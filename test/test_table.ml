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
open OUnit
open Printf

module CTable = Combined_table
module STable = Simple_table

let check_eq msg expected actual =
  assert_equal expected actual ?msg:(Some msg)

let test_simple_basic () =
  let table = STable.create ()
  in begin
    check_eq "empty-0" false  (STable.contains table ["foo", "bar"]);
    STable.insert table ["foo", "bar"];
    STable.insert table ["foo", "baz"];
    check_eq "nonempty-0" true  (STable.contains table ["foo", "bar"]);
    check_eq "nonempty-1" true  (STable.contains table ["foo", "baz"]);
    check_eq "empty-1" false  (STable.contains table ["foo", "quux"]);
  end

let test_simple_bind () =
  let table = STable.create () in
  let results : tuple list ref = ref [] in
  let clear_results () = results := [] in
  let cont (vars) (env) = results := (Array.map (Env.find env) vars) :: (!results) in
  let check_result message expected actual =
    let expected = Tuple.sort expected in
    let actual = Tuple.sort actual in
    let show_tuples atoms = "[" ^ (String.concat "; " (List.map Tuple.show atoms)) ^ "]"
    in (check_eq
	  ("Mismatch in " ^ message ^ "\nexpected:\t" ^ (show_tuples expected) ^ "\nactual:  \t" ^ (show_tuples actual))
	  expected actual)
  in let env = Env.fresh ()
  in let check_query (message) (bindings) (query) (result_vars) (expected_result) =
       let do_bind (name, value) = Env.bind env name value
       in begin
	 clear_results ();
	 Env.clear env;
	 List.iter do_bind bindings;
	 STable.bind_all table query env (cont result_vars);
	 check_result message expected_result  (!results);
       end
  in begin
    STable.insert' table ["foo"; "1"; "bar"];
    STable.insert' table ["foo"; "1"; "baz"];
    STable.insert' table ["glorb"; "2"; "2"];
    STable.insert' table ["quux"; "1"; "baz"];
    STable.insert' table ["quux"; "1"; "1"];

    check_query "simple"   [("X", "foo")]        [|"X"; "Y"; "Z"|]  [|"Z"|]  [[|"bar"|]; [|"baz"|]];
    check_query "empty"    [("X", "not-found")]  [|"X"; "Y"; "Z"|]  [|"Z"|]  [];
    check_query "eq-bind"  []                    [|"X"; "Y"; "Y"|]  [|"X"|]  [[|"glorb"|]; [|"quux"|]];
    List.iter (function var -> check_eq ("env-clear-" ^ var) None (Env.lookup env var)) ["Y"; "Z"];
    check_query "check-1"    [("X", "foo"); ("Y", "1"); ("Z", "bar")]        [|"X"; "Y"; "Z"|]  [|"Z"|]  [[|"bar"|]];
    check_query "check-0"    [("X", "foo"); ("Y", "1"); ("Z", "unfound")]    [|"X"; "Y"; "Z"|]  [|"Z"|]  [];
  end


let test_combined_table_delta_and_flag () =
  let base_table = STable.create () in
  let delta_table = STable.create () in
  let flag = ref false in
  let join_table = CTable.create_delta (flag, delta_table, base_table) in
  begin
    STable.insert' base_table ["foo"];
    check_eq "flag-initially-false" false (!flag);
    CTable.insert' join_table ["foo"];
    check_eq "flag-not-updated" false (!flag);
    check_eq "redundant-update-not-in-delta" false (STable.contains delta_table [|"foo"|]);
    CTable.insert' join_table ["bar"];
    check_eq "flag-updated" true (!flag);
    check_eq ("real-update-in-delta(" ^ (STable.show delta_table) ^ ")") true (STable.contains delta_table [|"bar"|]);
    check_eq "real-update-in-base" true (STable.contains base_table [|"bar"|]);
  end


let test_combined_table_replace_delta () =
  let base_table = STable.create () in
  let delta_foo_table = STable.create () in
  let delta_bar_table = STable.create () in
  let delta_quux_table = STable.create () in
  let flag = ref false in
  let join_table = CTable.create_delta (flag, delta_foo_table, base_table) in
  let all_values = ["foo"; "bar"; "quux"] in
  let check_containment tablename table selection =
    let contains s = List.exists (function n -> n = s) selection in
    let try_value v =
      let cs = if contains v
	then "assert-contains"
	else "assert-does-not-contain"
      in check_eq (tablename ^ "(" ^ (STable.show table) ^ ") " ^ cs ^ " " ^ v) (contains v) (STable.contains table [|v|])
    in List.iter try_value all_values
  in
  begin
    CTable.insert' join_table ["foo"];
    CTable.update_delta join_table delta_bar_table;
    CTable.insert' join_table ["bar"];
    CTable.update_delta join_table delta_quux_table;
    CTable.insert' join_table ["quux"];
    check_containment "base" base_table all_values;
    check_containment "delta-foo-table" delta_foo_table ["foo"];
    check_containment "delta-bar-table" delta_bar_table ["bar"];
    check_containment "delta-quux-table" delta_quux_table ["quux"];
  end
  

let all_tests = "table" >:::
  [
    "simple-basic" >:: test_simple_basic;
    "simple-bind" >:: test_simple_bind;
    "combined-update" >:: test_combined_table_delta_and_flag;
    "combined-new-delta" >:: test_combined_table_replace_delta;
  ]

let _ = run_test_tt_main (all_tests)
