{
open Parser

let keyword_table = Hashtbl.create 10

let () =
  List.iter (fun (kw, tok) -> Hashtbl.add keyword_table kw tok)
    [ "pod", POD;
      "service", SERVICE;
      "volume", VOLUME;
      "enum", ENUM;
      "true", TRUE;
      "false", FALSE
    ]
}

let digit = ['0'-'9']
let id_start = ['a'-'z' 'A'-'Z' '_']
let id_char = id_start | digit
let ident = id_start id_char*

rule token = parse
  | [' ' '\t' '\r' '\n']      { token lexbuf } (* skip whitespace *)

  | '"' ([^ '"' '\\'] | '\\' _)* '"' as s {
      let unquoted = String.sub s 1 (String.length s - 2) in
      STRING unquoted
    }

  | digit+ as i               { INT (int_of_string i) }

  | ident {
    let id = Lexing.lexeme lexbuf in
    try Hashtbl.find keyword_table id
    with Not_found -> IDENT id
  }

  | '='                       { ASSIGN }
  | '{'                       { LBRACE }
  | '}'                       { RBRACE }
  | '['                       { LBRACK }
  | ']'                       { RBRACK }
  | ','                       { COMMA }

  | eof                       { EOF }

  | _ {
    let c = Lexing.lexeme_char lexbuf 0 in
    failwith (Printf.sprintf "Unexpected character: '%c'" c)
  }

