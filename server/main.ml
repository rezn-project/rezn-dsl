let socket_path = "/tmp/rezn_signer.sock"

let buffer_size = 1024


let cleanup_and_exit sock =
  Unix.close sock;
  if Sys.file_exists socket_path then Unix.unlink socket_path;
  exit 0

let () =
  let sock = ref None in
  Sys.set_signal Sys.sigterm (Sys.Signal_handle (fun _ -> 
    match !sock with Some s -> cleanup_and_exit s | None -> exit 0));
  Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> 
    match !sock with Some s -> cleanup_and_exit s | None -> exit 0));
  if Sys.file_exists socket_path then Unix.unlink socket_path;
  let socket = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  sock := Some socket;
  Unix.bind socket (Unix.ADDR_UNIX socket_path);
  Unix.listen socket 5;

  Rezn.Keys.ensure_keys ();

  let sk = Rezn.Keys.get_sk () in

  Printf.printf "Signer service ready on %s\n%!" socket_path;

  let rec loop () =
    let (client, _) = Unix.accept socket in
    let in_chan = Unix.in_channel_of_descr client in
    let out_chan = Unix.out_channel_of_descr client in
    try
      let buf = Buffer.create buffer_size in
        (try while true do Buffer.add_channel buf in_chan buffer_size done
        with End_of_file -> ());
      let req_body = Buffer.contents buf in

      let response =
        try
          match Yojson.Safe.from_string req_body with
          | `Assoc [ ("op", `String "sign"); ("source", `String src) ] ->
              let bundle = Rezn.Frontend.sign_program_string src sk in
              `Assoc [ "status", `String "ok"; "bundle", bundle ]
          | `Assoc [ ("op", `String "verify"); ("bundle", bundle_json) ] ->
            let valid = Rezn.Verify.verify_bundle bundle_json in
            `Assoc [ "status", `String "ok"; "verified", `Bool valid ]
          | _ ->
              `Assoc [ "status", `String "error"; "message", `String "Invalid request format" ]
        with exn ->
          `Assoc [ "status", `String "error"; "message", `String (Printexc.to_string exn) ]
      in
      let result = Yojson.Safe.to_string response in
      output_string out_chan result;
      flush out_chan;
      close_in in_chan;
      close_out out_chan;
      loop ()
    with exn ->
      Printf.eprintf "Connection error: %s\n%!" (Printexc.to_string exn);
      close_in_noerr in_chan;
      close_out_noerr out_chan;
      loop ()
  in
  loop ()
