open Asm

exception Not_supported of string
exception Un_implemented_instruction of string

type labels = (* function label for closures *)
  (Id.l * int) list

type prog_with_label =
  (* prog for interpreter *)
  | ProgWithLabel of (Id.l * float) list * fundef list * t * labels

let register_size = 1000000
let heap = ref 0

module Util = struct
  let prog_with_label prog =
    let rec create_labels fundefs i =
      match fundefs with
      | [] -> []
      | fundef :: tl -> (fundef.name, i) :: create_labels tl (i + 1)
    in
    let (Prog (table, _, fundefs, exp)) = prog in
    let labels = create_labels fundefs 0 in
    ProgWithLabel (table, fundefs, exp, labels)
  ;;

  let zero = "zero.0"

  let int_of_id_t = function
    | "min_caml_hp" -> failwith "int_of_id_t min_caml_hp is not supported."
    | id ->
      id |> String.split_on_char '.' |> List.rev |> List.hd |> int_of_string
  ;;

  let string_of_id_or_imm = function C n -> string_of_int n | V id -> id

  let rec find_label_number label = function
    | [] ->
      let (Id.L s) = label in
      int_of_id_t s
    | (l, num) :: tl -> if l = label then num else find_label_number label tl
  ;;

  let rec find_label prog num =
    let (ProgWithLabel (_, _, _, labels)) = prog in
    match labels |> List.find_opt (fun (id_l, n) -> n = num) with
    | Some (id, _) -> id
    | None ->
      Log.error (Printf.sprintf "num: %d" num);
      failwith (Printf.sprintf "Not found num: %d" num)
  ;;

  let rec lookup_by_id_l prog name =
    let (ProgWithLabel (_, fundefs, _, _)) = prog in
    match fundefs |> List.find_opt (fun fundef -> fundef.name = name) with
    | Some fundef -> fundef
    | None ->
      Log.error
        (let (Id.L s) = name in
         Printf.sprintf "CallCls %s is not found" s);
      assert false
  ;;

  let rec lookup_by_id_t prog name =
    let (ProgWithLabel (_, fundefs, _, _)) = prog in
    match
      fundefs
      |> List.find_opt (fun fundef ->
             (let (Id.L s) = fundef.name in
              s)
             = name)
    with
    | Some fundef -> fundef
    | None ->
      Log.error (Printf.sprintf "CallCls %s" name);
      assert false
  ;;

  let make_reg reg args_tmp args_real =
    (* 仮引数のレジスタに実引数がしまわれている reg を作る *)
    let regs_tmp = List.map int_of_id_t args_tmp in
    let regs_real = List.map int_of_id_t args_real in
    let arr = Array.make register_size 0 in
    let rec zip x y =
      match x, y with
      | [], [] -> []
      | h1 :: t1, h2 :: t2 -> (h1, h2) :: zip t1 t2
      | _ -> assert false
    in
    List.iter (fun (x, y) -> arr.(x) <- reg.(y)) (zip regs_tmp regs_real);
    arr
  ;;
end

open Util

let rec interp prog instr reg mem =
  match instr with
  | Ans exp ->
    let res = eval_exp prog exp reg mem in
    (* Log.debug (Printf.sprintf "Ans (%d)" res); *)
    res
  | Let (("min_caml_hp", _), exp, t) ->
    let res = eval_exp prog exp reg mem in
    Log.debug
      (Printf.sprintf
         "Let (id: %s, reg_num: %d, res: %d)"
         "min_caml_hp"
         !heap
         res);
    heap := res;
    interp prog t reg mem
  | Let ((id, _), exp, t) ->
    let reg_num = int_of_id_t id in
    let res = eval_exp prog exp reg mem in
    Log.debug
      (Printf.sprintf "Let (id: %s, reg_num: %d, res: %d)" id reg_num res);
    reg.(reg_num) <- res;
    interp prog t reg mem

