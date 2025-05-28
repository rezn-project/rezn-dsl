let key_file = "rezn.key"
let pub_file = "rezn.pub"

let ensure_keys () =
  try
    let fd =
      Unix.openfile key_file [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL ] 0o600
    in
    Printf.printf "Generating new Ed25519 keypair...\n%!";
    Sodium.Random.stir ();
    let sk, pk = Sodium.Sign.random_keypair () in
    let sk_bytes = Sodium.Sign.Bytes.of_secret_key sk in
    let pk_bytes = Sodium.Sign.Bytes.of_public_key pk in

    let out = Unix.out_channel_of_descr fd in
    Out_channel.output_bytes out sk_bytes;
    Out_channel.close out;

    Out_channel.with_open_bin pub_file (fun out_pub ->
      Out_channel.output_bytes out_pub pk_bytes
    )
  with Unix.Unix_error (Unix.EEXIST, _, _) ->
    () (* Key already exists — do nothing *)

let get_sk () : Sodium.secret Sodium.Sign.key =
  try
    let sk_bytes =
      In_channel.with_open_bin key_file In_channel.input_all
      |> Bytes.of_string
    in
    let sk = Sodium.Sign.Bytes.to_secret_key sk_bytes in
    sk
  with
  | Sys_error msg -> 
      failwith ("Failed to read secret key file: " ^ msg)
  | Sodium.Verification_failure ->
      failwith ("Invalid secret key format in file: " ^ key_file)