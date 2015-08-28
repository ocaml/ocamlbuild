# A short introduction to OCamlbuild

OCamlbuild's job is to determine the sequence of calls to the
compiler, with the right set of command-line flags, needed to build
your OCaml project. It was designed to take into account specifics of
the OCaml language that make writing good Makefiles difficult, such as
the dreaded "units Foo and Bar make inconsistent assumptions about
Baz" error.

## Core concepts

### Rules and targets

OCamlbuild knows about a set of *rules* to build programs, that provide
a piece of OCaml code to build certain kind of files, named *targets*,
from some dependencies (statically known or
dynamically discovered). For example, a built-in "%.ml -> %.cmo" rule
describes how to build any `.cmo` compilation unit file from the `.ml`
of the same name; if you call `ocamlbuild foo.cmo`, it will either use
`foo.ml` in your source directory or, if it doesn't exist, try to
build it, for example from `foo.mll` or `foo.mly`.

OCamlbuild knows various targets to build all sort of useful things:
byte or native programs (`.byte`, `.native`), library archives
(`.cma`, `.cmxa`, `.cmxs`), documentation (`.docdir/index.html`,
`.docdir/man`), etc. We will detail those in the [Reference
section](TODO REF).

### Tags and the `_tags` file

*Tags* are an abstraction layer designed to specify command-line flags
in a declarative style. If you're invoking the compiler directly and
wish to build a program with debug information enabled, you need to pass
the `-g` flag to the compilation and linking step of the build
process, but not during an initial syntactic preprocessing step
(if any), when building `.cma` library archives, or when calling
`ocamldoc`. With OCamlbuild, you can simply add the `debug` tag to
your program's targets, and it will sort out when to insert the `-g`
flag or not.

To attach tags to your OCamlbuild targets, you write them in a `_tags`
file. Each line is of the form `foo: bar`. `bar` is a list of tags,
and `foo` is a filter that determines to which targets `bar`
applies. For example the `_tags` file

    true: package(toto), package(tata)
    <foo.*> or <bar.*>: debug
    "strange.ml": rectypes

will make your whole project (`true` matches anything) depend on the
ocamlfind packages `toto` and `tata`, compile modules `foo` and `bar`
with debug information, and pass `-rectypes` when compiling
`strange.ml` -- but not `strange.mli`. We will detail the syntax of
predicates, and the set of built-in tags in the [Reference
section](TODO REF).

### `myocamlbuild.ml`

The `_tags` file provides a convenient but limited interface to tune
your project. For any more general purpose, we chose to use
a configuration file directly written in OCaml, instead of reinventing
a home-made configuration language -- or using your shell as Make
does. Code put in the `myocamlbuild.ml` file at the root of your
project will be compiled and executed by `ocamlbuild` upon invocation.

For simple use cases, you should not have to write a `myocamlbuild.ml`
file, except maybe to specify project-wide configuration options --
similar to command-line options you would pass to OCamlbuild. But it
also allows to define new rules and targets (for example to support
a shiny new preprocessing program), to define new tags or refine the
meaning of existing tags. We will cover these use-cases in the more
advanced [Plugin section](TODO REF) of the manual.

## A simple program

Simple OCaml projects often have a set of `.ml` and `.mli` files that
provide useful modules depending on each other, and possibly a main
file `myprog.ml` that contains the main program code.

    mod1.ml
    mod1.mli
    mod2.ml
    myprog.ml

You can build your program using either the bytecode compiler, with

    % ocamlbuild myprog.byte

or the native compiler, with

    % ocamlbuild myprog.native

Let's look at the organization of your source directory after this
compilation command:

    _build/
    mod1.ml
    mod1.mli
    mod2.ml
    myprog.byte -> _build/myprog.byte*
    myprog.ml

OCamlbuild does all its work in a single `_build` directory, to help
keep your source directory clean. Targets are therefore built inside
`_build`. It will generally add a symbolic link for the requested
target in the user directory, but if a target does not appear after
being built, chances are it is in `_build`.

## Hygiene

