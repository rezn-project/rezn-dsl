let verify_bundle (bundle : Yojson.Safe.t) : bool =
  try
    match bundle with
    | `Assoc [
        ("program", program_json);
        ("signature", `Assoc [
          ("algorithm", `String "ed25519");
          ("sig", `String sig_b64);
          ("pub", `String pub_b64)
        ])
      ] ->
        let json_str = Yojson.Safe.to_string program_json in
        let msg = Bytes.of_string json_str in

        let signature =
          Base64.decode sig_b64
          |> Result.get_ok
          |> Bytes.of_string
          |> Sodium.Sign.Bytes.to_signature
        in
        let pubkey =
          Base64.decode pub_b64
          |> Result.get_ok
          |> Bytes.of_string
          |> Sodium.Sign.Bytes.to_public_key
        in

        (try
           Sodium.Sign.Bytes.verify pubkey signature msg;
           true
         with _ -> false)
    | _ -> 
      Printf.eprintf "[verify] Invalid bundle format.\n%!";
      false
  with _ -> 
    Printf.eprintf "[verify] Error during verification.\n%!";
    false
