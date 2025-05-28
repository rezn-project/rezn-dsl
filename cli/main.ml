open Rezn.Frontend
open Cmdliner

let run input_file output_file_opt =
  try
    Rezn.Sign.ensure_keys ();

    let sk_bytes =
      let ic = open_in_bin Rezn.Sign.key_file in
      really_input_string ic 64 |> Bytes.of_string
    in
    let sk = Sodium.Sign.Bytes.to_secret_key sk_bytes in

    let prog = parse_file input_file in
    let bundle = Rezn.Sign.generate_signed_bundle prog sk in
    let json_str = Yojson.Safe.pretty_to_string bundle in

    (match output_file_opt with
     | Some path ->
         let oc = open_out path in
         output_string oc json_str;
         close_out oc
     | None ->
         print_endline json_str);

    exit 0
  with
  | Rezn.Frontend.Parse_error msg ->
      prerr_endline msg;
      exit 1
  | Rezn.Frontend.Lexer_error msg ->
      prerr_endline ("Lexer error: " ^ msg);
      exit 1
  | exn ->
      prerr_endline ("Unhandled error: " ^ Printexc.to_string exn);
      exit 2

let input_file =
  let doc = "The .rezn source file to compile and sign." in
  Arg.(required & pos 0 (some file) None & info [] ~docv:"REZN_FILE" ~doc)

let output_file =
  let doc = "Optional output path. If omitted, signed bundle is printed to stdout." in
  Arg.(value & opt (some string) None & info ["o"; "output"] ~docv:"FILE" ~doc)

let cmd_term =
  Term.(const run $ input_file $ output_file)

let cmd_info =
  let doc = "Compile and cryptographically sign a Rezn IR program" in
  let man = [
    `S Manpage.s_description;
    `P "Reads a .rezn file, emits JSON IR, and attaches an Ed25519 signature to it.";
    `P "The signature proves authenticity and prevents tampering of the infrastructure spec.";
  ] in
  Cmd.info "reznc" ~doc ~man

let cmd = Cmd.v cmd_info cmd_term

let () = Stdlib.exit @@ Cmd.eval cmd
