type literal =
  | Int of int
  | String of string
  | Bool of bool
  | List of literal list

type field =
  | Field of string * literal

type pod_decl = string * field list
type svc_decl = string * field list
type volume_decl = string * field list
type enum_decl = string * string list

type decl =
  | Pod of pod_decl
  | Service of svc_decl
  | Volume of volume_decl
  | Enum of enum_decl

type program = decl list
