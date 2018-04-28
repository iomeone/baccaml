open Util
open Jit_config

let dir = "test/data/"

let () =
  Logger.log_level := Logger.Debug

let setup aa bb =
  List.iter
    (fun (a, i) -> bb.(i) <- value_of a)
    (ListUtil.zip (Array.to_list aa) (ListUtil.range 0 (Array.length aa - 1)))

module Test_dependencies = struct
  include Tracing_jit
  include Method_jit
  include Jit_config
  include Mincaml_util
end
