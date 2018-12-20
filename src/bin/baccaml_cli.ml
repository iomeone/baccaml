open MinCaml
open RCaml
open BacCaml
open Jit_prep

let _ =
  run begin fun jittype env ->
    let { prog; reg; mem; red_args; ex_name; merge_pc; trace_name } = env in
    let trace =
      match jittype with
      | `Meta_tracing ->
        [Jit_tracing.run_while prog reg mem trace_name (red_args) 3 merge_pc]
      | `Meta_method ->
        Jit_method.run_while prog reg mem trace_name ("stack" :: red_args)
    in
    Logs.debug (fun m -> List.iter (fun t -> m "%s\n" (Emit_virtual.to_string_fundef t)) trace);
    Jit_emit.emit_result ~prog:prog ~traces:trace ~file:ex_name ~jit_type:jittype
  end
