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
