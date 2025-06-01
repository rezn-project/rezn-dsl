open Ctypes
open Foreign

let try_paths = [
  Sys.getenv_opt "REZNJCS_LIB_PATH";
  Some "/usr/lib/rezndsl/libreznjcs.so";
  Some "./libreznjcs.so";
  Some "./lib/libreznjcs.so";
] |> List.filter_map Fun.id

let lib =
  let rec try_load = function
    | [] -> failwith "Could not locate libreznjcs.so (tried REZNJCS_LIB_PATH and fallback paths)"
    | path :: rest ->
        try Dl.dlopen ~filename:path ~flags:[Dl.RTLD_NOW]
        with Dl.DL_error err ->
          prerr_endline ("[WARN] Failed to load: " ^ path ^ " - " ^ err);
          try_load rest
  in
  try_load try_paths

let strlen =
  foreign "strlen" (ptr char @-> returning size_t)

let rezn_canonicalize =
  foreign ~from:lib "rezn_canonicalize"
    (string @-> returning (ptr char))

let rezn_free =
  foreign ~from:lib "rezn_free"
    (ptr char @-> returning void)

let canonicalize json =
  if String.length json = 0 then
    failwith "Canonicalization failed: empty JSON string"
  else
    let ptr = rezn_canonicalize json in
    if Ctypes.is_null ptr then
      failwith ("Canonicalization failed: invalid JSON or library error for input: "
                ^ String.sub json 0 (min 100 (String.length json)))
    else
      let len = Unsigned.Size_t.to_int (strlen ptr) in
      if len = 0 then (
        rezn_free ptr;
        failwith "Canonicalization failed: empty result"
      ) else
        let result = string_from_ptr ptr ~length:len in
        rezn_free ptr;
        result

