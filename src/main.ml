open Ast

let rec string_of_expr = function
  | IntLit i -> string_of_int i
  | BoolLit b -> string_of_bool b
  | StringLit s -> "\"" ^ s ^ "\""
  | Var name -> name
  | FieldAccess (obj, field) ->
      string_of_expr obj ^ "." ^ field
  | BinOp (op, lhs, rhs) ->
      let op_str = match op with
        | Add -> "+" | Sub -> "-" | Mul -> "*" | Div -> "/"
        | Eq -> "==" | Neq -> "!=" | Gt -> ">" | Lt -> "<"
        | Ge -> ">=" | Le -> "<=" | And -> "&&" | Or -> "||"
      in
      "(" ^ string_of_expr lhs ^ " " ^ op_str ^ " " ^ string_of_expr rhs ^ ")"
  | Call (name, args) ->
      name ^ "(" ^ String.concat ", " (List.map string_of_expr args) ^ ")"
  | ListLit xs ->
      "[" ^ String.concat ", " (List.map string_of_expr xs) ^ "]"

let string_of_contract c =
  let pp_opt label = function
    | Some e -> Printf.sprintf "    %s: %s\n" label (string_of_expr e)
    | None -> ""
  in
  pp_opt "pre" c.pre ^
  pp_opt "post" c.post ^
  pp_opt "invariant" c.invariant

let print_declaration = function
  | Pod (name, fields, contract) ->
      Printf.printf "POD %s\n" name;
      List.iter (function
        | IntField (k, v) -> Printf.printf "  %s = %d\n" k v
        | StringField (k, v) -> Printf.printf "  %s = \"%s\"\n" k v
        | ListField (k, vs) -> Printf.printf "  %s = %s\n" k (string_of_expr (ListLit vs))
      ) fields;
      Printf.printf "  Contract:\n%s" (string_of_contract contract)
  | Service (name, _fields, _contract) ->
      Printf.printf "SERVICE %s\n" name;
      (* same as above *)
  | Volume (name, fields) ->
      Printf.printf "VOLUME %s\n" name;
      List.iter (function
        | IntField (k, v) -> Printf.printf "  %s = %d\n" k v
        | StringField (k, v) -> Printf.printf "  %s = \"%s\"\n" k v
        | ListField (k, vs) -> Printf.printf "  %s = %s\n" k (string_of_expr (ListLit vs))
      ) fields
  | Enum (name, values) ->
      Printf.printf "ENUM %s = [%s]\n" name (String.concat ", " values)

let () =
  let filename = Sys.argv.(1) in
  let in_chan = open_in filename in
  let lexbuf = Lexing.from_channel in_chan in

  let ast =
    try
      Parser.declarations Lexer.token lexbuf
    with
    | Parser.Error ->
        let pos = lexbuf.Lexing.lex_curr_p in
        Printf.eprintf "Parse error at line %d, column %d\n"
          pos.pos_lnum
          (pos.pos_cnum - pos.pos_bol);
        exit 1
  in

  close_in in_chan;
  List.iter print_declaration ast
