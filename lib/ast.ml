type literal =
  | Int       of int
  | String    of string
  | Bool      of bool
  | List      of literal list
  | Object    of (string * literal) list   (* nested maps, e.g. env = { … } *)
  | SecretRef of string                    (* DATABASE_URL = secret "db-prod-url" *)

type field = Field of string * literal

type pod_decl     = string * field list          (* pod "nginx" { … }        *)
type svc_decl     = string * field list          (* service "foo" { … }      *)
type volume_decl  = string * field list          (* volume "bar" { … }       *)
type enum_decl    = string * string list         (* enum "env" { … }         *)
type secret_decl  = string * literal             (* secret "db-prod-url" { value = "…" } *)

type decl =
  | Pod     of pod_decl
  | Service of svc_decl
  | Volume  of volume_decl
  | Enum    of enum_decl
  | Secret  of secret_decl

type program = decl list
