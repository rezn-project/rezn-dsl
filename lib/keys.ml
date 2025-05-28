let get_sk () : Sodium.secret Sodium.Sign.key =
  try
    let sk_bytes =
      In_channel.with_open_bin Sign.key_file In_channel.input_all
      |> Bytes.of_string
    in
    let sk = Sodium.Sign.Bytes.to_secret_key sk_bytes in
    sk
  with
  | Sys_error msg -> 
      failwith ("Failed to read secret key file: " ^ msg)
  | Sodium.Verification_failure ->
      failwith ("Invalid secret key format in file: " ^ Sign.key_file)