open Ast
open Parser
open Lexer
open Lexing

let parse_string s =
  let lexbuf = from_string s in
  try Parser.program Lexer.token lexbuf
  with Parser.Error ->
    let pos = lexbuf.lex_curr_p in
    failwith (Printf.sprintf "Parse error at line %d, column %d"
      pos.pos_lnum (pos.pos_cnum - pos.pos_bol))

let%expect_test "basic pod parses correctly" =
  let input = {|
    pod "web" {
      image = "nginx"
      replicas = 2
    }
  |} in
  let ast = parse_string input in
  let json = Codegen.program_to_json ast in
  Yojson.Basic.pretty_to_string json |> print_endline;
  [%expect {|
    [
      {
        "kind": "pod",
        "name": "web",
        "fields": {
          "image": "nginx",
          "replicas": 2
        }
      }
    ]
  |}]
