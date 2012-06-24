(***************************************************************************
 This file is Copyright (C) 2012 Christoph Reichenbach

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the
   Free Software Foundation, Inc.
   59 Temple Place, Suite 330
   Boston, MA  02111-1307
   USA

 The author can be reached as "reichenb" at "colorado.edu".

***************************************************************************)

exception Malformed
exception NotADeltaTable
exception UnexpectedDeltaTable

type atom = string

let eprint x = Printf.printf "%s" x

module Atom =
  struct
    type t = atom
    let show (s : string) = s
    let dummy = ""
  end

type tuple = atom array

module Tuple =
  struct
    type t = tuple
    let show elts = "(" ^ (String.concat ", " (List.map Atom.show (Array.to_list elts))) ^ ")"
    let sort = List.sort (Compare.array_collate (String.compare))

    let string_sizes (tuple) =
      List.map (function t -> (String.length (Atom.show t))) (Array.to_list tuple)

    let show_padded sizes tuple =
      let rec s a b =
	match (a, b) with
	    (size::sl, atom::al)	-> (Printf.sprintf "%-*s" size (Atom.show atom)) :: (s sl al)
	  | (_, [])			-> []
	  | ([], atom::al)		-> (Atom.show atom) :: (s [] al)
      in String.concat "" (s sizes (Array.to_list tuple))

    let merge_string_sizes sizes0 sizes1 =
      let rec m a b =
	match (a, b) with
	    ([], tl)	-> tl
	  | (tl, [])	-> tl
	  | (h1::tl1,
	     h2::tl2)	-> (if h1 > h2 then h1 else h2)::(m tl1 tl2)
      in m sizes0 sizes1
  end

type base_predicate = string

type predicate =
    Predicate of base_predicate
  | DeltaPredicate of base_predicate

module Predicate =
  struct
    type t = predicate

    let atom = Predicate "atom"

    let is_delta s =
      match s with
	  DeltaPredicate _	-> true
	| _			-> false

    let show (p) =
      match p with
	  Predicate p		-> p
	| DeltaPredicate d	-> "D[" ^ d ^ "]"

    let delta s =
      match s with
	  Predicate p		-> DeltaPredicate p
	| DeltaPredicate d	-> raise (Failure ("Attempted deltafication of delta`"^d^"'"))

    let compare l r =
      match (l, r) with
	  (Predicate _, DeltaPredicate _)		-> -1
	| (DeltaPredicate _, Predicate _)		-> 1
	| ((Predicate a,Predicate b)
	      | (DeltaPredicate a, DeltaPredicate b))	-> String.compare a b

  end

type fact = base_predicate * (atom array)

module Fact =
  struct
    type t = fact

    let show (bp, tuple) = bp ^ (Tuple.show (tuple))
  end


type variable = Variable.t

type literal = predicate * (variable array)

module Literal =
  struct
    type t = literal

    let delta (p, body) =
      (Predicate.delta p, body)

    let show (symbol, varlist) =
      Predicate.show(symbol) ^ "(" ^ (String.concat ", " (List.map Variable.show (Array.to_list varlist))) ^ ")"
    let compare = Compare.join (Predicate.compare) (Compare.array_collate Variable.compare)
  end

module VarSet = Set.Make(Variable)
let var_set_add' a b = VarSet.add b a

module PredicateSet' = Set.Make(Predicate)
module PredicateSet =
  struct
    open PredicateSet'
    type t = PredicateSet'.t
    let empty = empty
    let add = add
    let add' a b = add b a
    let from_list = List.fold_left add' empty
    let to_list s = fold (function a -> function b -> a :: b) s []
    let iter = iter
    let fold = fold
    let union = union
    let inter = inter
    let cardinal = cardinal
    let is_empty = is_empty
    let singleton = singleton
    let contains = mem
    let equal = equal
    let for_all = for_all
    let diff = diff
    let show set =
      let show_one elt tail = (Predicate.show elt)::tail
      in let elts = fold show_one set [] in
	 "{" ^ (String.concat ", " elts) ^ "}"
  end

let varset_literal (_, vars) = Array.fold_left var_set_add' VarSet.empty vars
let varset_rule_head (head, _) = varset_literal (head)
let varset_rule_body (_, body) = List.fold_left (fun map -> fun (_, vars) -> Array.fold_left var_set_add' map vars) VarSet.empty body

let predicate_set_body (_, body) =  List.fold_left (fun map -> fun (p, _) -> PredicateSet.add p map) PredicateSet.empty body

type rule = literal * literal list

module Rule =
  struct
    type t = rule
    let show (head, tail) = Literal.show (head) ^ " :- " ^ (String.concat ", " (List.map Literal.show tail)) ^ "."
    let compare = Compare.join (Literal.compare) (Compare.collate (Literal.compare))
    let equal a b = 0 = compare a b

    let normalise ((head, tail) as rule : rule) =
      let head_vars = varset_rule_head (rule) in
      let body_vars = varset_rule_body (rule) in
      let free_vars = VarSet.diff head_vars body_vars in
      let add_atom_predicate var tail = (Predicate.atom, [| var |]) :: tail in
      let atom_tail = VarSet.fold add_atom_predicate free_vars [] in
      (head, tail @ atom_tail)
  end

type ruleset = rule list

module RuleSet =
  struct
    type t = ruleset
    let show ruleset = String.concat "\n" (List.map Rule.show ruleset)
  end

type stratum =
    { pss	: PredicateSet.t;
      base	: rule list;
      delta	: rule list }

module Stratum =
  struct
    type t = stratum

    let show_n label stratum =
      let show_rules rules =
	String.concat "" (List.map (function rule -> "  " ^ Rule.show rule ^ "\n") rules)
      in ("== " ^ label ^ "<" ^ (PredicateSet.show stratum.pss) ^ ">}\n"
	  ^ "- base:\n"
	  ^ (show_rules stratum.base)
	  ^ "- delta:\n"
	  ^ (show_rules stratum.delta))

    let show = show_n ""

    let normalise stratum =
      { pss	= stratum.pss;
	base	= List.sort Rule.compare stratum.base;
	delta	= List.sort Rule.compare stratum.delta; }

    let equal stratum0 stratum1 =
      let s0 = normalise stratum0 in
      let s1 = normalise stratum1
      in (PredicateSet.equal s0.pss s1.pss
	  && s0.base = s1.base
	    && s0.delta = s1.delta)
  end

module StratifiedRuleset =
  struct
    type t = stratum list

    let show strata =
      let rec show_i i args =
	match args with
	    []		-> ""
	  | h::tl	-> (Stratum.show_n (Printf.sprintf "%i" i) h) ^ "\n" ^ (show_i (i+1) tl)
      in show_i 0 strata

    let normalise =
      List.map Stratum.normalise

    let equal =
      let rec is_eq r0 r1 =
	match (r0, r1) with
	    ([], [])	-> true
	  | (h0::tl0,
	     h1::tl1)	-> if Stratum.equal h0 h1 then is_eq tl0 tl1 else false
	  | _		-> false
      in is_eq
  end

