open Ast

let escape_markdown_characters s =
  let b = Buffer.create (String.length s * 2) in
  for i = 0 to String.length s - 1 do
    match s.[i] with
    | '.' as c ->
        if i > 0 &&
           match s.[i-1] with
           | '0' .. '9' -> i+1 < String.length s && s.[i+1] = ' '
           | _ -> false
        then
          Buffer.add_char b '\\';
        Buffer.add_char b c
    | '-' as c ->
        if (i = 0 || match s.[i-1] with ' '| '\n' -> true | _ -> false) &&
           (i+1 < String.length s && (s.[i+1] = ' '||s.[i+1] = '-'))
        then
          Buffer.add_char b '\\';
        Buffer.add_char b c
    | '+' as c ->
        if (i = 0 || match s.[i-1] with ' '| '\n' -> true | _ -> false) &&
           (i+1 < String.length s && s.[i+1] = ' ')
        then
          Buffer.add_char b '\\';
        Buffer.add_char b c
    | '!' as c ->
        if i+1 < String.length s && s.[i+1] = '[' then Buffer.add_char b '\\';
        Buffer.add_char b c
    | '<' as c ->
        if i <> String.length s - 1 &&
           (match s.[i+1] with 'a' .. 'z' | 'A' .. 'Z' -> false | _ -> true)
        then
          Buffer.add_char b '\\';
        Buffer.add_char b c
    | '>' as c ->
        if i = 0 || (match s.[i-1] with ' ' | '\n' -> false | _ -> true) then
          Buffer.add_char b '\\';
        Buffer.add_char b c
    | '#' as c ->
        if i = 0 || s.[i-1] = '\n' then Buffer.add_char b '\\';
        Buffer.add_char b c
    | '\\' | '[' | ']' | '(' | ')' | '`' | '*' as c ->
        Buffer.add_char b '\\';
        Buffer.add_char b c
    | c ->
        Buffer.add_char b c
  done;
  Buffer.contents b

let rec inline b = function
  | Concat l ->
      List.iter (inline b) l
  | Text t ->
      Printf.bprintf b "%s" (escape_markdown_characters t)
  | Emph {kind = Normal; style; content} ->
      let q = match style with Star -> '*' | Underscore -> '_' in
      Printf.bprintf b "%c%a%c" q inline content q
  | Emph {kind = Strong; style; content} ->
      let q = match style with Star -> '*' | Underscore -> '_' in
      Printf.bprintf b "%c%c%a%c%c" q q inline content q q
  | Code (n, c) ->
      let d = String.make n '`' in
      Printf.bprintf b "%s%s%s" d c d
  | Hard_break ->
      Buffer.add_string b "<br />"
  | Html body ->
      Buffer.add_string b body
  | Link {kind = Url; def = {label; destination; title = None}} ->
      Printf.bprintf b "[%a](%s)" inline label destination
  | Link {kind = Img; def = {label; destination; title = None}} ->
      Printf.bprintf b "![%a](%s)" inline label (* FIXME *) destination
  | Link {kind = Url; def = {label; destination; title = Some title}} ->
      Printf.bprintf b "[%a](%s \"%s\")" inline label destination title
  | Link {kind = Img; def = {label; destination; title = Some title}} ->
      Printf.bprintf b "![%a](%s \"%s\")" inline label (* FIXME *) destination title
  | Ref {kind = Url; label; def = {Ast.label = label'; _}} ->
      Printf.bprintf b "[%a][%s]" inline label label'
  | Ref {kind = Img; label; def = {Ast.label = label'; _}} ->
      Printf.bprintf b "![%a][%s]" inline label label'
  | Soft_break ->
      if Buffer.length b = 1 ||
         (Buffer.length b > 1 &&
          not(Buffer.nth b (Buffer.length b - 1) = '\n' &&
              Buffer.nth b (Buffer.length b - 2) = '\n'))
      then
        Buffer.add_string b "\n"