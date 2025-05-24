type ir_binop =
  | IR_Add | IR_Sub | IR_Mul | IR_Div
  | IR_Eq | IR_Neq | IR_Gt | IR_Lt | IR_Le | IR_Ge
  | IR_And | IR_Or

type ir_expr =
  | IR_Int of int
  | IR_Bool of bool
  | IR_String of string
  | IR_Var of string
  | IR_Field of string
  | IR_OldField of string
  | IR_Result
  | IR_BinOp of ir_binop * ir_expr * ir_expr
  | IR_UnOp of string * ir_expr
  | IR_Call of string * ir_expr list

type ir_stmt =
  | IR_Assign of ir_expr * ir_expr
  | IR_Print of ir_expr
  | IR_If of ir_expr * ir_stmt list * ir_stmt list option
  | IR_While of ir_expr * ir_stmt list
  | IR_Return of ir_expr option
  | IR_Assert of string * ir_expr
