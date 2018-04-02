open Asm
open Core
open Interp_config
open Tracing_jit
open Jit_config
open Jit_util

let zero = Jit_config.zero

let rec find_label_number label = function
  | [] -> let Id.L s = label in int_of_id_t s
  | (l, num) :: tl -> if l = label then num else find_label_number label tl

let rec find_label prog num =
  let ProgWithLabel (_, _, _, labels) = prog in
  match List.find ~f:(fun (id_l, n) -> n = num) labels with
  | Some (id, _) -> id
  | None ->
    Logger.error (Printf.sprintf "num: %d" num);
    raise Not_found

let rec lookup_by_id_l prog name =
  let ProgWithLabel (_, fundefs, _, _) = prog in
  match List.find ~f:(fun fundef -> (fundef.name = name)) fundefs with
  | Some (fundef) -> fundef
  | None ->
    Logger.error (let Id.L s = name in Printf.sprintf "CallCls %s is not found" s);
    raise Not_found

let rec lookup_by_id_t prog name =
  let ProgWithLabel (_, fundefs, _, _) = prog in
  match List.find ~f:(fun fundef -> (let Id.L s = fundef.name in s) = name) fundefs with
  | Some (fundef) -> fundef
  | None ->
    Logger.error (Printf.sprintf "CallCls %s" name);
    raise Not_found

let make_reg reg args_tmp args_real = (* 仮引数のレジスタに実引数がしまわれている reg を作る *)
  let regs_tmp = List.map ~f:int_of_id_t args_tmp in
  let regs_real = List.map ~f:int_of_id_t args_real in
  let arr = Array.create register_size 0 in
  List.iter
    ~f:(fun (x, y) -> arr.(x) <- reg.(y))
    (List.zip_exn regs_tmp regs_real);
  arr

let is_first_dispatch = ref true

let rec interp prog instr reg mem jit_args = match instr with
  | Ans exp ->
    let res = eval_exp prog exp reg mem jit_args in
    (* Logger.debug (Printf.sprintf "Ans (%d)" res); *)
    res
  | Let (("min_caml_hp", _), exp, t) ->
    let res = eval_exp prog exp reg mem jit_args in
    Logger.debug(Printf.sprintf "Let (id: %s, reg_num: %d, res: %d)" "min_caml_hp" !heap res);
    heap := res;
    interp prog t reg mem jit_args
  | Let ((id, _), exp, t) ->
    let reg_num = int_of_id_t id in
    let res = eval_exp prog exp reg mem jit_args in
    Logger.debug(Printf.sprintf "Let (id: %s, reg_num: %d, res: %d)" id reg_num res);
    reg.(reg_num) <- res;
    begin
      match !enable_jit, !is_first_dispatch with
      | true, true ->
        is_first_dispatch := false;
        interp prog (Ans (CallDir (Id.L jit_args.trace_name, jit_args.reds, []))) reg mem jit_args
      | _ -> interp prog t reg mem jit_args
    end

