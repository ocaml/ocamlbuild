
# OCamlbuild #

OCamlbuild is a generic build tool, that have built-in rules for
building OCaml library and programs.

Your should refer to the [OCambuild
manual](https://github.com/gasche/manual-ocamlbuild/blob/master/manual.md)
for more informations on the tools.

## Automatic Installation ##

OCamlbuild was directly present in OCaml release prior to 4.3. Now it
is available as an external tool. With [opam](https://opam.ocaml.org/):

```
opam install ocamlbuild
```

If you are testing a not yet released version of OCaml you perhaps
need to use the master version of OCamlbuild. With opam:

```
opam pin add ocamlbuild --kind=git "https://github.com/ocaml/ocamlbuild.git#master"
```

## Compilation from source ##

1. Configure.
```
make configure
```

The installation location is determined by the installation location of the ocaml
compiler. For installation in a different location just change the paths in the
generated Makefile.config.

2. Compile the sources.
```
make
```

3. Install.
```
make install
```