and eval_exp prog exp' reg mem =
  match exp' with
  | Nop ->
    Log.debug (Printf.sprintf "Nop");
    0
  | Set n ->
    Log.debug (Printf.sprintf "Set (%d)" n);
    n
  | Neg n ->
    let res = reg.(int_of_id_t n) in
    Log.debug (Printf.sprintf "Neg %d" res);
    -res
  | SetL id_l ->
    let (ProgWithLabel (_, _, _, labels)) = prog in
    let res = find_label_number id_l labels in
    Log.debug
      (Printf.sprintf
         "SetL (%s: %d)"
         (let (Id.L s) = id_l in
          s)
         res);
    res
  | Mov "min_caml_hp" ->
    Log.debug (Printf.sprintf "Mov (min_caml_hp: %d)" !heap);
    !heap
  | Mov id_t ->
    let regnum = int_of_id_t id_t in
    let res = reg.(regnum) in
    Log.debug
      (Printf.sprintf "Mov (id_t: %s, regnum: %d, res: %d)" id_t regnum res);
    res
  | Add (id_t1, V id_t2) ->
    (match id_t1 with
    | "min_caml_hp" ->
      let r1 = !heap in
      let r2 = int_of_id_t id_t2 in
      let res = r1 + reg.(r2) in
      Log.debug (Printf.sprintf "Add (r1: %d, r2: %d, res: %d)" r1 r2 res);
      res
    | _ ->
      let r1 = int_of_id_t id_t1 in
      let r2 = int_of_id_t id_t2 in
      let res = reg.(r1) + reg.(r2) in
      Log.debug (Printf.sprintf "Add (r1: %d, r2: %d, res: %d)" r1 r2 res);
      res)
  | Add (id_t, C n) ->
    (match id_t with
    | "min_caml_hp" ->
      let r1 = !heap in
      let res = r1 + n in
      Log.debug (Printf.sprintf "AddImm (r1: %d, r2: %d, res: %d)" r1 n res);
      res
    | _ ->
      let r1 = int_of_id_t id_t in
      let res = reg.(r1) + n in
      Log.debug (Printf.sprintf "AddImm (r1: %d, r2: %d, res: %d)" r1 n res);
      res)
  | Sub (id_t1, V id_t2) ->
    (match id_t1 with
    | "min_caml_hp" ->
      let r1 = !heap in
      let r2 = reg.(int_of_id_t id_t2) in
      let res = r1 - r2 in
      Log.debug (Printf.sprintf "Sub (r1: %d, r2: %d, res: %d)" r1 r2 res);
      res
    | _ ->
      let r1 = int_of_id_t id_t1 in
      let r2 = int_of_id_t id_t2 in
      let res = reg.(r1) - reg.(r2) in
      Log.debug (Printf.sprintf "Sub (r1: %d, r2: %d, res: %d)" r1 r2 res);
      res)
  | Sub (id_t, C n) ->
    (match id_t with
    | "min_caml_hp" ->
      let r1 = !heap in
      let res = r1 - n in
      Log.debug (Printf.sprintf "SubImm (r1: %d, r2: %d, res: %d)" r1 n res);
      res
    | _ ->
      let r1 = int_of_id_t id_t in
      let res = reg.(r1) - n in
      Log.debug (Printf.sprintf "SubImm (r1: %d, r2: %d, res: %d)" r1 n res);
      res)
  | Ld (zero, C n, x) -> mem.(n)
  | Ld (id_t, id_or_imm, x) ->
    (* id_t + id_or_imm * x の番地から load *)
    let dest =
      match id_t with "min_caml_hp" -> !heap | _ -> reg.(int_of_id_t id_t)
    in
    let offset =
      (match id_or_imm with V id_t -> reg.(int_of_id_t id_t) | C n -> n) * x
    in
    let res = mem.(dest + offset) in
    Log.debug
      (Printf.sprintf
         "Ld (id_t: %s, dest: %d, offset: %d, m: %d, res: %d)"
         id_t
         dest
         offset
         (dest + offset)
         res);
    res
  | St (id_t1, zero, C n, x) ->
    mem.(n) <- reg.(int_of_id_t id_t1);
    0
  | St (id_t1, id_t2, id_or_imm, x) ->
    (* id_t2 + id_or_imm * x の番地に id_t1 を store *)
    let src =
      match id_t1 with "min_caml_hp" -> !heap | _ -> reg.(int_of_id_t id_t1)
    in
    let dest =
      match id_t2 with "min_caml_hp" -> !heap | _ -> reg.(int_of_id_t id_t2)
    in
    let offset =
      (match id_or_imm with
      | V "min_caml_hp" -> !heap
      | V id_t -> reg.(int_of_id_t id_t)
      | C n -> n)
      * x
    in
    let m' = dest + offset in
    Log.debug
      (Printf.sprintf
         "St (id_t1: %s, id_t2: %s, dest: %d, offset: %d, m: %d), res: %d"
         id_t1
         id_t2
         dest
         offset
         m'
         src);
    mem.(m') <- src;
    0
  | Comment _ -> 0
  | IfEq (id1, id_or_imm, t1, t2) ->
    let r1 =
      match id1 with "min_caml_hp" -> !heap | _ -> reg.(int_of_id_t id1)
    in
    let r2 =
      match id_or_imm with V id_t -> reg.(int_of_id_t id_t) | C i -> i
    in
    Log.debug
      (Printf.sprintf
         "IfEq (id1: %s, id2: %s, t1: %d, t2: %d)"
         id1
         (string_of_id_or_imm id_or_imm)
         r1
         r2);
    if r1 = r2 then interp prog t1 reg mem else interp prog t2 reg mem
  | IfLE (id, id_or_imm, t1, t2) ->
    let r1 =
      match id with "min_caml_hp" -> !heap | _ -> reg.(int_of_id_t id)
    in
    let r2 =
      match id_or_imm with V id_t -> reg.(int_of_id_t id_t) | C i -> i
    in
    Log.debug
      (Printf.sprintf
         "IfLE (id: %s, id_or_imm: %s, t1: %d, t2: %d)"
         id
         (string_of_id_or_imm id_or_imm)
         r1
         r2);
    if r1 <= r2 then interp prog t1 reg mem else interp prog t2 reg mem
  | IfGE (id, id_or_imm, t1, t2) ->
    let r1 =
      match id with "min_caml_hp" -> !heap | _ -> reg.(int_of_id_t id)
    in
    let r2 =
      match id_or_imm with V id_t -> reg.(int_of_id_t id_t) | C i -> i
    in
    Log.debug
      (Printf.sprintf
         "IfGE (id1: %s, id2: %s, t1: %d, t2: %d)"
         id
         (string_of_id_or_imm id_or_imm)
         r1
         r2);
    if r1 >= r2 then interp prog t1 reg mem else interp prog t2 reg mem
  | CallCls (id_t, args, _) ->
    let r1 = reg.(int_of_id_t id_t) in
    let m1 = mem.(r1) in
    let (Id.L id) = find_label prog m1 in
    Log.debug
      (Printf.sprintf
         "CallCls (id_t: %s, r1: %d, r2: %d, id_l: %s)"
         id_t
         r1
         m1
         id);
    let fundef = lookup_by_id_l prog (Id.L id) in
    let reg' = make_reg reg fundef.args args in
    reg'.(int_of_id_t id) <- r1;
    interp prog fundef.body reg' mem
  | CallDir (Id.L "min_caml_print_int", [ arg ], _) ->
    let v = reg.(int_of_id_t arg) in
    Log.debug (Printf.sprintf "CallDir min_caml_print_int %d" v);
    print_int v;
    0
  | CallDir (Id.L "min_caml_print_newline", _, _) ->
    print_newline ();
    0
  | CallDir (Id.L "min_caml_truncate", _, [ farg ]) ->
    raise (Un_implemented_instruction "min_caml_truncate is not implemented.")
  | CallDir (Id.L "min_caml_create_array", [ arg1; arg2 ], _) ->
    let size = reg.(int_of_id_t arg1) in
    let init = reg.(int_of_id_t arg2) in
    let a = !heap in
    heap := !heap + (size * 4);
    for i = 0 to size do
      mem.(a + (i * 4)) <- init
    done;
    Log.debug
      (Printf.sprintf
         "CallDir (min_caml_create_array, arg1: %d, arg2: %d)"
         size
         init);
    a
  | CallDir (name, args, _) ->
    (* fundef.args: 仮引数 args: 実引数 *)
    let pc = (Array.of_list args).(1) in
    print_endline (int_of_id_t pc |> Array.get reg |> string_of_int);
    let fundef = lookup_by_id_l prog name in
    let reg' = make_reg reg fundef.args args in
    let (Id.L s) = name in
    Log.debug (Printf.sprintf "CallDir %s" s);
    interp prog fundef.body reg' mem
  | _ -> raise (Un_implemented_instruction "Not implemented.")
;;

let f prog =
  let reg = Array.make register_size 0 in
  let mem = Array.make register_size 0 in
  let prog' = prog_with_label prog in
  let (ProgWithLabel (_, _, instructions, labels)) = prog' in
  interp prog' instructions reg mem
;;