and eval_exp prog exp' reg mem jit_args = match exp' with
  | Nop ->
    Logger.debug ("Nop");
    0
  | Set n ->
    Logger.debug (Printf.sprintf "Set (%d)" n);
    n
  | Neg n ->
    let res = reg.(int_of_id_t n) in
    Logger.debug (Printf.sprintf "Neg %d" res);
    (- res)
  | SetL id_l ->
    let ProgWithLabel (_, _, _, labels) = prog in
    let res = find_label_number id_l labels in
    Logger.debug (Printf.sprintf "SetL (%s: %d)" (let Id.L s = id_l in s) res);
    res
  | Mov "min_caml_hp" ->
    Logger.debug (Printf.sprintf "Mov (min_caml_hp: %d)" !heap);
    !heap
  | Mov id_t ->
    let regnum = int_of_id_t id_t in
    let res = reg.(regnum) in
    Logger.debug (Printf.sprintf "Mov (id_t: %s, regnum: %d, res: %d)" id_t regnum res);
    res
  | Add (id_t1, V (id_t2)) ->
    (match id_t1 with
     | "min_caml_hp" ->
       let r1 = !heap in
       let r2 = int_of_id_t id_t2 in
       let res = r1 + reg.(r2) in
       Logger.debug (Printf.sprintf "Add (r1: %d, r2: %d, res: %d)" r1 r2 res);
       res
     | _ ->
       let r1 = int_of_id_t id_t1 in
       let r2 = int_of_id_t id_t2 in
       let res = reg.(r1) + reg.(r2) in
       Logger.debug (Printf.sprintf "Add (r1: %d, r2: %d, res: %d)" r1 r2 res);
       res)
  | Add (id_t, C n) ->
    (match id_t with
     | "min_caml_hp" ->
       let r1 = !heap in
       let res = r1 + n in
       Logger.debug (Printf.sprintf "AddImm (r1: %d, r2: %d, res: %d)" r1 n res);
       res
     | _ ->
       let r1 = int_of_id_t id_t in
       let res = reg.(r1) + n in
       Logger.debug (Printf.sprintf "AddImm (r1: %d, r2: %d, res: %d)" r1 n res);
       res)
  | Sub (id_t1, V (id_t2)) ->
    (match id_t1 with
       "min_caml_hp" ->
       let r1 = !heap in
       let r2 = reg.(int_of_id_t id_t2) in
       let res = r1 - r2 in
       Logger.debug (Printf.sprintf "Sub (r1: %d, r2: %d, res: %d)" r1 r2 res);
       res
     | _ ->
       let r1 = int_of_id_t id_t1 in
       let r2 = int_of_id_t id_t2 in
       let res = reg.(r1) - reg.(r2) in
       Logger.debug (Printf.sprintf "Sub (r1: %d, r2: %d, res: %d)" r1 r2 res);
       res)
  | Sub (id_t, C (n)) ->
    (match id_t with
       "min_caml_hp" ->
       let r1 = !heap in
       let res = r1 - n in
       Logger.debug (Printf.sprintf "SubImm (r1: %d, r2: %d, res: %d)" r1 n res);
       res
     | _ ->
       let r1 = int_of_id_t id_t in
       let res = reg.(r1) - n in
       Logger.debug (Printf.sprintf "SubImm (r1: %d, r2: %d, res: %d)" r1 n res);
       res)
  | Ld (zero, C (n), x) ->
    mem.(n)
  | Ld (id_t, id_or_imm, x) ->
    (* id_t + id_or_imm * x の番地から load *)
    let dest = match id_t with
      | "min_caml_hp" -> !heap
      | _ -> reg.(int_of_id_t id_t)
    in
    let offset = (match id_or_imm with
        | V id_t -> reg.(int_of_id_t id_t)
        | C n -> n) * x
    in
    let res = mem.(dest + offset) in
    Logger.debug (Printf.sprintf "Ld (id_t: %s, dest: %d, offset: %d, m: %d, res: %d)" id_t dest offset (dest + offset) res);
    res
  | St (id_t1, zero, C (n), x) ->
    mem.(n) <- reg.(int_of_id_t id_t1);
    0
  | St (id_t1, id_t2, id_or_imm, x) ->
    (* id_t2 + id_or_imm * x の番地に id_t1 を store *)
    let src = match id_t1 with
        "min_caml_hp" -> !heap
      | _ -> reg.(int_of_id_t id_t1)
    in
    let dest = match id_t2 with
        "min_caml_hp" -> !heap
      | _ -> reg.(int_of_id_t id_t2)
    in
    let offset = (match id_or_imm with
        | V "min_caml_hp" -> !heap
        | V id_t -> reg.(int_of_id_t id_t)
        | C n -> n) * x
    in
    let m = dest + offset in
    Logger.debug (Printf.sprintf "St (id_t1: %s, id_t2: %s, dest: %d, offset: %d, m: %d), res: %d" id_t1 id_t2 dest offset m src);
    mem.(m) <- src;
    0
  | Comment _ -> 0
  | IfEq (id1, id_or_imm, t1, t2) ->
    let r1 = match id1 with "min_caml_hp" -> !heap | _ -> reg.(int_of_id_t id1) in
    let r2 = match id_or_imm with
        V (id_t) -> reg.(int_of_id_t id_t)
      | C (i) -> i
    in
    Logger.debug (Printf.sprintf "IfEq (id1: %s, id2: %s, t1: %d, t2: %d)" id1 (string_of_id_or_imm id_or_imm) r1 r2);
    if r1 = r2 then
      interp prog t1 reg mem jit_args
    else
      interp prog t2 reg mem jit_args
  | IfLE (id, id_or_imm, t1, t2) ->
    let r1 = match id with "min_caml_hp" -> !heap | _ -> reg.(int_of_id_t id) in
    let r2 = match id_or_imm with
        V (id_t) -> reg.(int_of_id_t id_t)
      | C (i) -> i
    in
    Logger.debug (Printf.sprintf "IfLE (id: %s, id_or_imm: %s, t1: %d, t2: %d)" id (string_of_id_or_imm id_or_imm) r1 r2);
    if r1 <= r2 then
      interp prog t1 reg  mem jit_args
    else
      interp prog t2 reg  mem jit_args
  | IfGE (id, id_or_imm, t1, t2) ->
    let r1 = match id with "min_caml_hp" -> !heap | _ -> reg.(int_of_id_t id) in
    let r2 = match id_or_imm with
        V (id_t) -> reg.(int_of_id_t id_t)
      | C (i) -> i
    in
    Logger.debug (Printf.sprintf "IfGE (id1: %s, id2: %s, t1: %d, t2: %d)" id (string_of_id_or_imm id_or_imm) r1 r2);
    if r1 >= r2 then
      interp prog t1 reg  mem jit_args
    else
      interp prog t2 reg  mem jit_args
  | CallCls (id_t, args, _) ->
    let r1 = reg.(int_of_id_t id_t) in
    let m1 = mem.(r1) in
    let Id.L id = find_label prog m1 in
    Logger.debug (Printf.sprintf "CallCls (id_t: %s, r1: %d, r2: %d, id_l: %s)" id_t r1 m1 id);
    let fundef = lookup_by_id_l prog (Id.L (id)) in
    let reg' = make_reg reg (fundef.args) args in
    reg'.(int_of_id_t id) <- r1;
    interp prog (fundef.body) reg' mem jit_args
  | CallDir (Id.L ("min_caml_print_int"), [arg], _) ->
    let v = reg.(int_of_id_t arg) in
    Logger.debug (Printf.sprintf "CallDir min_caml_print_int %d" v);
    print_int v;
    0
  | CallDir (Id.L ("min_caml_print_newline"), _, _) ->
    print_newline ();
    0
  | CallDir (Id.L ("min_caml_truncate"), _, [farg]) ->
    raise (Un_implemented_instruction "min_caml_truncate is not implemented.")
  | CallDir (Id.L ("min_caml_create_array"), arg1 :: arg2 :: [], _) ->
    let size = reg.(int_of_id_t arg1) in
    let init = reg.(int_of_id_t arg2) in
    let a = !heap in
    heap := !heap + (size * 4);
    for i = 0 to size do
      mem.(a + i * 4) <- init
    done;
    Logger.debug (Printf.sprintf "CallDir (min_caml_create_array, arg1: %d, arg2: %d)" size init);
    a
  | CallDir (name, args, _) ->
    (* fundef.args: 仮引数 args: 実引数 *)
    let fundef = lookup_by_id_l prog name in
    let reg' = make_reg reg (fundef.args) args in
    let Id.L s = name in Logger.debug (Printf.sprintf "CallDir %s" s);
    interp prog (fundef.body) reg' mem jit_args
  | _ -> raise (Un_implemented_instruction "Not implemented.")


let f prog =
  let reg = Array.create register_size 0 in
  let mem = Array.create register_size 0 in
  let prog' = to_prog_with_label prog in
  let ProgWithLabel (_, _, instructions, labels) = prog' in
  let jit_args =
    { trace_name = ""
    ; reds = []
    ; greens = []
    ; loop_header = 0
    ; loop_pc_place = 0; }
  in
  interp prog' instructions reg mem jit_args