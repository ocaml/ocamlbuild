#use "internal_test_header.ml";;

let () =
  let long_file i = Printf.sprintf "f%0100d" i in
  let last1 = ref "0" in
  let last2 = ref "1" in
  let files = List.init 200 (fun i ->
      let name = long_file i in
      let prev1 = !last1 in
      let prev2 = !last2 in
      last1 := !last2;
      last2 := (String.capitalize_ascii name) ^".x";
      T.f (name ^ ".ml") ~content:(Printf.sprintf "let x = %s + %s" prev1 prev2)
    )
  in
  let files = T.f "fib.ml" ~content:(Printf.sprintf "print_int %s" !last2) :: files in
  test "LongCommand"
  ~options:[]
  ~description:"Check that ocamlbuild can handle long commands"
  ~tree:files
  ~targets:("fib.byte",[]) ();;

let () = test "Preprocess"
    ~description:"Check that preprocessor works"
    ~requirements:ocamlopt_available
    ~options:[]
    ~tree:[
      T.f "main.ml" ~content:{|let () = Printf.printf "line %d\n" __LINE__|};
      T.f "preprocessor.ml" ~content:{|
let () =
  let all = Array.to_list Sys.argv |> List.tl in
  let input = Sys.argv.(3) in
  let txt = Sys.argv.(1) in
  let shift = int_of_string (Sys.argv.(2)) in
  let ic = open_in input in
  for i = 1 to shift do
    print_endline (Printf.sprintf "(* shift lines by one, %s *)" txt);
  done;
  (try
  while true do
    let l = input_line ic in
    print_endline l;
  done;
  with End_of_file -> ());
  print_endline {txt|let () = if __LINE__ <> 4 then failwith "unexpected shift" |txt};
  print_endline (Printf.sprintf {txt|
let () =
  match [%s] with
  | ["with space"; "2"; _file] -> ()
  | l -> failwith (Printf.sprintf "Preprocessor received unexpected args: %%s" (String.concat " - " l))
|txt} (String.concat "; " (List.map (Printf.sprintf "%S") all)))

|};
      T.f "myocamlbuild.ml" ~content:{|
open Ocamlbuild_plugin
let () =
  dispatch begin function
  | After_rules ->
    dep ["mypreprocessor"] ["preprocessor.exe"];
    flag ["ocaml"; "pp"; "mypreprocessor"] (S [P "./preprocessor.exe";
                                               A "with space";
                                               A "2"]);
    rule "native to exe"
    ~prods:["%.exe"]
    ~dep:"%.native"
    (fun env _build ->
      let nat = env "%.native" and exe = env "%.exe" in
      Cmd(S[A "cp"; A nat; A exe]))
  | _ -> ()
  end
|};
      T.f "_tags" ~content:{|
<main.ml>: mypreprocessor
|}]
    ~targets:("main.native", [])
    ~post_cmd:("./main.native")
    ();;

let () = test "BasicNativeTree"
  ~options:[`no_ocamlfind]
  ~description:"Output tree for native compilation"
  ~requirements:ocamlopt_available
  ~tree:[T.f "dummy.ml"]
  ~matching:[M.Exact
                (_build
                   (M.lf
                      ["_digests";
                       "dummy.cmi";
                       "dummy.cmo";
                       "dummy.cmx";
                       "dummy.ml";
                       "dummy.ml.depends";
                       "dummy.native";
                       "dummy" -.- o;
                       "_log"]))]
  ~targets:("dummy.native",[]) ();;

let () = test "BasicByteTree"
  ~options:[`no_ocamlfind]
  ~description:"Output tree for byte compilation"
  ~tree:[T.f "dummy.ml"]
  ~matching:[M.Exact
                (_build
                   (M.lf
                      ["_digests";
                       "dummy.cmi";
                       "dummy.cmo";
                       "dummy.ml";
                       "dummy.ml.depends";
                       "dummy.byte";
                       "_log"]))]
  ~targets:("dummy.byte",[]) ();;

