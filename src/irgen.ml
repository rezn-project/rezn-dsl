open Ast
open Ir

let rec to_ir_expr = function
  | IntLit i -> IR_Int i
  | BoolLit b -> IR_Bool b
  | StringLit s -> IR_String s
  | Var (_, "result") -> IR_Result
  | Var (Field, name) -> IR_Field name
  | Var (Param, name) -> IR_Var name
  | Var (Local, name) -> IR_Var name
  | Old name -> IR_OldField name
  | UnaryOp (Not, e) -> IR_UnOp ("!", to_ir_expr e)
  | UnaryOp (Neg, e) -> IR_UnOp ("-", to_ir_expr e)
  | BinOp (Eq, Var (_, "result"), BoolLit true)
  | BinOp (Eq, BoolLit true, Var (_, "result")) ->
    IR_Result
  | BinOp (Eq, Var (_, "result"), BoolLit false)
  | BinOp (Eq, BoolLit false, Var (_, "result")) ->
    IR_UnOp ("!", IR_Result)
  | BinOp (op, a, b) ->
      let map_op = function
        | Add -> IR_Add | Sub -> IR_Sub | Mul -> IR_Mul | Div -> IR_Div
        | Eq -> IR_Eq | Neq -> IR_Neq
        | Gt -> IR_Gt | Lt -> IR_Lt | Ge -> IR_Ge | Le -> IR_Le
        | And -> IR_And | Or -> IR_Or
      in
      IR_BinOp (map_op op, to_ir_expr a, to_ir_expr b)
  | Call (_, name, args) ->
      IR_Call (name, List.map to_ir_expr args)


let to_ir_stmt = function
    | Assign (Var (Field, name), expr) ->
        IR_Assign (IR_Field name, to_ir_expr expr)
    | Assign (Var (Param, name), expr)
    | Assign (Var (Local, name), expr) ->
        IR_Assign (IR_Var name, to_ir_expr expr)
    | Print e ->
        IR_Print (to_ir_expr e)
    | Return (Some e) ->
        IR_Return (Some (to_ir_expr e))
    | Return None ->
        IR_Return None
    | _ ->
        IR_Assert ("UnsupportedStmt", IR_Bool false)
