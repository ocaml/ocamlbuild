(* Fullfilled and Missing are defined in ocamlbuild_test.ml
   Findlib was loaded in findlibonly_test_header.ml *)
let package_exists package =
  let open Findlib in
  try
    let dir = package_directory package in
    Printf.eprintf "%s found in %s\n%!" package dir;
    Fullfilled
  with No_such_package _ ->
    Missing (Printf.sprintf "the ocamlfind package %s" package)

let req_and a b =
  match a, b with
  | Fullfilled, Fullfilled -> Fullfilled
  | Missing _ as x, Fullfilled
  | Fullfilled, (Missing _ as x) -> x
  | Missing a, Missing b -> Missing (Printf.sprintf "%s, %s" a b)