let () = test "SeveralTargets"
  ~options:[`no_ocamlfind]
  ~description:"Several targets"
  ~requirements:ocamlopt_available
  ~tree:[T.f "dummy.ml"]
  ~matching:[_build (M.lf ["dummy.byte"; "dummy.native"])]
  ~targets:("dummy.byte",["dummy.native"]) ();;

let alt_build_dir = "BuIlD2";;

let () = test "BuildDir"
  ~options:[`no_ocamlfind; `build_dir alt_build_dir]
  ~description:"Different build directory"
  ~tree:[T.f "dummy.ml"]
  ~matching:[M.d alt_build_dir (M.lf ["dummy.byte"])]
  ~targets:("dummy.byte",[]) ();;

let tag_pat_msgs =
  ["*:a",
{|File "_tags", line 1, characters 0-2:
Lexing error: Invalid globbing pattern "*".|};

   "\n<*{>:a",
{|File "_tags", line 2, characters 0-5:
Lexing error: Invalid globbing pattern "<*{>".|};

   "<*>: ~@a,# ~a",
{|File "_tags", line 1, characters 10-11:
Lexing error: Only ',' separated tags are allowed.|}];;

List.iteri (fun i (content,failing_msg) ->
  let () = test (Printf.sprintf "TagsErrorMessage_%d" (i+1))
    ~options:[`no_ocamlfind]
    ~description:"Confirm relevance of an error message due to erronous _tags"
    ~output:(failure failing_msg)
    ~tree:[T.f "_tags" ~content; T.f "dummy.ml"]
    ~targets:("dummy.native",[]) ()
  in ()) tag_pat_msgs;;

