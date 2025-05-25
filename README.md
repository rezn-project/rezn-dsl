# rezn-dsl

A minimal infrastructure DSL with native parsing, typed fields, and JSON output.

## Status

Alpha status. It parses a declarative configuration language and emits structured JSON. Intended as a foundation for contract-enforced infrastructure definitions.

## Features

- Parser implemented in OCaml with Menhir and ocamllex
- Typed literals: `int`, `string`, `bool`, `list`
- Top-level declarations: `pod`, `service`, `volume`, `enum`
- Emits JSON as intermediate representation (IR)
- Lexer and parser written from scratch
- Single binary CLI

## Example

Input file `nginx.rezn`:

```rezn
pod "nginx" {
  image = "nginx:alpine"
  replicas = 2
  ports = [80, 443]
  secure = true
}

service "nginx-service" {
  selector = "nginx"
  port = 80
}

enum "env" {
  "dev", "prod"
}
````

Output (formatted):

```json
[
  {
    "kind": "pod",
    "name": "nginx",
    "fields": {
      "image": "nginx:alpine",
      "replicas": 2,
      "ports": [80, 443],
      "secure": true
    }
  },
  {
    "kind": "service",
    "name": "nginx-service",
    "fields": {
      "selector": "nginx",
      "port": 80
    }
  },
  {
    "kind": "enum",
    "name": "env",
    "options": ["dev", "prod"]
  }
]
```

## Build

Requires OCaml, Dune, and Menhir.

```bash
opam install dune yojson menhir
dune build
```

## Run

```bash
dune exec rezn examples/nginx.rezn
```

## Running Tests

```bash
dune runtest
````

## Roadmap

- Field validation
- Type annotations and schemas
- Contracts (pre, post, invariant)
- Imports and modules
- Binary IR format
- IR signing and signature verification


