{
    exception Error of string
    let error fmt = Printf.kprintf (fun msg -> raise (Error msg)) fmt

    let get = Lexing.lexeme
}

rule escape b = parse
  | '&'             { Buffer.add_string b "&amp;";  escape b lexbuf } 
  | '"'             { Buffer.add_string b "&quot;"; escape b lexbuf } 
  | '\''            { Buffer.add_string b "&apos;"; escape b lexbuf }
  | '>'             { Buffer.add_string b "&gt;";   escape b lexbuf }
  | '<'             { Buffer.add_string b "&lt;";   escape b lexbuf }
  | [^'&' '"' '\'' '>' '<']+ 
                    { Buffer.add_string b @@ get lexbuf
                    ; escape b lexbuf
                    }
  | eof             { let x = Buffer.contents b in Buffer.clear b; x }
  | _               { error "don't know how to quote: %s" (get lexbuf) }

{
let html str =
    let b       = Buffer.create @@ String.length str in
    let lexbuf  = Lexing.from_string str in 
        escape b lexbuf
}

