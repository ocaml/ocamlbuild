(***********************************************************************)
(*                                                                     *)
(*                             ocamlbuild                              *)
(*                                                                     *)
(*  Nicolas Pouillard, Berke Durak, projet Gallium, INRIA Rocquencourt *)
(*                                                                     *)
(*  Copyright 2007 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)


(* Original author: Nicolas Pouillard *)
open My_std

type file_kind =
| FK_dir
| FK_file
| FK_link
| FK_other

type stats =
  {
    stat_file_kind : file_kind;
    stat_key       : string
  }

let report_error f =
  function
  | Unix.Unix_error(err, fun_name, arg) ->
      Format.fprintf f "%s: %S failed" Sys.argv.(0) fun_name;
      if String.length arg > 0 then
        Format.fprintf f " on %S" arg;
      Format.fprintf f ": %s" (Unix.error_message err)
  | exn -> raise exn

let mkstat unix_stat x =
  let st =
    try unix_stat x
    with Unix.Unix_error _ as e -> raise (Sys_error (My_std.sbprintf "%a" report_error e))
  in
  { stat_key = Printf.sprintf "(%d,%d)" st.Unix.st_dev st.Unix.st_ino;
    stat_file_kind =
      match st.Unix.st_kind with
      | Unix.S_LNK -> FK_link
      | Unix.S_DIR -> FK_dir
      | Unix.S_CHR | Unix.S_BLK | Unix.S_FIFO | Unix.S_SOCK -> FK_other
      | Unix.S_REG -> FK_file }

let is_link s = (Unix.lstat s).Unix.st_kind = Unix.S_LNK

let at_exit_once callback =
  let pid = Unix.getpid () in
  at_exit begin fun () ->
    if pid = Unix.getpid () then callback ()
  end

let run_and_open s kont =
  let ic, cleanup =
    if Sys.win32
    then
      let args, cleanup = My_std.prepare_command_for_windows s in
      Unix.open_process_args_in args.(0) args, cleanup
    else Unix.open_process_in s, None in
  let close () =
    match Unix.close_process_in ic with
    | Unix.WEXITED 0 -> Option.iter (fun f -> f ()) cleanup
    | Unix.WEXITED _ | Unix.WSIGNALED _ | Unix.WSTOPPED _ ->
      Option.iter (fun f -> f ()) cleanup;
      failwith (Printf.sprintf "Error while running: %s" s) in
  let res = try
      kont ic
    with e -> (close (); raise e)
  in close (); res

let stdout_isatty () =
  Unix.isatty Unix.stdout &&
    try Unix.getenv "TERM" <> "dumb" with Not_found -> true

let execute_many =
  let exit i = raise (My_std.Exit_with_code i) in
  let exit = function
    | Ocamlbuild_executor.Subcommand_failed -> exit Exit_codes.rc_executor_subcommand_failed
    | Ocamlbuild_executor.Subcommand_got_signal -> exit Exit_codes.rc_executor_subcommand_got_signal
    | Ocamlbuild_executor.Io_error -> exit Exit_codes.rc_executor_io_error
    | Ocamlbuild_executor.Exceptionl_condition -> exit Exit_codes.rc_executor_excetptional_condition
  in
  Ocamlbuild_executor.execute ~exit

(* Ocamlbuild code assumes throughout that [readlink] will return a file name
   relative to the current directory. Let's make it so. *)
let readlink x =
  let y = Unix.readlink x in
  if Filename.is_relative y then
    Filename.concat (Filename.dirname x) y
  else
    y

let stat = mkstat Unix.stat
let lstat = mkstat Unix.lstat
let gettimeofday = Unix.gettimeofday

let run_and_read cmd =
  let bufsiz = 2048 in
  let buf = Bytes.create bufsiz in
  let totalbuf = Buffer.create 4096 in
  run_and_open cmd begin fun ic ->
    let rec loop pos =
      let len = input ic buf 0 bufsiz in
      if len > 0 then begin
        Buffer.add_subbytes totalbuf buf 0 len;
        loop (pos + len)
      end
    in loop 0; Buffer.contents totalbuf
  end
