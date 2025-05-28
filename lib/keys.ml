let get_sk () : Sodium.secret Sodium.Sign.key =
  (* Read the secret key from the file *)
  let sk_bytes =
    In_channel.with_open_bin Sign.key_file In_channel.input_all
    |> Bytes.of_string
  in
  let sk = Sodium.Sign.Bytes.to_secret_key sk_bytes in

  sk