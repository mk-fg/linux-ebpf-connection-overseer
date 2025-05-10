##  SDL ABI utils.
##
#[
  SPDX-License-Identifier: NCSA OR MIT OR Zlib
]#

import std/[ macros, re ]
import libsdl3

type SDLError* = object of Defect

proc raise_sdl_err_for_ast(ast: string) {.inline.} =
  let name = try: ast.replacef(re"^\s*([\w.]+).*", "$1") except ValueError: ast
  raise SDLError.newException(name & " failed: " & $SDL_GetError())

template chk*(body: untyped) = # check for cbool=true returns
  let res = body
  if unlikely res.uint == 0: raise_sdl_err_for_ast(astToStr(body))

template chk_nil*(body: untyped) =
  when result.typeof isnot ptr:
    {.fatal: "chk_nil requires function that returns pointer".}
  result = body
  if unlikely result.isNil: raise_sdl_err_for_ast(astToStr(body))

template chk_err_if*(check: untyped, body: untyped) =
  result = body
  let res = check
  if unlikely res: raise_sdl_err_for_ast(astToStr(body))

# vim: set sts=2 et sw=2:
