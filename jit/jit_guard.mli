open MinCaml
open Jit_env

val restore : reg -> args:string list -> Asm.t -> Asm.t
val promote : reg -> trace_name:string -> Asm.t -> Asm.t

module TJ : sig
  val create : reg -> string -> ?wlist:string list -> Asm.t -> Asm.t
end

module MJ : sig
  val create : reg -> env -> ?wlist:string list -> Asm.t -> Asm.t
end
