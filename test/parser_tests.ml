open Rezn.Frontend
open Yojson.Basic

let%expect_test "parsing a minimal pod" =
  let source = {| pod "x" { image = "nginx" } |} in
  let prog = parse_string source in
  let json = Rezn.Codegen.program_to_json prog in
  json |> pretty_to_string |> print_endline;
  [%expect {| [ { "kind": "pod", "name": "x", "fields": { "image": "nginx" } } ] |}]
