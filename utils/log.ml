type level = [
  | `Error
  | `Debug
  | `Warn
  | `App
  ]

let log_level : level ref = ref `Error

let error s =
  match !log_level with
  | `Error -> print_endline ("[err] " ^ s)
  | _ -> ()

let debug s =
  match !log_level with
  | `Debug -> print_endline ("[debug] " ^ s)
  | _ -> ()

let warn s =
  match !log_level with
  | `Error | `Warn -> print_endline ("[warn] " ^ s)
  | _ -> ()

let app s =
  match !log_level with
  | `Error | `Warn | `App -> Format.printf "[app] %s\n" s
  | _ -> ()