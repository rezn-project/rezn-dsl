type type_expr =
  | TypeInteger
  | TypeBoolean
  | TypeString

type var_context =
  | Local
  | Param
  | Field

type bin_op =
  | Add | Sub | Mul | Div
  | Eq | Neq | Gt | Lt | Ge | Le
  | And | Or

type unary_op =
  | Not | Neg

type expr =
  | IntLit of int
  | StringLit of string
  | BoolLit of bool
  | Var of string
  | FieldAccess of expr * string
  | BinOp of bin_op * expr * expr
  | Call of string * expr list
  | ListLit of expr list  (* <--- add this *)


type declaration =
  | Pod of string * field list * contract
  | Service of string * field list * contract
  | Volume of string * field list
  | Enum of string * string list

and contract = {
  pre       : expr option;
  post      : expr option;
  invariant : expr option;
}

and field =
  | IntField of string * int
  | StringField of string * string
  | ListField of string * expr list

