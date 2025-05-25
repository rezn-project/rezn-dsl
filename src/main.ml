open Frontend

let () =
  if Array.length Sys.argv <> 2 then begin
    Printf.eprintf "Usage: %s <file.rezn>\n" Sys.argv.(0);
    exit 1
  end;

  let filename = Sys.argv.(1) in
  let prog = parse_file filename in
  let json = Codegen.program_to_json prog in
  Yojson.Basic.pretty_to_channel stdout json;
  print_newline ()
  
