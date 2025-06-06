open Rezn.Frontend
open Cmdliner

let run input_file output_file_opt =
  try
    Rezn.Keys.ensure_keys ();

    let sk = Rezn.Keys.get_sk () in

    let prog = parse_file input_file in
    let bundle = Rezn.Sign.generate_signed_bundle prog sk in
    let json_str =
      try
        bundle
        |> Yojson.Safe.to_string
        |> Rezn.Jcs_bindings.canonicalize
      with
      | Failure msg ->
          prerr_endline ("Error during JSON canonicalization: " ^ msg);
          exit 1
      in

    (match output_file_opt with
     | Some path ->
         let oc = open_out path in
         output_string oc json_str;
         close_out oc
     | None ->
         print_endline json_str);

    ()
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
