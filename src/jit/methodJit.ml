open Asm
open Core
open Inlining
open JitConfig
open Renaming

module Util = struct
  let find_pc argsr n = int_of_id_t (List.nth_exn argsr n)

  let value_of_id_t reg id_t = reg.(int_of_id_t id_t)

  let value_of_id_or_imm reg = function
    | V (id) -> reg.(int_of_id_t id)
    | C (n) -> Green (n)
end

let rec method_jit p instr reg mem jit_args =
  match instr with
  | Ans (exp) ->
    method_jit_ans p exp reg mem jit_args
  | Let ((dest, typ), exp, body) ->
    begin
      match TracingJit.tracing_jit_let p exp reg mem with
      | Specialized (v) ->
        method_jit p body reg mem jit_args
      | Not_specialised (e, v) ->
        reg.(int_of_id_t dest) <- v;
        Let ((dest, typ), exp, method_jit p body reg mem jit_args)
    end

and method_jit_ans p e reg mem jit_args =
  match e with
  | CallDir (id_l, argsr, _) ->
    let fundef = find_fundef p id_l in
    method_jit p (inline_calldir_exp argsr fundef reg) reg mem jit_args
  | IfEq (id_t, id_or_imm, t1, t2) ->
    let r2 = Util.value_of_id_or_imm reg id_or_imm in
    Ans (
      match r2 with
      | Green (n2) ->
        let reg', mem' = reg, mem in
        let t1' = method_jit p t1 reg' mem' jit_args in
        let t2' = method_jit p t2 reg' mem' jit_args in
        IfEq (id_t, C (n2), t1', t2')
      | Red (n2) ->
        let reg', mem' = reg, mem in
        let t1' = method_jit p t1 reg' mem' jit_args in
        let t2' = method_jit p t2 reg' mem' jit_args in
        IfEq (id_t, id_or_imm, t1', t2')
    )
  | IfLE (id_t, id_or_imm, t1, t2) ->
    let r2 = Util.value_of_id_or_imm reg id_or_imm in
    Ans (
      match r2 with
      | Green (n2) ->
        let reg', mem' = reg, mem in
        let t1' = method_jit p t1 reg' mem' jit_args in
        let t2' = method_jit p t2 reg' mem' jit_args in
        IfLE (id_t, C (n2), t1', t2')
      | Red (n2) ->
        let reg', mem' = reg, mem in
        let t1' = method_jit p t1 reg' mem' jit_args in
        let t2' = method_jit p t2 reg' mem' jit_args in
        IfLE (id_t, id_or_imm, t1', t2')
    )
  | IfGE (id_t, id_or_imm, t1, t2) ->
    let r2 = Util.value_of_id_or_imm reg id_or_imm in
    Ans (
      match r2 with
      | Green (n2) ->
        let reg', mem' = reg, mem in
        let t1' = method_jit p t1 reg' mem' jit_args in
        let t2' = method_jit p t2 reg' mem' jit_args in
        IfGE (id_t, C (n2), t1', t2')
      | Red (n2) ->
        let reg', mem' = reg, mem in
        let t1' = method_jit p t1 reg' mem' jit_args in
        let t2' = method_jit p t2 reg' mem' jit_args in
        IfGE (id_t, id_or_imm, t1', t2')
      )
  | _ -> Ans (e)
