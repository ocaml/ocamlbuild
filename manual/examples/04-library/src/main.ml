
module J = Yojson.Basic

let json file = 
  J.from_file file |> J.to_channel stdout

let main () =
  let argv = Array.to_list Sys.argv in
  let args = List.tl argv in
  let this = List.hd argv in
  match args with
  | [file]    -> json file
  | _         -> Printf.eprintf "usage: %s file.json" this; exit 1

let () = main ()        

