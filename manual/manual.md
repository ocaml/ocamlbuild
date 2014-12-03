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
wish build a program with debug information enabled, you need to pass
the `-g` flag to the compilation and linking step of the build
process, but not during an initial syntactic preprocessing step
(if any), when building `.cma` library archives, or when calling
`ocamldoc`. With ocamlbuild, you can simply add the `debug` tag to
your program's targets, and it will sort out when to insert the `-g`
flag or not.

To attach tags to your ocamlbuild targets, you write them in a `_tags`
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
similar to command-line options you would pass to ocamlbuild. But it
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

Ocamlbuild does all its work in a single `_build` directory, to help
keep your source directory clean. Targets are therefore built inside
`_build`. It will generally add a symbolic link for the requested
target in the user directory, but if a target does not appear after
being built, chances are it is in `_build`.

A more irritating feature is that it will actively complain if some
compiled files are left in the source directory.

    % ocamlc -c mod2.ml       # in the source directory
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

### OCamlfind packages

Your project will probably depend on external libraries as well. Let's
assume they are provided by the ocamlfind packages `tata` and
`toto`. To tell ocamlbuild about them, you should use the tags
`package(tata)` and `package(toto)`. You also need to tell ocamlbuild
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

Note 2: If you have a [`myocamlbuild.ml`](#Enriching OCamlbuild through plugins) file at the root of your ocamlbuild
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

In recent versions of ocamlbuild (since OCaml 4.01), you can also
specify this using the `-syntax` command-line option:

    ocamlbuild -use-ocamlfind -syntax camlp4o myprog.byte

Note that passing the option `-tag "syntax(camlp4o)"` will also work
in older versions. More generally, `-tag foo` will apply the tag `foo`
to all targets, it is equivalent to adding `true: foo` in your tag
line. Note that the quoting, `-tag "syntax(camlp4o)"` instead of
`-tag syntax(camlp4o)`, is necessary for your shell to understand tags
that have parentheses.

### Archives, documentation...

Some ocamlbuild features require you to add new kind of files in your
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

## Targets and rules

TODO

## Tags

TODO

## The `-documentation` option

TODO

# Enriching OCamlbuild through plugins

## How `myocamlbuild.ml` works

If you have a `myocamlbuild.ml` file at the root of your ocamlbuild
project, the building process will run in two steps.

First, ocamlbuild will compile that file, linking it with all the
modules that are part of the globally installed `ocamlbuild`
executable. This will produce a program `_build/myocamlbuild` that
behaves exactly like `ocamlbuild` itself, except that it also runs the
code of your `myocamlbuild.ml` file. Immediately after, ocamlbuild
will stop (before doing any work on the targets you gave it) and start
the `_build/myocamlbuild` program instead, that will handle the rest
of the job. This is quite close to how, for example, XMonad (a window
manager whose configuration files are pure Haskell) works.

This means that it is technically possible to do anything in
`myocamlbuild.ml` that could be done by adding more code to the
upstream ocamlbuild sources. But in practice, relying on the
implementation internals would be fragile with respect to ocamlbuild
version changes.

We thus isolated a subset of the ocamlbuild API, exposed by the
`Ocamlbuild_plugin` module, that defines a stable interface for plugin
writers. It lets you manipulate command-line options, define new rules
and targets, add new tags or refine the meaning of existing flags,
etc. The signature of this module is the `PLUGIN` module type of the
interface-only `signatures.mli` file of the ocamlbuild
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

- The `-just-plugin` option instructs ocamlbuild to stop compilation
  after having built the plugin; it also guarantees that ocamlbuild
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
side-effects that modify a global ocamlbuild state. It would be
fragile to write your `myocamlbuild.ml` with such side-effects
performed at module initialization time, in the following style

    open Ocamlbuild_plugin
    (* bad style *)
    let () =
      Options.ocamlc := "/better/path/to/ocamlc"
    ;;

The problem is that you have little idea, and absolutely no
flexibility, of the time at which those actions will be performed with
respect to all the other actions of ocamlbuild. In this example,
command-line argument parsing will happen after this plugin effect, so
the changed option would be overridden by command-line options, which
may or may not be what the plugin writer expects.

To alleviate this side-effect order issue, OCamlbuild lets you
register actions at hook points, to be called at a well-defined place
during the ocamlbuild process. If you want your configuration change
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
or after other hooks, or not be called at all if ocamlbuild decides
not to check hygiene.

## Flag declarations

A flag declaration maps a *set of tags* to a list of command-line
options/flags/arguments. These arguments will be added to a given
compilation command if each of the tags are present on the given
target. 

The following example can be found in `ocaml_specific.ml`, the file of
the ocamlbuild sources that defines most ocaml-specific tags and rules
of ocamlbuild:

    flag ["ocaml"; "annot"; "compile"] (A "-annot");

This means that the `-annot` command-line option is added to any
compilation command for which those three tags are present. The tags
`"ocaml"` and `"compile"` are activated by default by ocamlbuild,
`"ocaml"` for any ocaml-related command, and `"compile"` specifically
for compilation steps -- as opposed to linking, documentation
generation, etc. The `"annot"` flag is not passed by default, so this
tag declaration will only take effects on targets that are explicitly
marked `annot` in the `_tags` file.

This very simple declarative language, mapping sets of tags to
command-line options, is the way to give meaning to ocamlbuild tags --
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
is to have a look at ocamlbuild's log file that is saved in
`_build/_log` each time ocamlbuild is run.  It contains the targets
ocamlbuild tried to produce, with the associated list of tags and the
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

TODO

### Stamps

TODO

### Copy rules

TODO

## Complete example: ocamlfind support in ocamlbuild

TODO

# Advanced Examples

## Complex multi-directory code organization

TODO

## Mixing C and OCaml code

TODO

## Using custom preprocessors

TODO

# Contributing to ocamlbuild

TODO
