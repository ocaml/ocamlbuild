
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

1. Configure the system.

```
make -f configure.make Makefile.config OCAMLBUILD_PREFIX=$prefix 
         OCAMLBUILD_BINDIR=$prefix/bin OCAMLBUILD_LIBDIR=$prefix/lib/ocaml 
         OCAML_NATIVE=$native OCAML_NATIVE_TOOLS=$native
```

where ```$native``` is true if native tools are available and ```$prefix``` is
the intended installation lcoation

2. Create the dependency file.

```
touch .depend
make depend
```

3. Compile the sources.
```
make all
```

4. Install.
```
make install
```