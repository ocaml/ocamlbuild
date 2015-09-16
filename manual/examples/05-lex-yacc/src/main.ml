
let main () =
  let argv = Array.to_list Sys.argv in
  let escape strings = 
    strings
    |> List.map Lexer.html 
    |> Util.join 
    |> print_endline
  in match List.tl argv with
  | []   -> escape [ Hello.hello ]
  | args -> escape args

let () = main ()        

