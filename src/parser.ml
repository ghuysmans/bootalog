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

open Base
open Program
open Program.Lexeme

exception ParseError of int * int * string

let generic_parse lexbuf =
  let current_token : lexeme option ref = ref None in
  let line = ref 0 in
  let offset = ref 0 in
  let error msg =
    raise (ParseError (!line, !offset, msg))
  in
  let error_unexpected token insth =
    error (Printf.sprintf "unexpected: %s in %s" (Program.Lexeme.show token) insth)
  in
  let lex () =
    let off = Lexing.lexeme_start lexbuf in
    let (line_nr, v) = Lexer.lex lexbuf
    in match v with
	LErrortoken (_, c)	-> error (Printf.sprintf "Foreign character `%c'" c)
      | _			->
	begin
	  line := line_nr;
	  offset := off;
	  v
	end
  in

  let next () =
    match !current_token with
	Some t	-> begin current_token := None; t end
      | None	-> lex ()
  in
  let push_back (token) =
    match !current_token with
	None	-> current_token := Some token
      | _	-> error "Internal error: push_back on non-empty slot"
  in

  let peek () =
    let token = next ()
    in begin
      push_back (token);
      token
    end
  in

  let try_next (checker) =
    let next_token = next ()
    in let result = checker next_token
       in begin
	 (match result with
	     None	-> push_back next_token
	   | _		-> ());
	 result
       end
  in

  (* Auxiliaries for recursive descent parser *)
  let accept (entity) =
    let checker other = if other = entity then Some true else None in
    match try_next (checker) with
	Some _	-> true
      | None	-> false
  in

  let accept_atom () =
    let checker other =
      match other with
	  LAtom a	-> Some a
	| _		-> None
    in try_next checker
  in

  let accept_name () =
    let checker other =
      match other with
  	  LName a	-> Some a
  	| _		-> None
    in try_next checker
  in

  let expect (entity) =
    if not (accept (entity))
    then error (Printf.sprintf "Expected `%s'" (Program.Lexeme.show entity))
  in

  let expect_atom () =
    match accept_atom () with
	None	-> error (Printf.sprintf "Expected atom (at `%s')" (Program.Lexeme.show (peek())))
      | Some a	-> a
  in

  let expect_name () =
    match accept_name () with
	None	-> error (Printf.sprintf "Expected name (at `%s')" (Program.Lexeme.show (peek())))
      | Some n	-> n
  in

  let parse_list separator accept_element element_descr accept_final =
    let rec parse_expecting_separator () =
      if accept_final ()
      then []
      else if accept (separator)
      then parse_not_expecting_separator (false)
      else []
    and parse_not_expecting_separator empty_allowed =
      if empty_allowed && accept_final ()
      then []
      else match accept_element () with
	  None		-> if empty_allowed then  [] else error (Printf.sprintf "Expected %s in list of %s" element_descr element_descr)
	| Some e	-> e :: (parse_expecting_separator ())
    in parse_not_expecting_separator (true)

  in
  let always expect () =
    Some (expect ())
  in

  let perr s =
    Printf.eprintf "%s\n" s
  in

  (* Recursive descent parsers *)
  let rec parse_program () =
    begin
    match peek () with
	LEOF	-> []
      | _	-> let lhs = parse_rule ()
		   in lhs :: parse_program ()
    end

  and parse_interactive () =
    match peek () with
	LEOF	-> []
      | _	-> let lhs = parse_interaction ()
		   in lhs :: parse_interactive ()

  and parse_database () =
    match peek () with
	LEOF	-> []
      | _	-> let lhs = parse_fact ()
		   in lhs :: parse_database ()

  (* Auxiliary parsers *)
  and parse_atom () : atom =
    if accept LMinus
    then ("-" ^ expect_atom ())
    else expect_atom ()

  and parse_tuple () : tuple =
    begin
      expect LOparen;
      let result = parse_list LComma (accept_atom) "atom" (function () -> accept LCparen)
      in Array.of_list result
    end

  and parse_fact () : fact =
    let pred = expect_name ()
    in (pred, parse_tuple ())

  and parse_base_literal () : literal =
    let pred = expect_name ()
    in begin
      expect LOparen;
      let body = parse_list LComma (accept_name) "name" (function () -> accept LCparen)
      in (Predicate pred, Array.of_list body)
    end

  and parse_literal () : literal =
    parse_base_literal ()

  and parse_literals (terminator) : literal list =
    parse_list LComma (always parse_literal) "literal" (function () -> accept terminator)

  and parse_rule () : rule =
    let head = parse_base_literal ()
    in match peek () with
	LPeriod	-> begin
	  expect (LPeriod);
	  Rule.normalise (head, [])
	end
      | LCdash	-> begin
	expect LCdash;
	let body =  parse_literals (LPeriod)
	in begin
	  expect LPeriod;
	  Rule.normalise (head, body)
	end
      end
      | other -> error_unexpected other "rule"

  and parse_interaction () =
    let dparse char action =
      begin
	expect char;
	let result = action (parse_fact ());
	in begin
	  expect LPeriod;
	  result
	end
      end
    in
    match peek () with
      LPlus		-> dparse LPlus (function a -> DAddFact a)
    | LMinus	-> dparse LMinus (function a -> DDelFact a)
    | _		-> DRule (parse_rule ())

  in (parse_program, parse_interactive, parse_database)


let parse_program lexbuf =
  let (prog, _, _) = generic_parse lexbuf
  in prog ()

let parse_interactive lexbuf =
  let (_, inter, _) = generic_parse lexbuf
  in inter ()

let parse_database lexbuf =
  let (_, _, db) = generic_parse lexbuf
  in db ()
