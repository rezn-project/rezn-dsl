open Ast
open Printf
open Ir

let rec string_of_expr = function
  | IntLit i -> string_of_int i
  | StringLit s -> sprintf "\"%s\"" s
  | Var (Field, name) -> "self->" ^ name
  | Var (Param, name) -> name
  | Var (Local, name) -> name
  | Old name -> "old_" ^ name
  | BinOp (Eq, a, b) ->
      (match a, b with
       | StringLit _, _
       | _, StringLit _
       | Var (_, _), Var (_, _) -> sprintf "strcmp(%s, %s) == 0" (string_of_expr a) (string_of_expr b)
       | _ -> sprintf "(%s == %s)" (string_of_expr a) (string_of_expr b))
  | BinOp (Neq, a, b) ->
      (match a, b with
       | StringLit _, _
       | _, StringLit _
       | Var (_, _), Var (_, _) -> sprintf "strcmp(%s, %s) != 0" (string_of_expr a) (string_of_expr b)
       | _ -> sprintf "(%s != %s)" (string_of_expr a) (string_of_expr b))
  | BinOp (op, a, b) ->
      let op_str = match op with
        | Add -> "+" | Sub -> "-" | Mul -> "*" | Div -> "/"
        | Gt -> ">" | Lt -> "<" | Ge -> ">=" | Le -> "<=" | And -> "&&" | Or -> "||"
        | _ -> "/* unknown op */"
      in
      "(" ^ string_of_expr a ^ " " ^ op_str ^ " " ^ string_of_expr b ^ ")"
  | _ -> "/* unsupported expr */"

let string_of_type = function
  | TypeInteger -> "int32_t"
  | TypeBoolean -> "bool"
  | TypeString -> "const char*"

let gen_stmt = function
  | Assign (Var(_, name), expr) ->
      (match expr with
       | StringLit _ -> sprintf "    self->%s = GC_strdup(%s);\n" name (string_of_expr expr)
       | _ -> sprintf "    self->%s = %s;\n" name (string_of_expr expr))
  | Assign (lhs, rhs) ->
      sprintf "    %s = %s;\n" (string_of_expr lhs) (string_of_expr rhs)
  | Print expr ->
      sprintf "    printf(\"%%s\\n\", %s);\n" (string_of_expr expr)
  | Return _ -> ""  (* handled specially in gen_routine *)
  | _ -> "    /* unsupported stmt */\n"

