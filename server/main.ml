let socket_path = "/tmp/rezn_signer.sock"

let () =
  if Sys.file_exists socket_path then Unix.unlink socket_path;
  let sock = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Unix.bind sock (Unix.ADDR_UNIX socket_path);
  Unix.listen sock 5;

  Rezn.Sign.ensure_keys ();

  let sk = Rezn.Keys.get_sk () in

  Printf.printf "Signer service ready on %s\n%!" socket_path;

  let rec loop () =
    let (client, _) = Unix.accept sock in
    let in_chan = Unix.in_channel_of_descr client in
    let out_chan = Unix.out_channel_of_descr client in
    try
      
      let req_body = really_input_string in_chan (in_channel_length in_chan) in

      let response =
        try
          match Yojson.Safe.from_string req_body with
          | `Assoc [ ("op", `String "sign"); ("source", `String src) ] ->
              let bundle = Rezn.Frontend.sign_program_string src sk in
              `Assoc [ "status", `String "ok"; "bundle", bundle ]
          | `Assoc [ ("op", `String "verify"); ("bundle", _bundle) ] ->
              let valid = false in
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
    with _ ->
      close_in_noerr in_chan;
      close_out_noerr out_chan;
      loop ()
  in
  loop ()
