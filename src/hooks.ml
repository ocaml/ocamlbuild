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
type message =
  | Before_hygiene
  | After_hygiene
  | Before_options
  | After_options
  | Before_rules
  | After_rules

let hooks = ref None

let setup_hooks f =
  match !hooks with
  | None -> hooks := Some f
  | Some _ ->
      Log.eprintf "%a" Format.pp_print_text
        "Warning: your myocamlbuild.ml plugin seems to be setting \
         up several dispatch hooks through several calls to \
         Ocamlbuild_plugin.dispatch. This is not supported, \
         all dispatch functions but the last one will be discarded.\n\
         \n\
         You should not install several hook handlers, but rather \
         combine several handler functions explicitly in a single \
         dispatch call. This lets you declare the order between \
         sub-hooks instead of relying on some implicit evaluation \
         effect order.\n";
      hooks := Some f

let call_hook m =
  match !hooks with
  | None -> ()
  | Some hook -> hook m
