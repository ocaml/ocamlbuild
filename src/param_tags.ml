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

open My_std

(* Original author: Romain Bardou *)

(* tag name -> tag action (string -> unit) *)
let declared_tags = Hashtbl.create 17

module TagsSet = Set.Make(Tags)

type tags_multi =
  { mutable actions : (StringSet.t -> unit) list;
    mutable seen_instances : Tags.t;
    mutable processed_tag_sets : TagsSet.t }

(* tag name -> tags_multi *)
let declared_tags_multi = Hashtbl.create 17

let acknowledged_tags = ref []

(* [= union of x.seen_instances for x in declared_tags_multi] *)
let all_tags_multi = ref Tags.empty

let only_once f =
  let instances = ref StringSet.empty in
  fun param ->
    if StringSet.mem param !instances then ()
    else begin
      instances := StringSet.add param !instances;
      f param
    end

let declare name action =
  Hashtbl.add declared_tags name (only_once action)

let declare_multi name action =
  match Hashtbl.find declared_tags_multi name with
  | multi -> multi.actions <- multi.actions @ [action]
  | exception Not_found ->
    Hashtbl.add declared_tags_multi name
      { actions = [action]
      ; seen_instances = Tags.empty
      ; processed_tag_sets = TagsSet.empty }

let parse source tag = Lexers.tag_gen source (lexbuf_of_string tag)

let acknowledge source maybe_loc tag =
  let (name, param) = parse source tag in
  acknowledged_tags := ((name, param), maybe_loc) :: !acknowledged_tags

let make = Printf.sprintf "%s(%s)"

let really_acknowledge_multi_tags multi tags =
  if not (Tags.is_empty tags)
  && not (TagsSet.mem tags multi.processed_tag_sets) then begin
    multi.processed_tag_sets <- TagsSet.add tags multi.processed_tag_sets;
    let params =
      Tags.elements tags
      |> List.map (fun tag ->
        match snd (parse "unknown" tag) with
        | None -> assert false
        | Some param -> param)
      |> StringSet.of_list
    in
    List.iter (fun f -> f params) multi.actions
  end

let really_acknowledge ?(quiet=false) ((name, param), maybe_loc) =
  match param with
    | None ->
        if (Hashtbl.mem declared_tags name ||
            Hashtbl.mem declared_tags_multi name) && not quiet then
          Log.eprintf "%aWarning: tag %S expects a parameter"
            Loc.print_loc_option maybe_loc name
    | Some param ->
        let actions = List.rev (Hashtbl.find_all declared_tags name) in
        let has_multi =
          match Hashtbl.find declared_tags_multi name with
          | multi ->
            let tag = make name param  in
            multi.seen_instances <- Tags.add tag multi.seen_instances;
            all_tags_multi := Tags.add tag !all_tags_multi;
            (* Just for the tag checks *)
            really_acknowledge_multi_tags multi
              (Tags.singleton (make name param));
            true
          | exception Not_found ->
            false
        in
        if actions = [] && not has_multi && not quiet then
          Log.eprintf "%aWarning: tag %S does not expect a parameter, \
                       but is used with parameter %S"
            Loc.print_loc_option maybe_loc name param;
        List.iter (fun f -> f param) actions

let partial_init ?quiet source tags =
  let parse_noloc tag = (parse source tag, None) in
  Tags.iter (fun tag -> really_acknowledge ?quiet (parse_noloc tag)) tags

let init () =
  List.iter really_acknowledge (My_std.List.ordered_unique !acknowledged_tags)

let is_applied tag =
  let len = String.length tag in
  len > 0 && tag.[len - 1] = ')'

let handle_multi_param_tags tags =
  let tags = Tags.inter tags !all_tags_multi in
  if not (Tags.is_empty tags) then
    Hashtbl.iter (fun _name multi ->
      really_acknowledge_multi_tags multi
        (Tags.inter tags multi.seen_instances))
      declared_tags_multi
