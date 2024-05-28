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

(* Compatibility with both OCaml < 4.08 and >= 5.00 *)
module Pervasives = struct
  let stdout = stdout
end

(* Original author: Berke Durak *)
(* Ocamlbuild_executor *)

open Unix;;

type error =
  | Subcommand_failed
  | Subcommand_got_signal
  | Io_error
  | Exceptionl_condition

type task = unit -> string;;

type job = {
  job_id      : int * int;
  job_command : string;
  job_next    : task list;
  job_result  : bool ref; (* Result of this sequence group *)
  job_stdout  : in_channel;
  job_stdin   : out_channel;
  job_stderr  : in_channel;
  job_buffer  : Buffer.t;
  job_pid     : int;
  job_tmp_file: string option;
  mutable job_dying : bool;
};;

module JS = Set.Make(struct type t = job let compare = compare end);;
module FDM = Map.Make(struct type t = file_descr let compare = compare end);;

let sf = Printf.sprintf;;
let fp = Printf.fprintf;;

(*** print_unix_status *)
(* FIXME never called *)
let print_unix_status oc = function
  | WEXITED x -> fp oc "exit %d" x
  | WSIGNALED i -> fp oc "signal %d" i
  | WSTOPPED i -> fp oc "stop %d" i
;;
(* ***)
(*** print_job_id *)
let print_job_id oc (x,y) = fp oc "%d.%d" x y;;
(* ***)
(*** output_lines *)
let output_lines prefix oc buffer =
  let u = Buffer.contents buffer in
  let m = String.length u in
  let output_line i j =
    output_string oc prefix;
    output_substring oc u i (j - i);
    output_char oc '\n'
  in
  let rec loop i =
    if i < m then
      let j =
        try String.index_from u i '\n'
        with Not_found -> m
      in
      output_line i j;
      loop (j + 1)
    else
      ()
  in
  loop 0
;;

