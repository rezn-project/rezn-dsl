open Rezn.Frontend

let () =
  if Array.length Sys.argv <> 2 then begin
    Printf.eprintf "Usage: %s <file.rezn>\n" Sys.argv.(0);
    exit 1
  end;

  let filename = Sys.argv.(1) in
  
  try
    Rezn.Sign.ensure_keys ();

    let sk_bytes =
      let ic = open_in_bin Rezn.Sign.key_file in
      really_input_string ic 64 |> Bytes.of_string
    in
    let sk = Sodium.Sign.Bytes.to_secret_key sk_bytes in

    let prog = parse_file filename in
    let json = Rezn.Codegen.program_to_json prog in
    let json_str = Yojson.Safe.pretty_to_string json in

    let signature = Sodium.Sign.Bytes.sign_detached sk (Bytes.of_string json_str) in
    let signature_in_bytes = Sodium.Sign.Bytes.of_signature signature in

    let bundle =
      `Assoc [
        "program", json;
        "signature", `Assoc [
          "algorithm", `String "ed25519";
          "sig", `String (Base64.encode_exn (Bytes.to_string (signature_in_bytes)));
        ]
      ]
    in

    (* Output the signed bundle *)
    let oc = open_out "output.reznbundle.json" in
    Yojson.Safe.pretty_to_channel oc bundle;
    close_out oc;


    print_newline ()
  with
  | Rezn.Frontend.Parse_error msg ->
      Printf.eprintf "%s\n" msg;
      exit 1
  | Rezn.Frontend.Lexer_error msg ->
      Printf.eprintf "Lexer error: %s\n" msg;
      exit 1
  
