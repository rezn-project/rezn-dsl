# rezn-dsl

A minimal infrastructure DSL with native parsing, typed fields, and JSON output.

## Status

Alpha status. It parses a declarative configuration language and emits structured JSON. Intended as a foundation for contract-enforced infrastructure definitions.

## Features

- Parser implemented in OCaml with Menhir and ocamllex
- Typed literals: `int`, `string`, `bool`, `list`
- Top-level declarations: `pod`, `service`, `volume`, `enum`
- Emits canonicalized JSON (RFC 8785) as intermediate representation (IR); leverages C++ based library through FFI
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

## Download dependency

- wget `https://github.com/rezn-project/rezn-jcsd/releases/download/v0.0.2/libreznjcs_amd64.so` (replace amd64 with your arch; check available architectures)
- Rename to `libreznjcs.so`
- Set `REZNJCS_LIB_PATH`, i.e. `REZNJCS_LIB_PATH=/path/to/libreznjcs.so`

These are the paths tried by the application:

```ocaml
let try_paths = [
  Sys.getenv_opt "REZNJCS_LIB_PATH";
  Some "/usr/lib/rezndsl/libreznjcs.so";
  Some "./libreznjcs.so";
  Some "./lib/libreznjcs.so";
] |> List.filter_map Fun.id
```

If you encounter issues related to the shared library, try enabling `DEBUG=1`

### Running the Unix socket

`./_build/default/server/main.exe ` -> `Signer service ready on /tmp/rezn_signer.sock`

#### Setup

The commands here assume you have installed `curl`, i.e.

`sudo apt install curl`

#### Signing

**Once a bundle has been signed and verified, treat the JSON as strictly read-only.**

Do **not** reformat, reserialize, pretty-print, or modify the JSON in any way.

> Even changes that appear trivial — such as field reordering, whitespace adjustments,
> or float formatting — will cause the signature to become invalid. The bundle exists
> to be **verified, not edited**. If you need to change the program, update the original
> `.rezn` source and re-sign it.

```bash
cat ./examples/basic-example.rezn \
| jq -Rs '{op:"sign", source:.}' \
| curl --unix-socket /tmp/rezndsl.sock \
       -H 'Content-Type: application/json' \
       -d @- \
       http://localhost/          # path is ignored for UDS

```

should emit (below example is pretty-printed):

```json
{
  "status": "ok",
  "bundle": {
    "program": [
      {
        "kind": "pod",
        "name": "nginx",
        "fields": {
          "image": "nginx:alpine",
          "replicas": 2,
          "ports": [
            80,
            443
          ],
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
        "kind": "volume",
        "name": "shared-cache",
        "fields": {
          "mount": "/cache"
        }
      },
      {
        "kind": "enum",
        "name": "env",
        "options": [
          "prod",
          "staging",
          "dev"
        ]
      }
    ],
    "signature": {
      "algorithm": "ed25519",
      "sig": "FHD0qZUpHsma5OPUc7mvNvjrE44Oc/R27GEUrtdf8gkb/azm4uTUcgY2H9Szo4Otw3VlYLhOjZlErnEffv6oCA==",
      "pub": "MWf0xdBZrWtyrMhpvrv3y0AAtEjHYgMLviEsWtadang="
    }
  }
}
```

#### Verifying

```bash
jq '{op:"verify", bundle:.}' ./examples/basic-example.ir.json \
| curl --unix-socket /tmp/rezndsl.sock \
       -H 'Content-Type: application/json' \
       -d @- http://localhost/

```

Should emit

`{"status":"ok","verified":true}`

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
REZNJCS_LIB_PATH=/path/to/libreznjcs.so dune runtest
````

## Roadmap

- Field validation
- Type annotations and schemas
- Contracts (pre, post, invariant)
- Imports and modules
- Binary IR format
- IR signing and signature verification