let open_process_full_win cmd env =
  let (in_read, in_write) = Unix.pipe () in
  let (out_read, out_write) = Unix.pipe () in
  let (err_read, err_write) = Unix.pipe () in
  Unix.set_close_on_exec in_read;
  Unix.set_close_on_exec out_write;
  Unix.set_close_on_exec err_read;
  let inchan = Unix.in_channel_of_descr in_read in
  let outchan = Unix.out_channel_of_descr out_write in
  let errchan = Unix.in_channel_of_descr err_read in
  let shell = Lazy.force Ocamlbuild_pack.My_std.windows_shell in
  let test_cmd =
    String.concat " " (List.map Filename.quote (Array.to_list shell)) ^
    "-ec " ^
    Filename.quote (Ocamlbuild_pack.My_std.prep_windows_cmd cmd) in
  let argv,tmp_file =
    if String.length test_cmd < 7_900 then
      Array.append
        shell
        [| "-ec" ; Ocamlbuild_pack.My_std.prep_windows_cmd cmd |],None
    else
    let fln,ch = Filename.open_temp_file ~mode:[Open_binary] "ocamlbuild" ".sh" in
    output_string ch (Ocamlbuild_pack.My_std.prep_windows_cmd cmd);
    close_out ch;
    let fln' = String.map (function '\\' -> '/' | c -> c) fln in
    Array.append
      shell
      [| "-c" ; fln' |], Some fln in
  let pid =
    Unix.create_process_env argv.(0) argv env out_read in_write err_write in
  Unix.close out_read;
  Unix.close in_write;
  Unix.close err_write;
  (pid, inchan, outchan, errchan,tmp_file)

let close_process_full_win (pid,inchan, outchan, errchan, tmp_file) =
  let delete tmp_file =
    match tmp_file with
    | None -> ()
    | Some x -> try Sys.remove x with Sys_error _ -> () in
  let tmp_file_deleted = ref false in
  try
    close_in inchan;
    close_out outchan;
    close_in errchan;
    let res = snd(Unix.waitpid [] pid) in
    tmp_file_deleted := true;
    delete tmp_file;
    res
  with
  | x when tmp_file <> None && !tmp_file_deleted = false ->
    delete tmp_file;
    raise x

(* ***)
(*** execute *)
(* XXX: Add test for non reentrancy *)
let execute
  ?(max_jobs=max_int)
  ?(ticker=ignore)
  ?(period=0.1)
  ?(display=(fun f -> f Pervasives.stdout))
  ~exit
  (commands : task list list)
    =
  let batch_id = ref 0 in
  let env = environment () in
  let jobs = ref JS.empty in
  let jobs_active = ref 0 in
  let jobs_to_terminate = Queue.create () in
  let commands_to_execute = Queue.create () in
  let all_ok = ref true in
  let results =
    List.map (fun tasks ->
      let result = ref false in
      Queue.add (tasks, result) commands_to_execute;
      result)
      commands
  in
  let outputs = ref FDM.empty in
  let doi = descr_of_in_channel in
  let doo = descr_of_out_channel in
  (*** compute_fds *)
  let compute_fds =
    let fds = ref ([], [], []) in
    let prev_jobs = ref JS.empty in
    fun () ->
      if not (!prev_jobs == !jobs) then
        begin
          prev_jobs := !jobs;
          fds :=
            JS.fold
              begin fun job (rfds, wfds, xfds) ->
                let ofd = doi job.job_stdout
                and ifd = doo job.job_stdin
                and efd = doi job.job_stderr
                in
                (ofd :: efd :: rfds, wfds, ofd :: ifd :: efd :: xfds)
              end
              !jobs
              ([], [], [])
        end;
      !fds
  in
  (* ***)
  (*** add_job *)
  let add_job cmd rest result id =
    (*display begin fun oc -> fp oc "Job %a is %s\n%!" print_job_id id cmd; end;*)
    let (pid,stdout', stdin', stderr', tmp_file) =
      if Sys.win32 then open_process_full_win cmd env else
      let a,b,c = open_process_full cmd env in
      -1,a,b,c,None
    in
    incr jobs_active;
    if not Sys.win32 then (
      set_nonblock (doi stdout');
      set_nonblock (doi stderr');
    );
    let job =
      { job_id          = id;
        job_command     = cmd;
        job_next        = rest;
        job_result      = result;
        job_stdout      = stdout';
        job_stdin       = stdin';
        job_stderr      = stderr';
        job_buffer      = Buffer.create 1024;
        job_dying       = false;
        job_tmp_file    = tmp_file;
        job_pid         = pid }
    in
    outputs := FDM.add (doi stdout') job (FDM.add (doi stderr') job !outputs);
    jobs := JS.add job !jobs;
  in
  (* ***)
  (*** skip_empty_tasks *)
  let rec skip_empty_tasks = function
    | [] -> None
    | task :: tasks ->
        let cmd = task () in
        if cmd = "" then skip_empty_tasks tasks else Some(cmd, tasks)
  in
  (* ***)
  (*** add_some_jobs *)
  let add_some_jobs () =
    let (tasks, result) = Queue.take commands_to_execute in
    match skip_empty_tasks tasks with
    | None -> result := false
    | Some(cmd, rest) ->
      let b_id = !batch_id in
      incr batch_id;
      add_job cmd rest result (b_id, 0)
  in
  (* ***)
  (*** terminate *)
  let terminate ?(continue=true) job =
    if not job.job_dying then
      begin
        job.job_dying <- true;
        Queue.add (job, continue) jobs_to_terminate
      end
    else
      ()
  in
  (* ***)
  (*** add_more_jobs_if_possible *)
  let add_more_jobs_if_possible () =
    while !jobs_active < max_jobs && not (Queue.is_empty commands_to_execute) do
      add_some_jobs ()
    done
  in
  (* ***)
  (*** do_read *)
  let do_read =
    let u = Bytes.create 4096 in
    fun ?(loop=false) fd job ->
      (*if job.job_dying then
        ()
      else*)
        try
          let rec iteration () =
            let m =
              try
                read fd u 0 (Bytes.length u)
              with
              | Unix.Unix_error(Unix.EPIPE,_,_) when Sys.win32 -> 0
              | Unix.Unix_error(e,_,_)  ->
                let msg = error_message e in
                display (fun oc -> fp oc
                        "Error while reading stdout/stderr: %s\n" msg);
                0
            in
            if m = 0 then
              if job.job_dying then
                ()
              else
                terminate job
            else
              begin
                Buffer.add_subbytes job.job_buffer u 0 m;
                if loop then
                  iteration ()
                else
                  ()
              end
          in
          iteration ()
        with
        | x ->
            display
              begin fun oc ->
                fp oc "Exception %s while reading output of command %S\n%!" job.job_command
                  (Printexc.to_string x);
              end;
            exit Io_error
  in
  (* ***)
  (*** process_jobs_to_terminate *)
  let process_jobs_to_terminate () =
    while not (Queue.is_empty jobs_to_terminate) do
      ticker ();
      let (job, continue) = Queue.take jobs_to_terminate in

      (*display begin fun oc -> fp oc "Terminating job %a\n%!" print_job_id job.job_id; end;*)

      decr jobs_active;

      (* PR#5371: we would get EAGAIN below otherwise *)
      if not Sys.win32 then (
        clear_nonblock (doi job.job_stdout);
        clear_nonblock (doi job.job_stderr);
      );
      do_read ~loop:true (doi job.job_stdout) job;
      do_read ~loop:true (doi job.job_stderr) job;
      outputs := FDM.remove (doi job.job_stdout) (FDM.remove (doi job.job_stderr) !outputs);
      jobs := JS.remove job !jobs;
      let status =
        if Sys.win32 then
          close_process_full_win (job.job_pid, job.job_stdout, job.job_stdin, job.job_stderr, job.job_tmp_file)
        else
          close_process_full (job.job_stdout, job.job_stdin, job.job_stderr) in

      let shown = ref false in

      let show_command () =
        if !shown then
          ()
        else
        display
          begin fun oc ->
            shown := true;
            fp oc "+ %s\n" job.job_command;
            output_lines "" oc job.job_buffer
          end
      in
      if Buffer.length job.job_buffer > 0 then show_command ();
      begin
        match status with
        | Unix.WEXITED 0 ->
            begin
              if continue then
                begin
                  match skip_empty_tasks job.job_next with
                  | None -> job.job_result := true
                  | Some(cmd, rest) ->
                      let (b_id, s_id) = job.job_id in
                      add_job cmd rest job.job_result (b_id, s_id + 1)
                end
              else
                all_ok := false;
            end
        | Unix.WEXITED rc ->
            show_command ();
            display (fun oc -> fp oc "Command exited with code %d.\n" rc);
            all_ok := false;
            exit Subcommand_failed
        | Unix.WSTOPPED s | Unix.WSIGNALED s ->
            show_command ();
            all_ok := false;
            display (fun oc -> fp oc "Command got signal %d.\n" s);
            exit Subcommand_got_signal
      end
    done
  in
  (* ***)
  (*** terminate_all_jobs *)
  let terminate_all_jobs () =
    JS.iter (terminate ~continue:false) !jobs
  in
  (* ***)
  (*** loop *)
  let rec loop () =
    (*display (fun oc -> fp oc "Total %d jobs\n" !jobs_active);*)
    process_jobs_to_terminate ();
    add_more_jobs_if_possible ();
    if JS.is_empty !jobs then
      ()
    else
      begin
        let (rfds, wfds, xfds) = compute_fds () in
        ticker ();
        let rec select_non_intr r w x p =
          try select r w x p
          with Unix_error (EINTR, _, _) -> select_non_intr r w x p in
        let (chrfds, chwfds, chxfds) = select_non_intr rfds wfds xfds period in
        List.iter
          begin fun (fdlist, hook) ->
            List.iter
              begin fun fd ->
                try
                  let job = FDM.find fd !outputs in
                  ticker ();
                  hook fd job
                with
                | Not_found -> () (* XXX *)
              end
              fdlist
          end
          [chrfds, do_read ~loop:false;
           chwfds, (fun _ _ -> ());
           chxfds,
             begin fun _ _job ->
               (*display (fun oc -> fp oc "Exceptional condition on command %S\n%!" job.job_command);
               exit Exceptional_condition*)
               () (* FIXME *)
             end];
        loop ()
      end
  in
  try
    loop ();
    None
  with
  | x ->
      begin
        try
          terminate_all_jobs ()
        with
        | x' ->
            display (fun oc -> fp oc "Extra exception %s\n%!" (Printexc.to_string x'))
      end;
      Some(List.map (!) results, x)
;;
(* ***)
