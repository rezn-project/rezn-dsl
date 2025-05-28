let key_file = "rezn.key"
let pub_file = "rezn.pub"

let ensure_keys () =
  if not (Sys.file_exists key_file) then (
    Printf.printf "Generating new Ed25519 keypair...\n%!";
    Sodium.Random.stir ();
    let sk, pk = Sodium.Sign.random_keypair () in
    let sk_bytes = Sodium.Sign.Bytes.of_secret_key sk in
    let pk_bytes = Sodium.Sign.Bytes.of_public_key pk in
    let out = open_out_bin key_file in
    output_bytes out sk_bytes;
    close_out out;
    let out_pub = open_out_bin pub_file in
    output_bytes out_pub pk_bytes;
    close_out out_pub
  )

let sign_json sk json_str =
  let msg = Bytes.of_string json_str in
  Sodium.Sign.Bytes.sign sk msg

let generate_signed_bundle (prog : Ast.program) (sk : Sodium.secret Sodium.Sign.key) : Yojson.Safe.t =
  let json = Codegen.program_to_json prog in
  let json_str = Yojson.Safe.to_string json in

  (* Hash the canonical program *)
  let hash = Digestif.SHA256.digest_string json_str in
  let hex = Digestif.SHA256.to_hex hash in
  Printf.printf "OCaml hash: %s\n%!" hex;

  let signature = Sodium.Sign.Bytes.sign_detached sk (Bytes.of_string json_str) in
  let signature_bytes = Sodium.Sign.Bytes.of_signature signature in
  let sig_b64 = Base64.encode_exn (Bytes.to_string signature_bytes) in
  let pk = Sodium.Sign.secret_key_to_public_key sk in
  let pub_b64 = Base64.encode_exn (Bytes.to_string (Sodium.Sign.Bytes.of_public_key pk)) in
  `Assoc [
    "program", json;
    "signature", `Assoc [
      "algorithm", `String "ed25519";
      "sig", `String sig_b64;
      "pub", `String pub_b64;
    ]
  ]

