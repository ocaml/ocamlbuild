# OCamlbuild #
[![build](https://github.com/ocaml/ocamlbuild/actions/workflows/build.yml/badge.svg)](https://github.com/ocaml/ocamlbuild/actions/workflows/build.yml)

OCamlbuild is a generic build tool, that has built-in rules for
building OCaml library and programs.

In recent years, the OCaml community has converged towards a more
recent and faster build tool:
[Dune](https://github.com/ocaml/dune). If you are choosing a build
system, you should probably use Dune instead. (Between January and
June 2019, 77 new OCaml packages using ocamlbuild were publicly
released, versus 544 packages using dune.)

Your should refer to the [OCambuild
manual](https://github.com/ocaml/ocamlbuild/blob/master/manual/manual.adoc)
for more informations on how to use ocamlbuild.

## Automatic Installation ##

With [opam](https://opam.ocaml.org/):

```
opam install ocamlbuild
```

If you are testing a not yet released version of OCaml, you may need
to use the development version of OCamlbuild. With opam:

```
opam pin add ocamlbuild --kind=git "https://github.com/ocaml/ocamlbuild.git#master"
```

## Compilation from source ##

We assume GNU make, which may be named `gmake` on your system.

1. Configure.
```
make configure
```

The installation location is determined by the installation location
of the ocaml compiler. You can set the following configuration
variables (`make configure VAR=foo`):

- `OCAMLBUILD_{PREFIX,BINDIR,LIBDIR}` will use opam or
  ocaml/ocamlfind's settings by default; see `configure.make` for the
  precise initialization logic.

- `OCAML_NATIVE`: should be `true` if native compilation is available
  on your machine, `false` otherwise

2. Compile the sources.
```
make
```

3. Install.
```
make install
```

You can also clean the compilation results with `make clean`, and
uninstall a manually-installed OCamlbuild with `make uninstall`.