A more irritating feature is that it will actively complain if some
compiled files are left in the source directory.

    % ocamlc -c mod2.ml       # in the source directory of the previous example
    % ocamlbuild myprog.byte

      SANITIZE: a total of 2 files that should probably not be in your
        source tree has been found. A script shell file
        "_build/sanitize.sh" is being created.  Check this script and
        run it to remove unwanted files or use other options (such as
        defining hygiene exceptions or using the -no-hygiene option).
      IMPORTANT: I cannot work with leftover compiled files.
      ERROR: Leftover OCaml compilation files:
        File mod2.cmo in . has suffix .cmo
        File mod2.cmi in . has suffix .cmi
      Exiting due to hygiene violations.

    % rm mod2.cm*

It is possible to exclude some files from this hygiene checking by
tagging them with the `precious` or `not_hygienic` tags, or to disable
the check globally using the `-no-hygiene` command-line option.

The reason for this check is that leftover intermediate files can
disrupt the way your build system work. OCamlbuild knows which target
you need (library archives or program executables), and tries to build
their dependencies, which first builds the dependencies of those
dependencies, etc., until it eventually reaches your source files (the
*inputs* of the build process). Everything present in the source
directory is considered to be an input; if you keep old `.cmo` files
in your source repository, OCamlbuild will not try to rebuild them
from source files, but take them as references to produce the final
targets, which is not what you want if they are stale.

### OCamlfind packages

Your project will probably depend on external libraries as well. Let's
assume they are provided by the ocamlfind packages `tata` and
`toto`. To tell OCamlbuild about them, you should use the tags
`package(tata)` and `package(toto)`. You also need to tell OCamlbuild
to enable support for ocamlfind by passing the `-use-ocamlfind`
command-line option.

So you will have the following `_tags` file:

    true: package(tata), package(toto)

and invoke compilation with

    ocamlbuild -use-ocamlfind myprog.byte

Note: given the pervasiveness of ocamlfind package, you can expect to
always invoke `ocamlbuild` with the `-use-ocamlfind` option. We will
probably enable `-use-ocamlfind` by default in future versions of
OCamlbuild, but in the meantime feel free to define a shell alias for
convenience.

