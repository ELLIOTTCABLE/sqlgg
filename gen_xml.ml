(* OCaml code generation *)

open ExtList
open ExtString
open Operators
open Printf

open Stmt
open Gen
open Sql

type xml = | Node of (string * (string * string) list * xml list)
           | Comment of string

let xml_escape s =
  let b = Buffer.create 10 in
  let add s = Buffer.add_string b s in
  String.iter (function
  | '&' -> add "&amp;"
  | '"' -> add "&quot;"
  | '\n' -> add "&#x0A;"
  | '\r' -> ()
  | '<' -> add "&lt;"
  | '>' -> add "&gt;"
  | c -> Buffer.add_char b c) s;
  Buffer.contents b

let xml_to_string xml =
  let b = Buffer.create 1000 in
(*   let indent = ref 0 in *)
  let rec fold = function
    | Node (name,attrs,children) ->
        bprintf b "\n<%s" name;
        List.iter (fun (n,v) -> bprintf b " %s=\"%s\"" n (xml_escape v)) attrs;
        begin match children with
        | [] -> bprintf b "/>"
        | _ -> bprintf b ">"; List.iter fold children; bprintf b "</%s>" name
        end
    | Comment text -> bprintf b "\n<!-- %s -->" (Gen_caml.replace_all ~str:text ~sub:"--" ~by:"&mdash;")
  in
  fold xml;
  Buffer.contents b

(*
let _ =
  Node ("test",["name","d\"s&quot;ds"],[]) >> xml_to_string >> print_endline
*)

let comment (x,_) fmt = Printf.ksprintf (fun s -> x := Comment s :: !x) fmt

let value n t = Node ("value",["name",n; "type",t;],[])

let param_type_to_string t = Option.map_default Type.to_string "Any" t
let params_to_values = List.mapi (fun i (n,t) -> value (param_name_to_string n i) (param_type_to_string t))
let params_to_values = List.unique & params_to_values

let scheme_to_values = List.map (fun attr -> value attr.RA.name (Type.to_string attr.RA.domain))

type t = xml list ref * xml list ref

let start () = ref [], ref []

let generate_code (x,_) index scheme params kind props =
  let name = choose_name props kind index in
  let input = Node ("in",[],params_to_values params) in
  let output = Node ("out",[],scheme_to_values scheme) in
  let sql = get_sql props kind params in
  x := Node ("stmt",["name",name; "sql",sql;],[input; output]) :: !x

let start_output (x,pre) = pre := !x; x := []

let finish_output (x,pre) =
  List.iter (fun z -> z >> xml_to_string >> print_endline) !pre;
  Node ("sqlgg",[],List.rev !x) >> xml_to_string >> print_endline;
  x := [];
  pre := []

