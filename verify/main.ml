open Cmdliner

let run input_file =
  try
    let json = Yojson.Safe.from_file input_file in
    let is_valid = Rezn.Verify.verify_bundle json in

    if is_valid then (
      print_endline "✔ Signature is valid.";
      exit 0
    ) else (
      prerr_endline "✘ Signature is INVALID.";
      exit 1
    )
  with
  | Yojson.Json_error msg ->
      prerr_endline ("Failed to parse JSON: " ^ msg);
      exit 2
  | exn ->
      prerr_endline ("Unhandled error: " ^ Printexc.to_string exn);
      exit 3

let input_file =
  let doc = "The signed bundle file to verify (must be JSON)." in
  Arg.(required & pos 0 (some file) None & info [] ~docv:"SIGNED_JSON" ~doc)

let cmd_term =
  Term.(const run $ input_file)

let cmd_info =
  let doc = "Verify a signed Rezn IR bundle" in
  let man = [
    `S Manpage.s_description;
    `P "Verifies that the signature in a signed bundle is valid.";
    `P "Reads a JSON file containing {program, signature}, and checks the Ed25519 signature.";
  ] in
  Cmd.info "rezn-verify" ~doc ~man

let cmd = Cmd.v cmd_info cmd_term

let () = Stdlib.exit @@ Cmd.eval cmd