Note 2: If you have a [`myocamlbuild.ml`](#Enriching OCamlbuild through plugins) file at the root of your OCamlbuild
project, you can use it to set this option, instead of using one command line parameter. Something like this:

    open Ocamlbuild_plugin
    let () =
      dispatch (function
        | Before_options ->
          Options.use_ocamlfind := true
        | _ -> ())


### Syntax extensions

If you use syntax extensions distributed through `ocamlfind`, you can
use them as any ocamlfind package, but you must also use the
`syntax(...)` tag to indicate which preprocessor you use: `camlp4o`,
`camlp4r`, `camlp5o`, etc.

    true: syntax(camlp4o)
    true: package(toto), package(blah.syntax)

In recent versions of OCamlbuild (since OCaml 4.01), you can also
specify this using the `-syntax` command-line option:

    ocamlbuild -use-ocamlfind -syntax camlp4o myprog.byte

Note that passing the option `-tag "syntax(camlp4o)"` will also work
in older versions. More generally, `-tag foo` will apply the tag `foo`
to all targets, it is equivalent to adding `true: foo` in your tag
line. Note that the quoting, `-tag "syntax(camlp4o)"` instead of
`-tag syntax(camlp4o)`, is necessary for your shell to understand tags
that have parentheses.

### Archives, documentation...

Some OCamlbuild features require you to add new kind of files in your
source directory. Suppose you would like to distribute an archive file
`mylib.cma` that would contain the compilation unit for your modules
`mod1.ml` and `mod2.ml`. For this, you should create a file
`mylib.mllib` listing the name of desired modules -- capitalized, as
in OCaml source code:

    Mod1
    Mod2

OCamlbuild knows about a rule `"%.mllib -> %.cma"`, so you can then
use:

    ocamlbuild mylib.cma

or, for a native archive

    ocamlbuild mylib.cmxa

(Producing a shared native library `.cmxs` is also supported by
a different form of file with the same syntax, `foo.mldylib`)

Similarly, if you want to invoke `ocamldoc` to document your program,
you should list the modules you want documented in a `.odocl` file. If
you name it `mydoc.odocl` for example, you can then invoke

    ocamlbuild mydoc.docdir/index.html

which will produce the documentation in the subdirectory
`mydoc.docdir`, thanks to a rule `"%.odocl -> %.docdir/index.html"`.

# Reference documentation

In this chapter, we will try to cover the built-in targets and tags
provided by OCamlbuild. We will omit features that are deprecated,
because we found they lead to bad practices or were superseded by
better options. Of course, given that a `myocamlbuild.ml` can add new
rules and tags, this documentation will always be partial.

## File extensions of the OCaml compiler and common tools

A large part of the file extensions in OCamlbuild rules have not been
designed by OCamlbuild itself, but are standard extensions manipulated
by the OCaml compiler. As the reader may not be familiar with them, we
will recapitulate them now. For most use-cases OCamlbuild will hide
most of those subtleties from you, but having this reference is still
useful to understand advanced usage scenarios or read build logs.

- `foo.ml`: OCaml source code, providing the implementation of the module `Foo`

- `foo.mli`: OCaml source code, providing the interface of the module
  `Foo`

- `foo.cmo`: OCaml bytecode-compiled object file, providing the
  implementation of the module `Foo`

- `foo.cmi`: OCaml bytecode-compiled object file, providing the
  interface of the module `Foo`

- `blah.cma`: OCaml bytecode-compiled archive file, containing
  a collection of `.cmo` or `.cma` files, to be used as a library
  (for either static or dynamic linking)

- `foo.cmx`: OCaml native-compiled object file, providing the
  implementation of the module `Foo`

- `foo.o` (`foo.obj` under Windows): complementary native object file
  for the module `Foo`

- `foo.cmxa`: OCaml native-compiled archive file, containing
  a collection of `.cmx` files, for static linking only

- `foo.a` or `foo.lib`: complementary native library files for
  a native-compiled archive file `foo.cmxa`, containing a collection
  of `.o` or `.obj` files

- `foo.cmxs`: OCaml native-compiled archive file (or "plugin") for
  dynamic linking, containing a collection of `.cmx`, `.cmxa`,
  `.o|.obj`, `.a|.lib` files.

The OCaml compilers also accept native files (`.o|.obj`, `.a|.lib` and
even source files `.c`) as input arguments, which get passed to the
native C toolchain (compiler or linker) when producing mixed C/OCaml
programs or libraries.

In addition, the following extensions are not enforced by the compiler
itself, but are commonly used by OCaml tools:

- `foo.mll`: lexer description, to be processed by a lexer generator
  to produce a `foo.ml` file, and possibly `foo.mli`

- `foo.mly`: grammar description, to be processed by a parser
  generator to produce a `foo.ml` file, and possibly `foo.mli`

- `foo.mlp`, `foo.ml4`, `foo.mlip`, `foo.mli4`: common extensions for
  files to be processed by an external preprocessor (`p` for
  "preprocessing" and `4` for Camlp4, an influential
  OCaml preprocessor).

## Targets and rules

The built-in OCamlbuild for OCaml compilation all rely on file
extensions to know which rule to use. Note that this is not imposed by
OCamlbuild rule system, which would allow more flexible patterns. But
it is always the filename of the target that determines which rules to
apply to build it.

In consequence, OCamlbuild adds specific file extensions to the one
listed above (or variations of them), that are the user-interface to
use its rules providing certain features. For example, `.inferred.mli`
is not a standard extension in the OCaml compiler, but it is
understood by a built-in rule of OCamlbuild to ask for the `.mli` that
the compiler can auto-generate by typing a `.ml` file without an
explicit interface: running `ocamlbuild foo.inferred.mli` will first
build `foo.ml` (or find it in the source directory), then generate
`foo.inferred.mli` from it -- users are expected to then inspect it,
hopefully add documentation, and then move it to `foo.mli` by
themselves.

The target extensions understood by OCamlbuild built-in rules are
listed in the following subsections. Again, note that `myocamlbuild`
plugins may add new targets and rules.

### Basic targets

- `.cmi`, `.cmo`, `.cmx`: builds those intermediate files from the
  corresponding source files (`.ml`, and the `.mli` if it exists)

- `.byte`, `.native`: extension of executables generated from a module
  and its dependencies for bytecode and native compilation.

- `.mllib`: contains a list of module paths (`Bar`, `subdir/Baz`) that
  will be compiled and archived together to build a corresponding `.cma`
  or `.cmxa` target.

- `.cma`, `.cmxa`: the preferred way to build a library archive is to
  use a `.mllib` file listing its content. If a `foo.mllib` is absent,
  building the target `foo.cm{,x}a` will create an archive with
  `foo.cm{o,x}` and all the local module it depends upon,
  transitively.

- `.mldylib`: contains a list of module paths (`Bar`, `subdir/Baz`)
  that will be compiled and archived together to build a corresponding
  `.cmxs` target (native plugin). Note that there is no corresponding
  concept of bytecode plugin archive, as `.cma` files (built from
  `.mllib` files) support for static and dynamic linking.

- `.cmxs`: the preferred way to build a plugin archive is to list its
  content in a `.mldylib` file. In absence of `foo.mldylib`,
  building `foo.cmxs` will either:

    - build `foo.cmxa` and copy its content into
      a `.cmxs` file (in particular this means that a `.cmxs` can be
      created from a `.mllib` file), or

    - build `foo.cmx` and create a plugin archive containing exactly
      `foo.cmx`. Note that this differs from the rule for `.cm{,x}a`
      files (whose archive include the dependencies of the module
      `Foo`), in order to avoid dynamically linking the same modules
      several times.

- `.itarget`, `.otarget`: building `foo.itarget` requests the build of
  the targets listed (one per line) in the corresponding `foo.itarget`
  file


### ocamldoc targets

These target will call the documentation generator `ocamldoc`.

- `.odocl`: contains a list of module names for which to produce
  documentation, using one of the targets listed below

- `.docdir/index.html`: building the target
  `foo.docdir/index.thml` will create a subdirectory `foo.docdir`
  containing the HTML documentation of all modules listed in
  `foo.odocl`.

- `.docdir/man`: as `.docdir/index.html` above, but builds the
  documentation in `man` format

- `.docdir/bar.tex` or `.docdic/bar.ltx`: building the target
  `foo.docdir/bar.tex` will build the documentation for the modules
  listed in `foo.odocl`, as a LaTeX file named
  `foo.docdir/bar.tex`. The basename `bar` is not important, but it is
  the extension `.tex` or `.ltx` that indicates to OCamlbuild that
  ocamldoc should be asked for a LaTeX output.

- `.docdir/bar.texi`: same as above, but generates documentation in
  TeXinfo format.

- `.docdir/bar.dot`: same as above, but generates a `.dot` graph of
  inter-module dependencies.

### OCamlYacc and Menhir targets

OCamlbuild will by default use `ocamlyacc`, a legacy parser generator
that is included in the OCaml distribution. The third-party parser
generator [Menhir](TODO URL) is superior in all aspects, so you are
encouraged to use it instead. To enable the use of Menhir instead of
ocamlyacc, you should pass the `-use-menhir` option, or have `true:
use_menhir` in your `_tags` file. OCamlbuild will then activate
menhir-specific builtin rule listed below.

- `.mly` files are grammar description files. They will be passed to
  OCamlYacc to produce the corresponding `.ml` file, or Menhir if it
  is enabled.

- `.mlypack`: Menhir (not ocamlyacc) supports building a parser by
  composing several `.mly` files together, containing different parts
  of the grammar description. Listing module paths in `foo.mlypack`
  will produce `foo.ml` and `foo.mli` by combining the `.mly` files
  corresponding to the listed modules.

- `.mly.depends` and `.mlypack.depends`: Menhir (not ocamlyacc)
  supports calling `ocamldep` to approximate the dependencies of the
  OCaml module on which the generated parser will depend.

### Advanced targets

- `.ml.depends`, `.mli.depends`: call the `ocamldep` tool to compute
  a conservative sur-approximation of the external dependencies of the
  corresponding source file

- `.inferred.mli`: infer a `.mli` interface from the corresponding
  `.ml` file

- `.mlpack`: contains a list of module paths (`Bar`, `subdir/Baz`)
  that can be packed as submodules of a `.cmo` or `.cmx` file: if
  `foo.mlpack` exist, asking for the target `foo.cmx` will build the
  modules listed in `foo.mlpack` and pack them together. Note that the
  native ocaml compiler requires the submodules that will be packed to
  be compiled with the `-for-pack Foo` option (where `Foo` is the name
  of the result of packing), and OCamlbuild does not hide this
  semantics from the user: you can use the built-in parametrized flag
  `for-pack(Foo)` for this purpose. For example, to build `foo.cmx`
  containing `Bar` and `subdir/Baz` as packed-submodules, you should
  have the following:

        foo.mlpack:
          Bar
          subdir/Baz

        _tags:
          <{bar,subdir/baz}.cmx: for-pack(Foo)

- `.byte.o` (`.byte.obj` on Windows), `.byte.so` (`.byte.dll` on
  Windows, `.byte.dylib` on OSX), `.byte.c`: produces object files for
  static or dynamic linking, or a C source file, by passing the
  `-output-obj` option to the OCaml bytecode compiler -- see
  `-output-obj` documentation.

- `.native.(o|obj)`, `.native.(so|dll|dylib)`:
  produces object files for static or dynamic linking by passing the
  `-output-obj` option to the OCaml native compiler -- see
  `-output-obj` documentation.

- `.c`, `.{o,obj}`: OCamlbuild can build `.{o,obj}` files from `.c`
  files by passing them to the OCaml compiler (which in turns calls
  the C toolchain). The OCaml compiler called is `ocamlc` or
  `ocamlopt`, depending on whether or not the `native` flag is set on
  the `.c` source file.

- `.clib`: contains a list of file paths (eg. `foo.o`, not
  module paths) to be linked together (by using the standard
  `ocamlmklib` tool) to produce a `.a` or `.lib` archive
  (for static linking) or a `.so` or `.dll` archive
  (for dynamic linking). If `foo.o` is listed and OCamlbuild is run
  from Windows, `foo.obj` will be used instead. The target name
  includes a `lib` or `dll` prefix, following standard conventions: to
  build a static library from `foo.clib`, you should require the
  target `libfoo.{a,lib}`, and to build a dynamic library you should
  require the target `dllfoo.{so,dll}`.

- `.mltop`, `.top`: requesting the build of `foo.top` will look for
  a list of module paths in `foo.mltop`, and build a custom toplevel
  with all these modules pre-linked -- by using the standard
  `ocamlmktop` tool.

### Deprecated targets

- `.p.*`, `.d.*`:

    OCamlbuild supports requesting `foo.p.{cmx,native}` and
    `foo.d.{cmo,byte}` to build libraries or executables with profiling
    information (`.p`) or debug information (`.d`) enabled. Unfortunately,
    this runs counter the simple scheme used by the OCaml compiler to find
    the object files of a compilation unit dependencies: if `Foo` depends
    on a module `Bar`, the compilation of `foo.p.cmx` will inspect
    `bar.cmx` (rather than `bar.p.cmx`) for cross-module information --
    this is why `.d` is not supported for native code, as this defeats the
    purpose of debug builds. (`.p` is not supported for bytecode because
    bytecode profiling works very differently from native profiling.).

    The more robust solution is to build `foo.{cmo,cmx,byte,native}` with
    the `profile` or `debug` flag set (eg. `ocamlbuild -tag debug
    foo.native`, or using the `_tags` file). If the flag is set for
    certain files only, only those will have debugging or profiling
    information enabled. Note that (contrarily to the `.d.cmx` approach)
    this means you cannot keep a both a with-debug-info and
    a without-debug-info compiled object file for the same module at the
    same time: building `foo.byte` with `true: debug`, then without
    (or conversely) will rebuild all the `.cmo` files of all of `foo`
    dependencies each time.

- `.pp.ml`: This target produces a pretty-printing (as OCaml
  source code) of the OCaml AST produced by preprocessing the
  corresponding `.ml` file. This does not work properly when using
  `ocamlfind` to activate camlp4 preprocessors (the now-preferred way
  to enable syntax extensions), because `ocamlfind` does not provide
  a way to obtain the post-processing output, only to preprocess
  during compilation. Note that passing the `-dsource` compilation
  flag to the OCaml compiler will make it emit the result
  post-processing during compilation (as OCaml source code; use
  `-dparsetree` for a tree view of the AST).

## Tags

TODO

## The `-documentation` option

TODO

# Enriching OCamlbuild through plugins

## How `myocamlbuild.ml` works

If you have a `myocamlbuild.ml` file at the root of your OCamlbuild
project, the building process will run in two steps.

First, OCamlbuild will compile that file, linking it with all the
modules that are part of the globally installed `ocamlbuild`
executable. This will produce a program `_build/myocamlbuild` that
behaves exactly like `ocamlbuild` itself, except that it also runs the
code of your `myocamlbuild.ml` file. Immediately after, OCamlbuild
will stop (before doing any work on the targets you gave it) and start
the `_build/myocamlbuild` program instead, that will handle the rest
of the job. This is quite close to how, for example, XMonad (a window
manager whose configuration files are pure Haskell) works.

This means that it is technically possible to do anything in
`myocamlbuild.ml` that could be done by adding more code to the
upstream OCamlbuild sources. But in practice, relying on the
implementation internals would be fragile with respect to OCamlbuild
version changes.

We thus isolated a subset of the OCamlbuild API, exposed by the
`Ocamlbuild_plugin` module, that defines a stable interface for plugin
writers. It lets you manipulate command-line options, define new rules
and targets, add new tags or refine the meaning of existing flags,
etc. The signature of this module is the `PLUGIN` module type of the
interface-only `signatures.mli` file of the OCamlbuild
distribution. It is littered with comments explaining the purpose of
the exposed values, but this documentation aspect can still be
improved. We warmly welcome patches to improve this aspect of
ocamlbuild -- or any other aspect.

You can influence the `myocamlbuild.ml` compilation-and-launch process
in several ways:

- The `no-plugin` option allows to ignore the `myocamlbuild.ml` file
  and just run the stock `ocamlbuild` executable on your project. This
  mean that fancy new rules introduced by `myocamlbuild.ml` will not
  be available.

- The `-just-plugin` option instructs OCamlbuild to stop compilation
  after having built the plugin; it also guarantees that OCamlbuild
  will try to compile the plugin, which it may not always do, for
  example when you only ask for cleaning or documentation.

- The `-plugin-option FOO` option will pass the command-line option
  `FOO` to the `myocamlbuild` invocation -- and ignore it during
  plugin compilation.

- The `-plugin-tag` and `-plugin-tags` options allow to pass tags
  that will be used to compile the plugin. For example, if someone
  develops a cool library to help writing OCamlbuild plugins and
  distribute as 'toto.ocamlbuild' in ocamlfind, `-plugin-tag
  "package(toto.ocamlbuild)"` will let you use it in your
  `myocamlbuild.ml`.

Note: the rationale for `-plugin-option` and `-plugin-tag` to apply
during different phases of the process is that an option is meaningful
at runtime for the plugin, while a plugin tag is meaningful at
compile-time.


## Dispatch

Tag and rule declarations, or configuration option manipulation, are
side-effects that modify a global OCamlbuild state. It would be
fragile to write your `myocamlbuild.ml` with such side-effects
performed at module initialization time, in the following style

    open Ocamlbuild_plugin
    (* bad style *)
    let () =
      Options.ocamlc := "/better/path/to/ocamlc"
    ;;

The problem is that you have little idea, and absolutely no
flexibility, of the time at which those actions will be performed with
respect to all the other actions of OCamlbuild. In this example,
command-line argument parsing will happen after this plugin effect, so
the changed option would be overridden by command-line options, which
may or may not be what the plugin writer expects.

To alleviate this side-effect order issue, OCamlbuild lets you
register actions at hook points, to be called at a well-defined place
during the OCamlbuild process. If you want your configuration change
to happen after options have been processed, you should in fact write:

    open Ocamlbuild_plugin
    let () =
      dispatch (function
        | After_options ->
          Options.ocamlc := "..."
        | _ -> ())

The `dispatch` function register a hook-listening function provided by
the user; its type is `(hook -> unit) -> unit`. The hooks are
currently defined as

    (** Here is the list of hooks that the dispatch function have to handle.
        Generally one responds to one or two hooks (like After_rules) and do
        nothing in the default case. *)
    type hook =
      | Before_hygiene
      | After_hygiene
      | Before_options
      | After_options
      | Before_rules
      | After_rules

Note: we give no guarantee on the order in which various hooks will be
called, except of course that `Before_foo` always happens before
`After_foo`. In particular, the `hygiene` hooks may be called before
or after other hooks, or not be called at all if OCamlbuild decides
not to check [hygiene](TODO REF ## Hygiene).

## Flag declarations

A flag declaration maps a *set of tags* to a list of command-line
options/flags/arguments. These arguments will be added to a given
compilation command if each of the tags are present on the given
target.

The following example can be found in `ocaml_specific.ml`, the file of
the OCamlbuild sources that defines most ocaml-specific tags and rules
of OCamlbuild:

    flag ["ocaml"; "annot"; "compile"] (A "-annot");

This means that the `-annot` command-line option is added to any
compilation command for which those three tags are present. The tags
`"ocaml"` and `"compile"` are activated by default by OCamlbuild,
`"ocaml"` for any ocaml-related command, and `"compile"` specifically
for compilation steps -- as opposed to linking, documentation
generation, etc. The `"annot"` flag is not passed by default, so this
tag declaration will only take effects on targets that are explicitly
marked `annot` in the `_tags` file.

This very simple declarative language, mapping sets of tags to
command-line options, is the way to give meaning to OCamlbuild tags --
either add new ones or overload existing ones. It is very easy, for
example, to pass a different command-line argument depending on
whether byte or native-compilation is happening.

    flag ["ocaml"; "use_camlp4_bin"; "link"; "byte"]
      (A"+camlp4/Camlp4Bin.cmo");
    flag ["ocaml"; "use_camlp4_bin"; "link"; "native"]
      (A"+camlp4/Camlp4Bin.cmx");

The `A` constructor stands for "atom(ic)", and is part of a `spec`
datatype, representing specifications of fragments of command. We will
not describe its most advanced constructors -- it is again exposed in
`signatures.mli` -- but the most relevant here are as follow:

    (** The type for command specifications. That is pieces of command. *)
    and spec =
      | N              (** No operation. *)
      | S of spec list (** A sequence.  This gets flattened in the last stages *)
      | A of string    (** An atom. *)
      | P of pathname  (** A pathname. *)
      [...]

Remark: when introducing new flags, it is sometime difficult to guess
which combination of tags to use. A hint to find the right combination
is to have a look at OCamlbuild's log file that is saved in
`_build/_log` each time ocamlbuild is run.  It contains the targets
OCamlbuild tried to produce, with the associated list of tags and the
corresponding command lines.

### Parametrized tags

You can also define families of parametrized tags such as
`package(foo)` or `inline(30)`. This is done through the `pflag`
function, which takes a list of usual tags, the special parametrized
tag, and a function from the tag parameter to the corresponding command
specification. Again from the `PLUGIN` module type in `signatures.mli`:

    (** Allows to use [flag] with a parametrized tag (as [pdep] for [dep]).

        Example:
           pflag ["ocaml"; "compile"] "inline"
             (fun count -> S [A "-inline"; A count])
        says that command line option "-inline 42" should be added
        when compiling OCaml modules tagged with "inline(42)". *)
    val pflag : Tags.elt list -> Tags.elt -> (string -> Command.spec) -> unit

## Rule declarations

OCamlbuild let you build your own rules, to teach it how to build new
kind of targets.

TODO

### Stamps

TODO

### Copy rules

TODO

## Complete example: ocamlfind support in OCamlbuild

TODO

# Advanced Examples

## Complex multi-directory code organization

TODO

## Mixing C and OCaml code

TODO

## Using custom preprocessors

TODO

# Contributing to OCamlbuild

TODO