let () = test "Itarget"
  ~options:[`no_ocamlfind]
  ~description:".itarget building with dependencies between the modules (PR#5686)"
  ~tree:[T.f "foo.itarget" ~content:{|
a.cma
b.byte
|};
         T.f "a.ml";
         T.f "b.ml" ~content:"open A"]
  ~matching:[M.f "a.cma"; M.f "b.byte"]
  ~targets:("foo.otarget",[]) ();;

let () = test "PackAcross"
  ~options:[`no_ocamlfind]
  ~description:"Pack using a module from the other tree (PR#4592)"
  ~requirements:ocamlopt_available
  ~tree:[T.f "main.ml" ~content:"let _ = Pack.Packed.g ()";
         T.f "Pack.mlpack" ~content:"pack/Packed";
         T.f "_tags" ~content:{|
<lib>: include
<pack/*.cmx>: for-pack(Pack)
|};
         T.d "lib" [T.f "Lib.ml" ~content:"let f()=()";
                    T.f "Lib.mli" ~content:"val f : unit -> unit"];
         T.d "pack" [T.f "Packed.ml" ~content:"let g() = Lib.f ()"]]
  ~matching:[M.f "main.byte"; M.f "main.native"]
  ~targets:("main.byte", ["main.native"])
  ();;

let () = test "PackAcross2"
  ~options:[`no_ocamlfind]
  ~description:"Pack using a module from the other tree (PR#4592)"
  ~tree:[T.f "a2.mli" ~content:"val f : unit -> unit";
         T.f "a2.ml" ~content:"let f _ = ()";
         T.f "lib.ml" ~content:"module A = A2";
         T.f "b.ml" ~content:"let g = Lib.A.f";
         T.f "sup.mlpack" ~content:"B";
         T.f "prog.ml" ~content:"Sup.B.g"]
  ~matching:[M.f "prog.byte"]
  ~targets:("prog.byte",[]) ();;

let () = test "PackAcross3"
  ~options:[`no_ocamlfind]
  ~description:"Pack using a module from the other tree (PR#4592)"
  ~tree:[T.d "foo" [ T.f "bar.ml" ~content:"let baz = Quux.xyzzy"];
         T.f "foo.mlpack" ~content:"foo/Bar";
         T.f "main.ml" ~content:"prerr_endline Foo.Bar.baz";
         T.f "myocamlbuild.ml";
         T.f "quux.ml" ~content:{|let xyzzy = "xyzzy"|};
         T.f "quux.mli" ~content:"val xyzzy : string"]
  ~matching:[M.f "main.byte"]
  ~targets:("main.byte",[]) ();;

let () = test "NativeMliCmi"
  ~options:[`no_ocamlfind; `ocamlc "toto" (*using ocamlc would fail*);
            `tags["native"]]
  ~description:"check that ocamlopt is used for .mli->.cmi \
                when tag 'native' is set (part of PR#4613)"
  ~requirements:ocamlopt_available
  ~tree:[T.f "foo.mli" ~content:"val bar : int"]
  ~matching:[_build [M.f "foo.cmi"]]
  ~targets:("foo.cmi",[]) ();;

let () = test "NoIncludeNoHygiene1"
  ~options:[`no_ocamlfind]
  ~description:"check that hygiene checks are only done in traversed directories\
                (PR#4502)"
  ~tree:[T.d "must_ignore" [ T.f "dirty.mli" ~content:"val bug : int"];
         T.f "hello.ml" ~content:{|print_endline "Hello, World!"|};
         T.f "_tags" ~content:"<must_ignore>: -traverse"]
  ~pre_cmd:"ocamlc -c must_ignore/dirty.mli"
            (* will make hygiene fail if must_ignore/ is checked *)
  ~targets:("hello.byte",[]) ();;

let () = test "NoIncludeNoHygiene2"
  ~options:[`no_ocamlfind; `build_dir "must_ignore"]
  ~description:"check that hygiene checks are not done on the -build-dir \
                (PR#4502)"
  ~tree:[T.d "must_ignore" [ T.f "dirty.mli" ~content:"val bug : int"];
         T.f "hello.ml" ~content:{|print_endline "Hello, World!"|};
         T.f "_tags" ~content:""]
  ~pre_cmd:"ocamlc -c must_ignore/dirty.mli"
            (* will make hygiene fail if must_ignore/ is checked *)
  ~targets:("hello.byte",[]) ();;

let () = test "NoIncludeNoHygiene3"
  ~options:[`no_ocamlfind; `X "must_ignore"]
  ~description:"check that hygiene checks are not done on excluded dirs (PR#4502)"
  ~tree:[T.d "must_ignore" [ T.f "dirty.mli" ~content:"val bug : int"];
         T.f "hello.ml" ~content:{|print_endline "Hello, World!"|};
         T.f "_tags" ~content:""]
  ~pre_cmd:"ocamlc -c must_ignore/dirty.mli"
            (* will make hygiene fail if must_ignore/ is checked *)
  ~targets:("hello.byte",[]) ();;

let () = test "OutputObj"
  ~options:[`no_ocamlfind]
  ~description:"output_obj targets for native and bytecode (PR #6049)"
  ~requirements:ocamlopt_available
  ~tree:[T.f "hello.ml" ~content:{|print_endline "Hello, World!"|}]
  ~targets:("hello.byte" -.- o,["hello.byte.c";"hello.native" -.- o]) ();;

let () = test "OutputShared"
  ~options:[`no_ocamlfind]
  ~description:"output_shared targets for native and bytecode (PR #6733)"
  ~requirements:ocamlopt_available
  ~tree:[T.f "hello.ml" ~content:{|print_endline "Hello, World!"|};
         T.f "_tags" ~content:"<*.so>: runtime_variant(_pic)"]
  ~targets:("hello.byte" -.- so,["hello.native" -.- so]) ();;

let () = test "CmxsStubLink"
  ~options:[`no_ocamlfind]
  ~description:".cmxs link rules pass correct -I flags"
  ~requirements:ocamlopt_available
  ~tree:[T.d "src" [
           T.f "foo_stubs.c" ~content:{|
#include <stdio.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
CAMLprim value hello_world(value unit)
{
  CAMLparam1 (unit);
  printf("Hello World!\n");
  CAMLreturn (Val_unit);
}
|};
           T.f "libfoo_stubs.clib" ~content:("foo_stubs" -.- o) ;
           T.f "foo.ml" ~content:"";
         ];
         T.f "_tags" ~content:{|
<src/foo.{cma,cmxa}> : record_foo_stubs
<src/foo.cmxs> : link_foo_stubs
|};
         T.f "myocamlbuild.ml" ~content:{|
open Ocamlbuild_plugin
let () =
  dispatch begin function
  | After_rules ->
      dep ["record_foo_stubs"] ["src/libfoo_stubs" -.- !Options.ext_lib];
      flag_and_dep
        ["link"; "ocaml"; "link_foo_stubs"] (P ("src/libfoo_stubs" -.- !Options.ext_lib));
      flag ["library"; "ocaml"; "record_foo_stubs"]
        (S ([A "-cclib"; A "-lfoo_stubs"]));
  | _ -> ()
  end
|}]
  ~targets:("src/foo.cmxs",[]) ();;

let () = test "StrictSequenceFlag"
  ~options:[`no_ocamlfind; `quiet]
  ~description:"strict_sequence tag"
  ~tree:[T.f "hello.ml" ~content:"let () = 1; ()";
         T.f "_tags" ~content:{|
true: strict_sequence
|}]
  ~output:(failure
             ~filter:(
               List.filter (function
                   | "Command exited with code 2." -> true
                   | x -> starts_with_plus x))
             "+ ocamlc.opt -c -strict-sequence -o hello.cmo hello.ml\n\
              Command exited with code 2.")
  ~targets:("hello.byte",[]) ();;

let () = test "StrictFormatsFlag"
  ~options:[`no_ocamlfind; `quiet]
  ~description:"strict_format tag"
  ~tree:[T.f "hello.ml" ~content:{|let _ = Printf.printf "%.10s"|};
         T.f "_tags" ~content:{|
true: strict_formats
|}]
  ~output:(failure
             ~filter:(
               List.filter (function
                   | "Command exited with code 2." -> true
                   | x -> starts_with_plus x))
             "+ ocamlc.opt -c -strict-formats -o hello.cmo hello.ml\n\
              Command exited with code 2.")
  ~targets:("hello.byte",[]) ();;

let () = test "PrincipalFlag"
  ~options:[`no_ocamlfind; `quiet]
  ~description:"-principal tag"
  ~tree:[T.f "hello.ml"
           ~content:
{|type s={foo:int;bar:unit} type t={foo:int}
let f x = (x.bar; x.foo)
|};
         T.f "_tags" ~content:{|
true: principal
|}]
  ~output:(success
             ~filter:(
               List.filter_map (fun x ->
                   if starts_with_plus x
                   then Some x
                   else if starts_with ~prefix:"Warning" x
                   then Some (normalize_warning x)
                   else None))
             "+ ocamlc.opt -c -principal -o hello.cmo hello.ml\n\
              Warning 18: this type-based field disambiguation is not principal.") (* -principal warns, there is no error *)
  ~targets:("hello.byte",[]) ();;

let () = test "ModularPlugin1"
  ~description:"test a plugin with dependency on external libraries"
  ~options:[`no_ocamlfind; `quiet; `plugin_tag "use_str"]
  ~tree:[T.f "main.ml" ~content:"let x = 1";
         T.f "myocamlbuild.ml" ~content:{|ignore (Str.quote "");;|}]
  ~matching:[M.f "main.byte"]
  ~targets:("main.byte",[]) ();;

let () = test "ModularPlugin2"
  ~description:"check that parametrized tags defined by the plugin \
                do not warn at plugin-compilation time"
  ~requirements:ocamlopt_available
  ~options:[`no_ocamlfind; `quiet]
  ~tree:[T.f "main.ml" ~content:"let x = 1";
         T.f "_tags" ~content:"<main.*>: toto(-g)";
         T.f "myocamlbuild.ml"
           ~content:{|
open Ocamlbuild_plugin;;
pflag ["link"] "toto" (fun arg -> A arg);;
|}]
  ~output:(success "")
  ~matching:[M.f "main.byte"]
  ~targets:("main.byte",[]) ();;

let () = test "ModularPlugin3"
  ~description:"check that unknown parametrized tags encountered \
                during plugin compilation still warn"
  ~requirements:ocamlopt_available
  ~options:[`no_ocamlfind; `quiet; `plugin_tag "toto(-g)"]
  ~tree:[T.f "main.ml" ~content:"let x = 1";
         T.f "myocamlbuild.ml"
           ~content:{|
open Ocamlbuild_plugin;;
pflag ["link"] "toto" (fun arg -> A arg);;
|} ]
  ~output:(success
    {|Warning: tag "toto" does not expect a parameter, but is used with parameter "-g"|})
  ~matching:[M.f "main.byte"]
  ~targets:("main.byte",[]) ();;

let () = test "PluginCompilation1"
  ~description:"check that the plugin is not compiled when -no-plugin is passed"
  ~options:[`no_ocamlfind; `no_plugin]
  ~tree:[T.f "main.ml" ~content:"let x = 1";
         T.f "myocamlbuild.ml" ~content:{|prerr_endline "foo";;|}]
  ~matching:[_build [M.Not (M.f ("myocamlbuild" ^ Ocamlbuild_config.exe))]]
  ~targets:("main.byte",[]) ();;

let () = test "PluginCompilation2"
  ~description:"check that the plugin is compiled when -just-plugin is passed"
  ~options:[`no_ocamlfind; `just_plugin]
  ~tree:[T.f "main.ml" ~content:"let x = 1";
         T.f "myocamlbuild.ml" ~content:{|print_endline "foo";;|}]
  ~matching:[_build [M.f ("myocamlbuild" ^ Ocamlbuild_config.exe)]]
  ~targets:("", []) ();;

let () = test "PluginCompilation3"
  ~description:"check that the plugin is not executed \
                when -just-plugin is passed"
  ~requirements:ocamlopt_available
  ~options:[`no_ocamlfind; `quiet; `just_plugin]
  ~tree:[T.f "main.ml" ~content:"let x = 1";
         T.f "myocamlbuild.ml" ~content:{|print_endline "foo";;|}]
  (* if the plugin were executed we'd get "foo" in the output *)
  ~output:(success "")
  ~targets:("main.byte", []) ();;

let () = test "PluginTagsWarning"
  ~description:"check that a warning is raised if -plugin-tags \
                is used without a plugin file"
  ~options:[`no_ocamlfind; `plugin_tag "use_str"]
  ~tree:[T.f "main.ml" ~content:""]
  ~matching:[_build [M.f "main.cmo"]]
  ~output:(success
    {|Warning: option -plugin-tag(s) has no effect in absence of plugin file "myocamlbuild.ml"|})
  ~targets:("main.cmo", []) ();;

let () = test "TagsInNonHygienic"
  ~description:"Regression test for PR#6482, where a _tags \
                in a non-traversed directory would cause \
                ocamlbuild to abort"
  ~options:[`no_ocamlfind]
  ~tree:[
    T.f "main.ml" ~content:"";
    T.d "deps" [T.f "_tags" ~content:""];
    T.f "_tags" ~content:{|
<deps>: not_hygienic
|};
  ]
  ~matching:[M.f "main.byte"]
  ~targets:("main.byte",[]) ();;

let () = test "TagsNewlines"
  ~description:"Regression test for PR#6087 about placement \
                of newline-escaping backslashes"
  ~options:[`no_ocamlfind]
  ~tree:[
    T.f "main.ml" ~content:"";
    T.f "_tags" ~content:{|
<foo>: debug,\
rectypes
<bar>: \
debug, rectypes
<baz>\
: debug, rectypes
|};
  ]
  ~matching:[M.f "main.byte"]
  ~targets:("main.byte",[]) ();;

let () = test "OpenTag"
  ~description:"Test the parametrized tag for the new -open feature"
  ~options:[`no_ocamlfind]
  ~tree:[
    T.f "test.ml" ~content:"let _ = map rev [ []; [3;2] ]";
    T.f "_tags" ~content: "<test.*>: open(List)";
  ]
  ~matching:[M.f "test.byte"]
  ~targets:("test.byte",[]) ();;

let () = test "OpenDependencies"
  ~description:"Test dependency computation for the new -open feature (PR#6584)"
  ~options:[`no_ocamlfind]
  ~tree:[
    T.f "a.ml" ~content:"let x = 1";
    T.f "b.ml" ~content:"print_int x; print_newline ()";
    T.f "_tags" ~content: "<b.*>: open(A)";
  ]
  ~matching:[M.f "b.byte"]
  ~targets:("b.byte",[]) ();;

let () = test "TargetsStartingWithUnderscore"
  ~description:"Build targets whose name starts with '_'"
(*
  requested by Daniel Bünzli on the caml-list:
     Subject: [Caml-list] ocamlbuild, build a source that starts with _
     Date: Tue, 9 Feb 2016 14:35:06 +0100
     https://sympa.inria.fr/sympa/arc/caml-list/2016-02/msg00033.html
*)
  ~options:[`no_ocamlfind]
  ~tree:[ T.f "_a.c" ~content:"" ]
  ~targets:("_a" -.- o, []) ();;

let () = test "OpaqueEverything"
  ~description:"Check that tagging everything opaque does not break build"
(*
  Since 4.03, ocamlc also handles the -opaque flag and it has
  an interesting semantics when compiling .cmi flags. This means that
  under 4.03 we must add the -opaque flags on .cmi targets, while
  this would break compilation under older version. Check that code
  previously written with "-tag opaque" does not break on older OCaml
  versions.
*)
  ~options:[`no_ocamlfind; `tag "opaque"]
  ~tree:[ T.f "test.mli" ~content:"val x : int";
          T.f "test.ml"  ~content:"let x = 123"; ]
  ~targets:("test.byte", []) ();;

let () = test "ForPackEverything"
  ~description:"Check that tagging everything with -for-pack does not break build"
(*
  OCaml's PR#5995 highlighted that also using -for-pack for bytecode
  compilation was benefitial in some situations (when using OCaml 4.03
  or higher), so we changed ocamlbuild to pass the -for-pack flag
  under both native and bytecode compilation, instead of just native.
  Check that this does not break bytecode compilation.
*)
  ~options:[`no_ocamlfind; `tag "for-pack(Foo)"]
  ~tree:[ T.f "test.mli" ~content:"val x : int";
          T.f "test.ml"  ~content:"let x = 123"; ]
  ~targets:("test.cmo", []) ();;

let () = test "CLibFromCObj"
  ~description:"Build a C library from a C object file"
  ~options:[`no_ocamlfind; `no_plugin]
  ~tree:[
    T.f "test.c" ~content:{|
#include <stdio.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
CAMLprim value hello_world(value unit)
{
  CAMLparam1 (unit);
  printf("Hello World!\n");
  CAMLreturn (Val_unit);
}
|};
  ]
  ~targets:("libtest" -.- a, []) ();;

let () = test "JustNoPlugin"
    ~description:"(ocamlbuild -just-plugin) should do nothing when no plugin is there"
    ~options:[`no_ocamlfind; `just_plugin]
    ~tree:[T.f "test.ml" ~content:{|print_endline "Hellow World"|};]
    (* we check that the target is *not* built *)
    ~matching:[_build [M.Not (M.f "test.cmo")]]
    ~targets:("test.cmo", [])
    ();;

let () = test "CmxsFromMllib1"
  ~description:"Check that a .cmxs file can be built from a .mllib file"
  ~requirements:ocamlopt_available
  ~options:[`no_ocamlfind; `no_plugin]
  ~tree:[
    T.f "a.ml" ~content:"let a = 1";
    T.f "b.ml" ~content:"let b = true";
    T.f "foo.mllib" ~content:{|
A
B
|};
  ]
  ~targets:("foo.cmxs", []) ();;

let () = test "CmxsFromMllib2"
  ~description:"Check that a .cmxs file can be built from a .mllib file, \
                even when one of the module has the same name as the library"
  ~requirements:ocamlopt_available
  ~options:[`no_ocamlfind; `no_plugin]
  ~tree:[
    T.f "a.ml" ~content:"let a = 1";
    T.f "b.ml" ~content:"let b = true";
    T.f "foo.ml" ~content:"let foo = (A.a, B.b)";
    T.f "foo.mllib" ~content:{|
A
B
Foo
|};
  ]
  ~targets:("foo.cmxs", []) ();;


let () = test "MldylibOverridesMllib"
  ~description:"Check that the rule producing a cmxs from a .mllib only \
                triggers if there is no .mldylib"
  ~requirements:ocamlopt_available
(*
   GPR #132 (requested by issue #131) adds a new rule which allows producing a
   .cmxs from a .mllib, where previously this was only possible by providing
   a separate .mldylib file. This test ensures that the added rule behaves
   conservatively, i.e. only triggers when no .mldylib file can be found.
*)
  ~options:[`no_ocamlfind; `no_plugin]
  ~matching:[_build [M.Not (M.f "bar.cmi")]]
  ~tree:[
    T.f "foo.ml";
    T.f "bar.ml";
    T.f "mylib.mllib" ~content:{|
FooBar
|};
    T.f "mylib.mldylib" ~content:"Foo";
  ]
  ~targets:("mylib.cmxs", []) ();;

let () = test "MldylibOverridesCmx"
  ~description:"Check that the rule producing foo.cmxs from foo.mldylib \
                takes precedence over the one that uses foo.cmx"
  ~requirements:ocamlopt_available
  ~options:[`no_ocamlfind; `no_plugin]
  ~matching:[_build [M.f "bar.cmi"]]
  ~tree:[
    T.f "foo.ml";
    T.f "bar.ml";
    T.f "foo.mldylib" ~content:{|
Foo
Bar
|};
  ]
  ~targets:("foo.cmx", ["foo.cmxs"]) ();;

let () = test "MllibOverridesCmx"
  ~description:"Check that the rule producing foo.cmxs from foo.mllib \
                takes precedence over the one that uses foo.cmx"
  ~requirements:ocamlopt_available
  ~options:[`no_ocamlfind; `no_plugin]
  ~matching:[_build [M.f "bar.cmi"]]
  ~tree:[
    T.f "foo.ml";
    T.f "bar.ml";
    T.f "foo.mllib" ~content:{|
Foo
Bar
|};
  ]
  ~targets:("foo.cmx", ["foo.cmxs"]) ();;

let () = test "cleanIsQuiet"
  ~description:"clean is quiet"
  ~options:[]
  ~output:(success ~filter:(fun x -> x) "")
  ~targets:("-clean",[]) ()
;;

run ~root:"_test_internal";;
