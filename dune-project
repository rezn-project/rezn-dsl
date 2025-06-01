(lang dune 3.17)

(name rezn-dsl)

(generate_opam_files true)

(license MIT)

(maintainers "Andrea Mancuso <andrea@andreamancuso.dev>")

(authors "Andrea Mancuso <andrea@andreamancuso.dev>")

(source
 (github rezn-project/rezn-dsl))

(using menhir 2.1)

(package
 (allow_empty)
 (name rezn-dsl)
 (synopsis "DSL for Rezn")
 (description "Rezn is a domain-specific language (DSL) for Rezn")
 (depends
  ctypes
  ctypes-foreign
  (base64
   (and
    (>= 3.5.0)
    (< 4.0.0)))
  (cmdliner
   (>= 1.3.0))
  (digestif
   (>= 1.3.0))
  sodium
  (menhir
   (>= 2.1.0))
  (yojson
   (>= 2.2.2))
  ppx_expect))
