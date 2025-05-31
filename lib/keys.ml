let key_dir = "/etc/rezndsl"
let key_file = Filename.concat key_dir "rezn.key"
let pub_file = Filename.concat key_dir "rezn.pub"

let ensure_keys () =
  let () =
    try
      Unix.mkdir key_dir 0o700
    with
    | Unix.Unix_error ((Unix.EEXIST | Unix.EISDIR), _, _) -> ()
    | Unix.Unix_error (Unix.EACCES, _, _) as e ->
        Printf.eprintf "Cannot create %s – permission denied. Did you run the post-install script?\n%!" key_dir;
        raise e
    | Unix.Unix_error _ as e -> raise e
    in

  try
    let fd =
      Unix.openfile key_file [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL ] 0o600
    in
    Printf.printf "Generating new Ed25519 keypair at %s...\n%!" key_file;
    Sodium.Random.stir ();
    let sk, pk = Sodium.Sign.random_keypair () in
    let sk_bytes = Sodium.Sign.Bytes.of_secret_key sk in
    let pk_bytes = Sodium.Sign.Bytes.of_public_key pk in

    let out = Unix.out_channel_of_descr fd in
    Out_channel.output_bytes out sk_bytes;
    Out_channel.close out;

    Out_channel.with_open_bin pub_file (fun out_pub ->
      Out_channel.output_bytes out_pub pk_bytes
    );

    Unix.chmod key_file 0o600;
    Unix.chmod pub_file 0o644;
  with
  | Unix.Unix_error (Unix.EEXIST, _, _) ->
    if not (Sys.file_exists pub_file) then (
      try
        let sk =
          In_channel.with_open_bin key_file In_channel.input_all
          |> Bytes.of_string |> Sodium.Sign.Bytes.to_secret_key
        in
        let pk = Sodium.Sign.secret_key_to_public_key sk in
        Out_channel.with_open_bin pub_file (fun ch ->
          Out_channel.output_bytes ch (Sodium.Sign.Bytes.of_public_key pk)
        );
        Unix.chmod pub_file 0o644
      with exn ->
        Printf.eprintf "Failed to derive pubkey from existing secret key: %s\n%!" (Printexc.to_string exn);
        raise exn
    )
  
  | exn ->
      Printf.eprintf "Key generation failed: %s\n%!" (Printexc.to_string exn);
      raise exn

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
