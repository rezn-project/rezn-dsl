open Ctypes
open Foreign

let lib =
  Dl.dlopen ~filename:"libreznjcs.so" ~flags:[Dl.RTLD_NOW]

let strlen =
  foreign "strlen" (ptr char @-> returning size_t)

let rezn_canonicalize =
  foreign ~from:lib "rezn_canonicalize"
    (string @-> returning (ptr char))

let rezn_free =
  foreign ~from:lib "rezn_free"
    (ptr char @-> returning void)

let canonicalize json =
  let ptr = rezn_canonicalize json in
  if Ctypes.is_null ptr then
    failwith "Canonicalization failed: null pointer"
  else
    let len = Unsigned.Size_t.to_int (strlen ptr) in
    let result = string_from_ptr ptr ~length:len in
    rezn_free ptr;
    result

