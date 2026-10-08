# Shared signature fixture

These files are byte-identical copies in:

- `rezn-dsl/test/fixtures/signatures/`
- `rezn/rezn-runtime/tests/fixtures/signatures/`

`signed-program.json` deliberately has noncanonical object key ordering. Its
Ed25519 signature was generated with OpenSSL over the exact ASCII bytes in
`program.canonical.json`. The canonical file has no trailing newline. The
private signing key was temporary and is not included.

Both repositories' tests check the canonical bytes, verify the same public key
and signature, accept reordered object keys, and reject changed values. Keep
both fixture copies synchronized when adding or replacing vectors. Test keys
and signatures establish no production signer trust.
