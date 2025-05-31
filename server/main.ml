let default_socket_path = "/run/rezndsl/rezn.sock"
let fallback_socket_path = "/tmp/rezn.sock"

let get_socket_path () =
  match Sys.getenv_opt "SOCKET_PATH" with
  | Some path -> path
  | None -> (
      (* Check if /run/rezndsl exists and is writable *)
      if Sys.file_exists "/run/rezndsl" then (
        try
          let test_file = Filename.concat "/run/rezndsl" ".rezn_write_test" in
          let oc = open_out_gen [Open_creat; Open_wronly] 0o600 test_file in
          close_out oc;
          Sys.remove test_file;
          default_socket_path
        with _ -> fallback_socket_path
      ) else fallback_socket_path
    )

let socket_path = get_socket_path ()
let backlog = 10

let () =
  let sock = ref None in

  let cleanup_and_exit () =
    (match !sock with
    | Some s -> Unix.close s
    | None -> ());
    if Sys.file_exists socket_path then Unix.unlink socket_path;
    exit 0
  in

  (* Graceful shutdown handlers *)
  Sys.set_signal Sys.sigterm (Sys.Signal_handle (fun _ -> cleanup_and_exit ()));
  Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> cleanup_and_exit ()));

  (* Unlink existing socket if present *)
  if Sys.file_exists socket_path then Unix.unlink socket_path;

  (* Create and bind socket *)
  let socket = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  sock := Some socket;

  let socket_dir = Filename.dirname socket_path in
  (try Unix.mkdir socket_dir 0o770 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());

  Unix.bind socket (Unix.ADDR_UNIX socket_path);
  Unix.listen socket backlog;
  Unix.chmod socket_path 0o660;  (* Restrict access to rezndsl group *)

  Printf.printf "Signer service ready on %s\n%!" socket_path;

  (* Preload keys *)
  Rezn.Keys.ensure_keys ();
  let sk = Rezn.Keys.get_sk () in

  let handle_connection client_fd =
    let in_chan = Unix.in_channel_of_descr client_fd in
    let out_chan = Unix.out_channel_of_descr client_fd in

    let respond json =
      Yojson.Safe.to_string json |> output_string out_chan;
      output_char out_chan '\n';
      flush out_chan
    in

    let cleanup () =
      try close_in in_chan with _ -> ();
      try close_out out_chan with _ -> ();
      try Unix.close client_fd with _ -> ()
    in

    try
      let buf = Buffer.create 2048 in
      (try
        while true do
          Buffer.add_channel buf in_chan 1024
        done
      with End_of_file -> ());
      let raw_input = Buffer.contents buf in

      let response =
        try
          match Yojson.Safe.from_string raw_input with
          | `Assoc [ ("op", `String "sign"); ("source", `String src) ] ->
              let bundle = Rezn.Frontend.sign_program_string src (sk) in
              `Assoc [ "status", `String "ok"; "bundle", bundle ]

          | `Assoc [ ("op", `String "verify"); ("bundle", bundle_json) ] ->
              let valid = Rezn.Verify.verify_bundle bundle_json in
              `Assoc [ "status", `String "ok"; "verified", `Bool valid ]

          | _ ->
              `Assoc [ "status", `String "error"; "message", `String "Invalid request format" ]
        with exn ->
          Printf.eprintf "Handler error: %s\n%!" (Printexc.to_string exn);
          `Assoc [ "status", `String "error"; "message", `String "Internal error" ]
      in
      respond response;
      cleanup ()
    with exn ->
      Printf.eprintf "Connection error: %s\n%!" (Printexc.to_string exn);
      cleanup ()
  in

  (* Accept loop *)
  while true do
    try
      let (client_fd, _) = Unix.accept socket in
      ignore (Thread.create handle_connection client_fd)
    with exn ->
      Printf.eprintf "Socket accept error: %s\n%!" (Printexc.to_string exn)
  done
