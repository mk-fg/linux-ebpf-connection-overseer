##  SDL ABI utils.
##
#[
  SPDX-License-Identifier: NCSA OR MIT OR Zlib
]#

type SDLError* = object of Defect

when defined uselogging:
  import std/logging
import std/[ macros, re ]

const
  uselogging {.booldefine.} = false

when uselogging:
  template log_error*(args: varargs[typed, `$`]) =
    try:
      unpackVarargs echo, "ERROR: SDL3: ", args
    except Exception:
      discard
else:
  template log_error*(args: varargs[typed, `$`]) =
    unpackVarargs echo, "ERROR: SDL3: ", args

macro available_since*(procvar: typed, minver: string) =
  ##  Check whether unchecked function is available.
  ##
  ##  If the function is not available, the default value of return type
  ##  is returned.
  let procname = $procvar
  return quote do:
    if `procvar` == nil:
      log_error `procname`, " is available since SDL ", `minver`
      return result.type.default

template ensure_not_nil*(procname: string, body: untyped) =
  when result.typeof isnot ptr:
    {.fatal: "ensure_not_nil requires function that returns pointer".}
  result = body
  if unlikely result == nil:
    log_error procname, " failed: ", $SDL_GetError()
    return nil

template ensure_natural*(procname: string, body: untyped) =
  result = body
  if unlikely result < 0:
    log_error procname, " failed: ", $SDL_GetError()

template ensure_positive*(procname: string, body: untyped) =
  result = body
  if unlikely result <= 0:
    log_error procname, " failed: ", $SDL_GetError()

template chk*(body: untyped) = # easy-to-use "returns true on success" check
  let res = body
  if unlikely res.uint == 0:
    let name =
      try: astToStr(body).replacef(re"^\s*([\w.]+).*", "$1")
      except ValueError: astToStr(body)
    raise SDLError.newException(name & " failed: " & $SDL_GetError())

template chk_nil*(body: untyped) =
  when result.typeof isnot ptr:
    {.fatal: "chk_nil requires function that returns pointer".}
  result = body
  if unlikely result.isNil:
    let name =
      try: astToStr(body).replacef(re"^\s*([\w.]+).*", "$1")
      except ValueError: astToStr(body)
    raise SDLError.newException(name & " failed: " & $SDL_GetError())

# vim: set sts=2 et sw=2:
