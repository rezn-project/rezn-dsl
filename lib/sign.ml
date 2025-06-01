let sign_json sk json_str =
  let msg = Bytes.of_string json_str in
  Sodium.Sign.Bytes.sign sk msg

let generate_signed_bundle (prog : Ast.program) (sk : Sodium.secret Sodium.Sign.key) : Yojson.Safe.t =
  let json = Codegen.program_to_json prog in
  let json_str = Yojson.Safe.to_string json in
  let canon_ir = Jcs_bindings.canonicalize json_str in

  (* Hash the canonical program *)
  let hash = Digestif.SHA256.digest_string canon_ir in
  let hex = Digestif.SHA256.to_hex hash in
  Printf.printf "Signature generation hash: %s\n%!" hex;

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

