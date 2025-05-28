let verify_bundle (bundle : Yojson.Safe.t) : bool =
  try
    match bundle with
    | `Assoc assoc_list ->
        (match List.assoc_opt "program" assoc_list, List.assoc_opt "signature" assoc_list with
         | Some program_json, Some (`Assoc sig_fields) ->
             (match List.assoc_opt "algorithm" sig_fields, 
                    List.assoc_opt "sig" sig_fields,
                    List.assoc_opt "pub" sig_fields with
              | Some (`String "ed25519"), Some (`String sig_b64), Some (`String pub_b64) ->
                  let json_str = Yojson.Safe.to_string program_json in
                  let msg = Bytes.of_string json_str in

                  let signature =
                    match Base64.decode sig_b64 with
                    | Ok sig_str -> Bytes.of_string sig_str |> Sodium.Sign.Bytes.to_signature
                    | Error _ -> failwith "Invalid base64 signature"
                  in
                  let pubkey =
                    match Base64.decode pub_b64 with
                    | Ok pub_str -> Bytes.of_string pub_str |> Sodium.Sign.Bytes.to_public_key
                    | Error _ -> failwith "Invalid base64 public key"
                  in

                  (try
                     Sodium.Sign.Bytes.verify pubkey signature msg;
                     true
                   with _ -> false)
              | _ -> 
                  Printf.eprintf "[verify] Invalid signature fields.\n%!";
                  false)
         | _ -> 
             Printf.eprintf "[verify] Invalid bundle format.\n%!";
             false)
    | _ -> 
        Printf.eprintf "[verify] Invalid bundle format.\n%!";
        false
  with _ -> 
    Printf.eprintf "[verify] Error during verification.\n%!";
    false
