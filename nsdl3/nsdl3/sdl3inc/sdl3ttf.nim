##  SDL_ttf (separate .so lib) definitions.
##
#[
  SPDX-License-Identifier: NCSA OR MIT OR Zlib
]#

{.push raises: [].}

type
  Font* {.final, incompletestruct, pure.} = ptr object

  TextEngine* {.final, incompletestruct, pure.} = ptr object

  TextData* {.final, incompletestruct, pure.} = ptr object
  Text* {.final, incompletestruct, pure.} = ptr object
    text*: cstring
    num_lines*: cint
    refcount*: cint
    internal*: TextData

  FontStyleFlags* {.size: cint.sizeof.} = enum
    TTF_STYLE_NORMAL = 0x00
    TTF_STYLE_BOLD = 0x01
    TTF_STYLE_ITALIC = 0x02
    TTF_STYLE_UNDERLINE = 0x04
    TTF_STYLE_STRIKETHROUGH = 0x08

  HintingFlags* {.size: cint.sizeof.} = enum
    TTF_HINTING_INVALID = -1
    TTF_HINTING_NORMAL
    TTF_HINTING_LIGHT
    TTF_HINTING_MONO
    TTF_HINTING_NONE
    TTF_HINTING_LIGHT_SUBPIXEL

# vim: set sts=2 et sw=2:
