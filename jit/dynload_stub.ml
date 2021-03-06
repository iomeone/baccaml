external call_dlfun_arg1 : string -> string -> int -> int = "call_dlfun_arg1"

external call_dlfun_arg2
  :  string
  -> string
  -> int
  -> int
  -> int
  = "call_dlfun_arg2"

external call_dlfun_arg3
  :  string
  -> string
  -> int
  -> int
  -> int
  -> int
  = "call_dlfun_arg3"

let call_arg1 ~lib ~func ~arg1 = call_dlfun_arg1 lib func arg1
let call_arg2 ~lib ~func ~arg1 ~arg2 = call_dlfun_arg2 lib func arg1 arg2

let call_arg3 ~lib ~func ~arg1 ~arg2 ~arg3 =
  call_dlfun_arg3 lib func arg1 arg2 arg3
;;
