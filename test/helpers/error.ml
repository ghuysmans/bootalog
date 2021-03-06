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

 The author can be reached as "creichen" at "gmail.com".

***************************************************************************)

open Bootalog
open OUnit

let no_errors closure () =
  try
    closure ()
  with Errors.ProgramError errs ->
    begin
      assert_failure ("Unexpected program errors:\n" ^
			 Errors.show_errors errs)
    end

let expect_errors (expected_errors) closure () =
  try
    closure ();
    failwith "No exceptions observed!"
  with Errors.ProgramError actual_errors ->
    if Errors.all_equal actual_errors expected_errors
    then ()
    else assert_failure ("Mismatches in exception lists:\nExpected:\n"
			 ^ (Errors.show_errors expected_errors) ^ "\n"
			 ^ "\n Actual:\n"
			 ^ (Errors.show_errors actual_errors) ^"\n")
