open Util
open Jit.Util

let dir = "min-interp/"

let setup aa bb =
  List.iter (fun (a, i) -> bb.(i) <- value_of a)
    (List.zip (Array.to_list aa) (List.range 0 (Array.length aa - 1)))
