match sys_command "ocamlfind ocamlc -version" with
    | 0 -> ()
    | _ ->
      prerr_endline "Having ocamlfind installed is a prerequisite \
                     for running these tests. Aborting.";
      exit 1;
;;

#use "topfind";;
