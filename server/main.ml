open Lwt.Syntax

(* ---------- Unix-socket selection ---------- *)

let default_socket_path  = "/run/rezndsl/rezn.sock"
let fallback_socket_path = "/tmp/rezndsl.sock"

let get_socket_path () =
  match Sys.getenv_opt "SOCKET_PATH" with
  | Some p -> p
  | None   ->
    if Sys.file_exists "/run/rezndsl" then
      try
        let fn = Filename.concat "/run/rezndsl" ".rezn_write_test" in
        let oc = open_out_gen [Open_creat; Open_wronly] 0o600 fn in
        close_out oc; Sys.remove fn; default_socket_path
      with _ -> fallback_socket_path
    else fallback_socket_path

let socket_path = get_socket_path ()

let () =
  let dir = Filename.dirname socket_path in
  try Unix.mkdir dir 0o770 with Unix.Unix_error (Unix.EEXIST,_,_) -> ()

(* ---------- preload keys once at start-up ---------- *)

let () = Rezn.Keys.ensure_keys ()
let sk  = lazy (Rezn.Keys.get_sk ())

(* ---------- core request logic (off the event loop) ---------- *)

let handle_raw raw =
  Lwt_preemptive.detach
    (fun () ->
       try
         match Yojson.Safe.from_string raw with
         | `Assoc [ ("op", `String "sign"); ("source", `String src) ] ->
             let bundle =
               Rezn.Frontend.sign_program_string src (Lazy.force sk) in
             `Assoc [ "status", `String "ok"; "bundle", bundle ]

         | `Assoc [ ("op", `String "verify"); ("bundle", bundle_json) ] ->
             let ok = Rezn.Verify.verify_bundle bundle_json in
             `Assoc [ "status", `String "ok"; "verified", `Bool ok ]

         | _ ->
             `Assoc [ "status", `String "error";
                      "message", `String "Invalid request format" ]
       with exn ->
         Printf.eprintf "Handler error: %s\n%!" (Printexc.to_string exn);
         `Assoc [ "status", `String "error";
                  "message", `String "Internal error" ])
    ()

(* ---------- Dream route ---------- *)

let api_handler req =
  let* body  = Dream.body req in
  let* json  = handle_raw body in
  let canon  = Yojson.Safe.to_string json
               |> Rezn.Jcs_bindings.canonicalize in
  Dream.json canon

(* ---------- graceful shutdown ---------- *)

let stop_promise, stop_wakener = Lwt.wait ()
let stopping = ref false
let stop () = if not !stopping then (stopping := true;
                                     Lwt.wakeup_later stop_wakener ())

let () =
  Sys.set_signal Sys.sigterm (Sys.Signal_handle (fun _ -> stop ()));
  Sys.set_signal Sys.sigint  (Sys.Signal_handle (fun _ -> stop ()));

  at_exit (fun () ->
      if Sys.file_exists socket_path then Sys.remove socket_path)

(* ---------- run Dream ---------- *)

let () =
  Printf.printf "rezn-dsl signer ready on %s\n%!" socket_path;

  Dream.run
    ~socket_path          (* Unix-domain socket, same path as before *)
    ~greeting:false
    ~stop:stop_promise
  @@ Dream.logger
  @@ Dream.router [
       Dream.post "/" api_handler;
     ]