let gen_ast_routine class_name r =
  let param_list =
    String.concat ", " (List.map (fun p ->
      sprintf "%s %s" (string_of_type p.param_type) p.param_name
    ) r.params)
  in
  let buffer = Buffer.create 256 in

  let signature =
    if param_list = "" then
      sprintf "void %s(%s* self)" r.name class_name
    else
      sprintf "void %s(%s* self, %s)" r.name class_name param_list
  in
  Buffer.add_string buffer (signature ^ " {\n");

  let has_result =
    match r.return_type with
    | Some _ -> true
    | None -> false
  in

  if has_result then
    Buffer.add_string buffer (sprintf "    %s _result;\n" (string_of_type (Option.get r.return_type)));

  (* Preconditions *)
  List.iter (fun e ->
    Buffer.add_string buffer (sprintf "    if (!(%s)) {\n" (string_of_expr e));
    Buffer.add_string buffer "        fprintf(stderr, \"Precondition failed\\n\");\n";
    Buffer.add_string buffer "        exit(1);\n    }\n"
  ) r.require;

  (* Generate body, deferring return _result *)
  let deferred_return = ref None in
  List.iter (fun stmt ->
    match stmt with
    | Return (Some expr) when has_result ->
        Buffer.add_string buffer (sprintf "    _result = %s;\n" (string_of_expr expr));
        deferred_return := Some "_result"
    | Return None ->
        Buffer.add_string buffer "    return;\n"
    | _ ->
        Buffer.add_string buffer (gen_stmt stmt)
  ) r.body;

  (* Postconditions *)
  List.iter (fun e ->
    let skip =
      match e with
      | BinOp (_, Var (_, name), _) when name = "result" && not has_result -> true
      | BinOp (_, _, Var (_, name)) when name = "result" && not has_result -> true
      | _ -> false
    in
    if not skip then
      let expr_str =
        match e with
        | BinOp (op, Var (_, "result"), rhs) ->
            string_of_expr (BinOp (op, Var (Local, "_result"), rhs))
        | BinOp (op, lhs, Var (_, "result")) ->
            string_of_expr (BinOp (op, lhs, Var (Local, "_result")))
        | _ -> string_of_expr e
      in
      Buffer.add_string buffer (sprintf "    if (!(%s)) {\n" expr_str);
      Buffer.add_string buffer "        fprintf(stderr, \"Postcondition failed\\n\");\n";
      Buffer.add_string buffer "        exit(1);\n    }\n"
  ) r.ensure;

  (* Emit deferred return _result *)
  (match !deferred_return with
   | Some name -> Buffer.add_string buffer (sprintf "    return %s;\n" name)
   | None -> ());

  Buffer.add_string buffer "}\n";

  Buffer.contents buffer

  let rec string_of_ir_expr = function
  | IR_Int i -> string_of_int i
  | IR_Bool b -> if b then "true" else "false"
  | IR_String s -> sprintf "\"%s\"" s
  | IR_Var name -> name
  | IR_Field name -> "self->" ^ name
  | IR_OldField name -> "old_" ^ name
  | IR_Result -> "_result"
  | IR_UnOp (op, e) -> sprintf "(%s%s)" op (string_of_ir_expr e)
  | IR_Call (fn, args) ->
      sprintf "%s(%s)" fn (String.concat ", " (List.map string_of_ir_expr args))
  | IR_BinOp (IR_Eq, IR_Result, IR_Bool true) -> "_result"
  | IR_BinOp (IR_Eq, IR_Bool true, IR_Result) -> "_result"
  | IR_BinOp (IR_Eq, IR_Result, IR_Bool false) -> "!_result"
  | IR_BinOp (IR_Eq, IR_Bool false, IR_Result) -> "!_result"
  | IR_BinOp (IR_Eq, a, b)
  | IR_BinOp (IR_Neq, a, b) as expr ->
      let cmp = match expr with
        | IR_BinOp (IR_Eq, _, _) -> "== 0"
        | IR_BinOp (IR_Neq, _, _) -> "!= 0"
        | _ -> assert false
      in
      let is_str_like = function
        | IR_String _ | IR_Field _ | IR_OldField _ | IR_Var _ -> true
        | _ -> false
      in
      if is_str_like a && is_str_like b then
        sprintf "strcmp(%s, %s) %s" (string_of_ir_expr a) (string_of_ir_expr b) cmp
      else
        let op_str = if cmp = "== 0" then "==" else "!=" in
        sprintf "(%s %s %s)" (string_of_ir_expr a) op_str (string_of_ir_expr b)

  | IR_BinOp (op, a, b) ->
      let op_str = match op with
        | IR_Add -> "+" | IR_Sub -> "-" | IR_Mul -> "*" | IR_Div -> "/"
        | IR_Gt -> ">" | IR_Lt -> "<" | IR_Ge -> ">=" | IR_Le -> "<="
        | IR_And -> "&&" | IR_Or -> "||"
        | _ -> "/* unknown op */"
      in
      sprintf "(%s %s %s)" (string_of_ir_expr a) op_str (string_of_ir_expr b)


let emit_stmt = function
  | IR_Assign (IR_Field name, IR_Var src) ->
      sprintf "    self->%s = GC_strdup(%s);\n" name src
  | IR_Assign (IR_Field name, expr) ->
      (match expr with
       | IR_String _ -> sprintf "    self->%s = GC_strdup(%s);\n" name (string_of_ir_expr expr)
       | _ -> sprintf "    self->%s = %s;\n" name (string_of_ir_expr expr))
  | IR_Assign (lhs, rhs) ->
      sprintf "    %s = %s;\n" (string_of_ir_expr lhs) (string_of_ir_expr rhs)

  | IR_Print expr ->
      sprintf "    printf(\"%%s\\n\", %s);\n" (string_of_ir_expr expr)

  | IR_Assert (label, cond) ->
      sprintf "    if (!(%s)) {\n        fprintf(stderr, \"%s failed\\n\");\n        exit(1);\n    }\n"
        (string_of_ir_expr cond) label

  | IR_Return (Some expr) ->
      sprintf "    _result = %s;\n" (string_of_ir_expr expr)

  | IR_Return None ->
      "    return;\n"

  | _ ->
      "    /* unsupported IR stmt */\n"


