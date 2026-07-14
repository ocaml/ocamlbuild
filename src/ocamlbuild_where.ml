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

module O = Ocamlbuild_config;;

let bindir = ref O.bindir;;

(* Check if a directory contains a file that libdir is expected to contain. *)
let libdir_contains_ocamlbuild_library libdir =
  Sys.file_exists (Filename.concat libdir "ocamlbuild.cma") ||
    Sys.file_exists (Filename.concat libdir "ocamlbuild.cmx")

(* Try to guess the libdir from the current exe's location. *)
let guess_libdir_from_executable_name () =
  let guessed_bin_dir = Filename.dirname Sys.executable_name in
  Filename.concat
    (Filename.concat (Filename.dirname guessed_bin_dir) "lib")
    "ocamlbuild"

let libdir = ref begin
  let root, suffix =
    let ocaml_lib_len = String.length O.ocaml_libdir + 1 in
    let lib_len = String.length O.libdir_abs in
    (* Windows note: O.ocaml_libdir and O.libdir_abs have both been passed
       through GNU make's abspath function and will be forward-slash normalised.
       Filename.dir_sep is therefore not appropriate here. *)
    if lib_len < ocaml_lib_len
       || String.sub O.libdir_abs 0 ocaml_lib_len <> O.ocaml_libdir ^ "/" then
      O.libdir, "ocamlbuild"
    else
      (* https://github.com/ocaml/ocamlbuild/issues/69. Only use OCAMLLIB if
         the configured LIBDIR is a subdirectory (lexically) of OCAML_LIBDIR.
         If it is, append the difference between LIBDIR and OCAML_LIBDIR to
         OCAMLLIB. This allows `OCAMLLIB=/foo ocamlbuild -where` to return
         /foo/site-lib/ocamlbuild for a findlib-based installation and also
         to ignore OCAMLLIB in an opam-based installation (where setting
         OCAMLLIB is already a strange thing to have done). *)
      try
        let normalise_slashes =
          if Sys.win32 then
            String.map (function '/' -> '\\' | c -> c)
          else
            function s -> s
        in
        let subroot =
          String.sub O.libdir_abs ocaml_lib_len (lib_len - ocaml_lib_len)
          |> normalise_slashes
        in
        Sys.getenv "OCAMLLIB", Filename.concat subroot "ocamlbuild"
      with Not_found -> O.libdir, "ocamlbuild"
  in
  let libdir = Filename.concat root suffix in
  if libdir_contains_ocamlbuild_library libdir then
    libdir
  else
    (* The libdir doesn't contain the ocamlbuild library. Maybe the ocamlbuild
       installation has been moved to a new location after installation. Try to
       guess the libdir from the current exe's path. *)
    let guessed_libdir = guess_libdir_from_executable_name () in
    if libdir_contains_ocamlbuild_library guessed_libdir then (
      Printf.eprintf "Warning: The library directory where ocamlbuild was \
        originally installed (%s) either no longer exists, or does not contain \
        a copy of the ocamlbuild library. Guessing that the correct library \
        directory is %s because a copy of the ocamlbuild library exists at that \
        location, and because it is located at the expected path relative to \
        the current ocamlbuild executable. This can happen if ocamlbuild's \
        files are moved from the location where they were originally \
        installed."
        libdir
        guessed_libdir;
      guessed_libdir)
    else
      (* The guessed path also doesn't contain the ocamlbuild library, so just
         return the original libdir to help the user debug the error which will
         likely result. *)
      libdir
end;;
