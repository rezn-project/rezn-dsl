# Rezn Test Suite

Tests use `ppx_expect`. `parser_tests.ml` checks parsing; `signature_tests.ml`
checks the library signer/verifier round trip without compiler CLI formatting,
object key reordering, whitespace, changed values and array order, wrong
signatures/keys, empty programs, and the shared Rust signature fixture.

## Running tests

Install the repository's existing OCaml dependencies and the JCS shared library
used by the signer. Run from the `rezn-dsl` repository root:

```bash
REZNJCS_LIB_PATH=/absolute/path/libreznjcs.so opam exec -- dune build
REZNJCS_LIB_PATH=/absolute/path/libreznjcs.so opam exec -- dune runtest
```

The tests generate signing keys in memory; they never use or write the configured
application key directory. Dune declares the fixture dependencies and makes them
available in its test sandbox. See [shared fixture notes](fixtures/signatures/README.md).

## Accepting updated output

Test failures show the expected/actual output diff. After reviewing an intentional
change, `dune promote` updates snapshots. Changing JSON object ordering must not
turn a valid signature into a failed expectation, and changing a signed value or
array order must fail verification.
