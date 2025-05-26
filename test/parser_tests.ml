let%expect_test "parsing a minimal pod" =
  let source = {| pod "x" { image = "nginx" } |} in
  let prog = Rezn.Frontend.parse_string source in
  let json = Rezn.Codegen.program_to_json prog in
  json |> Yojson.Safe.pretty_to_string |> print_endline;
  [%expect {| [ { "kind": "pod", "name": "x", "fields": { "image": "nginx" } } ] |}]