let gen_ir_routine class_name name params return_type cls_fields ir_body =

  let buffer = Buffer.create 256 in

  let param_list =
    String.concat ", " (List.map (fun (typ, name) -> sprintf "%s %s" typ name) params)
  in

  let signature =
    match return_type with
    | Some typ -> sprintf "%s %s(%s* self%s%s)" typ name class_name
                    (if param_list = "" then "" else ", ") param_list
    | None -> sprintf "void %s(%s* self%s%s)" name class_name
                (if param_list = "" then "" else ", ") param_list
  in

  Buffer.add_string buffer (signature ^ " {\n");

  if Option.is_some return_type then
    Buffer.add_string buffer (sprintf "    %s _result;\n" (Option.get return_type));

  let used_old_fields =
    let rec collect acc = function
      | IR_Assert (_, cond) -> collect_expr acc cond
      | _ -> acc
    and collect_expr acc = function
      | IR_OldField name -> name :: acc
      | IR_BinOp (_, a, b) -> collect_expr (collect_expr acc a) b
      | IR_UnOp (_, e) -> collect_expr acc e
      | IR_Call (_, args) -> List.fold_left collect_expr acc args
      | _ -> acc
    in
    List.fold_left collect [] ir_body
    |> List.sort_uniq String.compare
  in
  
  List.iter (fun name ->
    let field_type =
      match List.find_opt (function Field(n, _) -> n = name | _ -> false) cls_fields with
      | Some (Field(_, t)) -> string_of_type t
      | _ -> "/* unknown type */"
    in
    Buffer.add_string buffer (sprintf "    %s old_%s = self->%s;\n" field_type name name)
  ) used_old_fields;

  List.iter (fun stmt ->
    Buffer.add_string buffer (emit_stmt stmt)
  ) ir_body;

  if Option.is_some return_type then
    Buffer.add_string buffer "    return _result;\n";

  Buffer.add_string buffer "}\n";
  Buffer.contents buffer
      
  

let gen_header cls =
    let class_name = String.uppercase_ascii cls.class_name in
    let buf = Buffer.create 256 in
  
    Buffer.add_string buf "#ifndef RIVAR_H\n#define RIVAR_H\n\n";
    Buffer.add_string buf "#include <stdint.h>\n#include <stdbool.h>\n\n";
  
    (* Struct *)
    Buffer.add_string buf (sprintf "typedef struct {\n");
    List.iter (function
      | Field(name, t) ->
          Buffer.add_string buf (sprintf "    %s %s;\n" (string_of_type t) name)
      | _ -> ()
    ) cls.features;
    Buffer.add_string buf (sprintf "} %s;\n\n" class_name);
  
    (* Function declarations *)
    List.iter (function
      | Routine { name; params; return_type; _ } ->
          let c_type_of = function
            | TypeInteger -> "int32_t"
            | TypeBoolean -> "bool"
            | TypeString -> "const char*"
          in
  
          let param_list =
            List.map (fun p -> (c_type_of p.param_type, p.param_name)) params
          in
  
          let param_str =
            String.concat ", " (
              (sprintf "%s* self" class_name) ::
              List.map (fun (t, n) -> sprintf "%s %s" t n) param_list
            )
          in
  
          let sig_str =
            match return_type with
            | Some t -> sprintf "%s %s(%s);" (c_type_of t) name param_str
            | None -> sprintf "void %s(%s);" name param_str
          in
  
          Buffer.add_string buf (sig_str ^ "\n")
      | _ -> ()
    ) cls.features;
  
    Buffer.add_string buf "\n#endif // RIVAR_H\n";
    Buffer.contents buf

let gen_class cls =
    let class_name = String.uppercase_ascii cls.class_name in
    let buf = Buffer.create 256 in
  
    (* Headers *)
    Buffer.add_string buf "#include <stdio.h>\n#include <stdlib.h>\n#include <stdbool.h>\n#include <stdint.h>\n#include <string.h>\n#include <gc.h>\n\n";
  
    (* Struct definition *)
    Buffer.add_string buf (sprintf "typedef struct {\n");
    List.iter (function
      | Field(name, t) ->
          Buffer.add_string buf (sprintf "    %s %s;\n" (string_of_type t) name)
      | _ -> ()
    ) cls.features;
    Buffer.add_string buf (sprintf "} %s;\n\n" class_name);
  
    (* Code for each routine *)
    List.iter (function
      | Routine { name; params; return_type; require; body; ensure } ->
          let c_type_of = function
            | TypeInteger -> "int32_t"
            | TypeBoolean -> "bool"
            | TypeString -> "const char*"
          in

          let param_list = List.map (fun p -> (c_type_of p.param_type, p.param_name)) params in
          let ret_type = Option.map c_type_of return_type in

          let contains_result e =
            let rec check = function
              | IR_Result -> true
              | IR_BinOp (_, a, b) -> check a || check b
              | IR_UnOp (_, e) -> check e
              | IR_Call (_, args) -> List.exists check args
              | _ -> false
            in
            check (Irgen.to_ir_expr e)
          in

          let filtered_ensures =
            if Option.is_some return_type then ensure
            else List.filter (fun e -> not (contains_result e)) ensure
          in

          let ir_body =
            List.map (fun e -> IR_Assert ("Precondition", Irgen.to_ir_expr e)) require
            @ List.map Irgen.to_ir_stmt body
            @ List.map (fun e -> IR_Assert ("Postcondition", Irgen.to_ir_expr e)) filtered_ensures
          in

          let routine_code =
            gen_ir_routine
              class_name
              name
              param_list
              ret_type
              cls.features
              ir_body
          in
          Buffer.add_string buf routine_code

      | _ -> ()
    ) cls.features;
  
    Buffer.contents buf
  

