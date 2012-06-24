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

{
open Program.Lexeme
open Strlib

let line_nr = ref 1
let line_offset = ref 0

let ret v  =
  (!line_nr, v)

}

let ident_tail = [ '\'' 'a'-'z' 'A'-'Z' '-' '0'-'9' ] *
let ident = [ 'a'-'z' 'A'-'Z' ] ident_tail
let posnum = ['0'-'9']+

rule lex =
    parse ","						{ ret LComma }
      | "."						{ ret LPeriod }
      | "?"						{ ret LQuestionmark }
      | ":-"						{ ret LCdash }
      | "+"						{ ret LPlus }
      | "-"						{ ret LMinus }
      | "("						{ ret LOparen }
      | ")"						{ ret LCparen }
      | '_' ident_tail					{ ret LWildcard }
      | ident as i					{ ret (LName i) }
      | '\'' (ident as i)				{ ret (LAtom i) }
      | posnum as n					{ ret (LAtom n) }
      | '"' (( '\\' _ | [^ '\\' '"'])* as qs) '"'	{ ret (LAtom (Strlib.dequote qs)) }
      | [ ' ' '\t' '\r' ]+				{ lex lexbuf }
      | "\n"						{ begin	line_nr := 1 + !line_nr; line_offset := Lexing.lexeme_start lexbuf; lex lexbuf end }
      | eof						{ ret (LEOF) }
      | _						{ ret (LErrortoken ((Lexing.lexeme_start lexbuf) - (!line_offset))) }

{}
