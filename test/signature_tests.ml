let source = {|
  pod "web" {
    image = "nginx:alpine"
    replicas = 1
    ports = [80, 81]
  }
  pod "side" {
    image = "httpd:alpine"
    replicas = 0
    ports = [80]
  }
|}

let signed_program () =
  let sk, _ = Sodium.Sign.random_keypair () in
  source
  |> Rezn.Frontend.parse_string
  |> fun program -> Rezn.Sign.generate_signed_bundle program sk

let print_verified bundle =
  bundle |> Rezn.Verify.verify_bundle |> string_of_bool |> print_endline

let map_member name f = function
  | `Assoc members ->
      assert (List.mem_assoc name members);
      `Assoc (List.map (fun (key, value) ->
        (key, if key = name then f value else value)) members)
  | _ -> failwith "expected object in test bundle"

let map_program f = map_member "program" f

let rec reorder_object_keys = function
  | `Assoc members ->
      `Assoc (List.rev (List.map (fun (key, value) ->
        (key, reorder_object_keys value)) members))
  | `List items -> `List (List.map reorder_object_keys items)
  | value -> value

let map_first_fields f = map_program (function
  | `List (first :: rest) -> `List (map_member "fields" f first :: rest)
  | _ -> failwith "expected a nonempty program in test bundle")

let%expect_test "library signer output verifies without CLI serialization" =
  signed_program () |> print_verified;
  [%expect {| true |}]

let%expect_test "equivalent object order and formatting verify" =
  let bundle = signed_program () in
  let canonical = bundle |> Yojson.Safe.to_string |> Rezn.Jcs_bindings.canonicalize
    |> Yojson.Safe.from_string in
  canonical |> print_verified;
  canonical |> reorder_object_keys |> print_verified;
  canonical |> map_first_fields (map_member "replicas" (fun _ -> `Float 1.0))
    |> print_verified;
  canonical |> reorder_object_keys |> Yojson.Safe.pretty_to_string
    |> Yojson.Safe.from_string |> print_verified;
  [%expect {|
    true
    true
    true
    true
  |}]

let%expect_test "changed values and array order invalidate the signature" =
  let bundle = signed_program () in
  bundle |> map_first_fields (map_member "image" (fun _ -> `String "httpd:alpine"))
    |> print_verified;
  bundle |> map_first_fields (map_member "replicas" (fun _ -> `Int 2))
    |> print_verified;
  bundle |> map_program (function `List items -> `List (List.rev items)
    | _ -> assert false) |> print_verified;
  bundle |> map_first_fields (map_member "ports" (function
    | `List ports -> `List (List.rev ports) | _ -> assert false)) |> print_verified;
  bundle |> map_first_fields (function
    | `Assoc fields -> `Assoc (("secure", `Bool false) :: fields)
    | _ -> assert false) |> print_verified;
  [%expect {|
    false
    false
    false
    false
    false
  |}]

let%expect_test "wrong signature and public key are rejected" =
  let bundle = signed_program () in
  bundle |> map_member "signature" (map_member "sig" (fun _ ->
    `String (Base64.encode_exn (String.make 64 '\000')))) |> print_verified;
  let _, other_pk = Sodium.Sign.random_keypair () in
  bundle |> map_member "signature" (map_member "pub" (fun _ ->
    `String (other_pk |> Sodium.Sign.Bytes.of_public_key |> Bytes.to_string
      |> Base64.encode_exn))) |> print_verified;
  [%expect {|
    false
    false
  |}]

let%expect_test "signed empty program verifies" =
  let sk, _ = Sodium.Sign.random_keypair () in
  Rezn.Sign.generate_signed_bundle [] sk |> print_verified;
  [%expect {| true |}]

let%expect_test "canonicalization failure rejects the program" =
  signed_program ()
  |> map_first_fields (map_member "replicas" (fun _ -> `Float nan))
  |> print_verified;
  [%expect {|
    [verify] Error during verification.
    false
  |}]

let%expect_test "shared JCS and Ed25519 fixture matches the Rust verifier" =
  let bundle = Yojson.Safe.from_file "fixtures/signatures/signed-program.json" in
  let program = Yojson.Safe.Util.member "program" bundle in
  let canonical = program |> Yojson.Safe.to_string |> Rezn.Jcs_bindings.canonicalize in
  let expected = In_channel.with_open_bin "fixtures/signatures/program.canonical.json"
    In_channel.input_all in
  (canonical = expected) |> string_of_bool |> print_endline;
  bundle |> print_verified;
  bundle |> reorder_object_keys |> print_verified;
  bundle |> map_first_fields (map_member "replicas" (fun _ -> `Int 2))
    |> print_verified;
  [%expect {|
    true
    true
    true
    false
  |}]
