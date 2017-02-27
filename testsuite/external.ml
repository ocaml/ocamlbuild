#use "internal_test_header.ml";;
#use "findlibonly_test_header.ml";;
#use "external_test_header.ml";;

let () = test "camlp4.opt"
  ~description:"Fixes PR#5652"
  ~options:[`package "camlp4.macro";`tags ["camlp4o.opt"; "syntax\\(camp4o\\)"];
            `ppflag "camlp4o.opt"; `ppflag "-parser"; `ppflag "macro";
            `ppflag "-DTEST"]
  ~tree:[T.f "dummy.ml"
            ~content:"IFDEF TEST THEN\nprint_endline \"Hello\";;\nENDIF;;"]
  ~matching:[M.x "dummy.native" ~output:"Hello"]
  ~targets:("dummy.native",[]) ();;

let () = test "SyntaxFlag"
  ~options:[`use_ocamlfind; `package "camlp4.macro"; `syntax "camlp4o"]
  ~description:"-syntax for ocamlbuild"
  ~tree:[T.f "dummy.ml" ~content:"IFDEF TEST THEN\nprint_endline \"Hello\";;\nENDIF;;"]
  ~matching:[M.f "dummy.native"]
  ~targets:("dummy.native",[]) ();;

let () = test "SubtoolOptions"
  ~description:"Options that come from tags that needs to be spliced \
                to the subtool invocation (PR#5763)"
  (* testing for the 'menhir' executable directly
     is too hard to do in a portable way; test the ocamlfind package instead *)
  ~requirements:(package_exists "menhirLib")
  ~options:[`use_ocamlfind; `use_menhir; `tags ["package(camlp4.fulllib)"]]
  ~tree:[T.f "parser.mly"
            ~content:"%{ %}
                      %token DUMMY
                      %start<Camlp4.PreCast.Syntax.Ast.expr option> test
                      %%
                      test: DUMMY {None}"]
  ~matching:[M.f "parser.native"; M.f "parser.byte"]
  ~targets:("parser.native",["parser.byte"])
  ();;

run ~root:"_test_external";;
