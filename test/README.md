# Rezn Test Suite

This folder contains `%expect_test`-based snapshot tests using `ppx_expect`.

## Running Tests

```bash
dune runtest
````

If the tests fail, the output will show a diff between the actual and expected results.

## Accepting Updated Output

If changes are intentional (e.g. new formatting, parser logic), run:

```bash
dune promote
```

This updates the `.ml` files with the new `%expect` values.
