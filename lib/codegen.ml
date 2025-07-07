open Ast

let rec literal_to_json = function
  | Int i           -> `Int i
  | String s        -> `String s
  | Bool b          -> `Bool b
  | List lst        -> `List (List.map literal_to_json lst)
  | Object kvs      ->
      `Assoc (List.map (fun (k, v) -> (k, literal_to_json v)) kvs)
  | SecretRef name  ->
      (* Encoded in-line secret reference *)
      `Assoc [ ("from",  `String "secret")
             ; ("name",  `String name)
             ]

let field_to_pair (Field (key, value)) =
  (key, literal_to_json value)

let fields_to_json fields =
  `Assoc (List.map field_to_pair fields)

let decl_to_json = function
  | Pod (name, fields) ->
      `Assoc [
        ("kind",   `String "pod");
        ("name",   `String name);
        ("fields", fields_to_json fields)
      ]
  | Service (name, fields) ->
      `Assoc [
        ("kind",   `String "service");
        ("name",   `String name);
        ("fields", fields_to_json fields)
      ]
  | Volume (name, fields) ->
      `Assoc [
        ("kind",   `String "volume");
        ("name",   `String name);
        ("fields", fields_to_json fields)
      ]
  | Enum (name, options) ->
      `Assoc [
        ("kind",   `String "enum");
        ("name",   `String name);
        ("options", `List (List.map (fun s -> `String s) options))
      ]
  | Secret (name, value) ->
      `Assoc [
        ("kind",  `String "secret");
        ("name",  `String name);
        ("value", literal_to_json value)
      ]

let program_to_json (prog : program) : Yojson.Safe.t =
  `List (List.map decl_to_json prog)
