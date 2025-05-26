##  High level SDL 3.0 shared library wrapper for Nim.
#[
  SPDX-License-Identifier: NCSA OR MIT OR Zlib
]#

{.push raises: [].}

import nsdl3/libsdl3
import nsdl3/utils

export open_sdl3_library, close_sdl3_library, last_sdl3_error
export open_sdl3_ttf_library, close_sdl3_ttf_library, last_sdl3_ttf_error
export SDLError

import nsdl3/sdl3inc/sdl3blendmode
export sdl3blendmode
import nsdl3/sdl3inc/sdl3events
export sdl3events
import nsdl3/sdl3inc/sdl3hints
export sdl3hints
import nsdl3/sdl3inc/sdl3init
export sdl3init
import nsdl3/sdl3inc/sdl3log
export sdl3log
import nsdl3/sdl3inc/sdl3pixels
export sdl3pixels
import nsdl3/sdl3inc/sdl3properties
import nsdl3/sdl3inc/sdl3rect
export sdl3rect
import nsdl3/sdl3inc/sdl3render
export sdl3render
import nsdl3/sdl3inc/sdl3surface
export sdl3surface
import nsdl3/sdl3inc/sdl3timer
export sdl3timer
import nsdl3/sdl3inc/sdl3ttf
export sdl3ttf
import nsdl3/sdl3inc/sdl3video
export sdl3video

# =========================================================================== #
# ==  SDL3 library functions                                               == #
# =========================================================================== #

converter from_sdl_bool(b: cbool): bool = b.int != 0
converter to_sdl_bool(b: bool): cbool = b.cbool
proc c_free(mem: pointer) {.header: "<stdlib.h>", importc: "free", nodecl.}

# --------------------------------------------------------------------------- #
# <SDL3/SDL_blendmode.h>                                                      #
# --------------------------------------------------------------------------- #

proc ComposeCustomBlendMode*(src_color_factor: BlendFactor,
                             dst_color_factor: BlendFactor,
                             color_operation: BlendOperation,
                             src_alpha_factor: BlendFactor,
                             dst_alpha_factor: BlendFactor,
                             alpha_operation: BlendOperation): BlendMode =
  ##  Compose a custom blend mode for renderers.
  SDL_ComposeCustomBlendMode src_color_factor, dst_color_factor,
                             color_operation, src_alpha_factor,
                             dst_alpha_factor, alpha_operation

# --------------------------------------------------------------------------- #
# <SDL3/SDL_error.h>                                                          #
# --------------------------------------------------------------------------- #

proc ClearError*(): bool {.discardable, inline.} =
  ##  ```c
  ##  void SDL_ClearError(void)
  ##  ```
  SDL_ClearError()

# int SDL_Error(SDL_errorcode code)

proc GetError*(): string {.inline.} =
  ##  ```c
  ##  const char *SDL_GetError(void)
  ##  ```
  $SDL_GetError()

# int SDL_SetError(const char *fmt, ...)

# --------------------------------------------------------------------------- #
# <SDL3/SDL_events.h>                                                         #
# --------------------------------------------------------------------------- #

# XXX: file removed
#proc free_drop_event_file*(event: var Event) =
#  ##  Free memory allocated for `EVENT_DROP_FILE` or `EVENT_DROP_TEXT`.
#  if event.typ == EVENT_DROP_FILE or event.typ == EVENT_DROP_TEXT:
#    if event.drop.file != nil:
#      sdl3_free event.drop.file
#      event.drop.file = nil       # Just in case.
# XXX:

# int SDL_AddEventWatch(SDL_EventFilter filter, void *userdata)
# void *SDL_AllocateEventMemory(size_t size)
# void SDL_DelEventWatch(SDL_EventFilter filter, void *userdata)
# SDL_bool SDL_EventEnabled(Uint32 type)
# void SDL_FilterEvents(SDL_EventFilter filter, void *userdata)
# void SDL_FlushEvent(Uint32 type)
# void SDL_FlushEvents(Uint32 minType, Uint32 maxType)
# SDL_bool SDL_GetEventFilter(SDL_EventFilter *filter, void **userdata)
# SDL_Window * SDL_GetWindowFromEvent(const SDL_Event *event)
# SDL_bool SDL_HasEvent(Uint32 type)
# SDL_bool SDL_HasEvents(Uint32 minType, Uint32 maxType)

proc PeepEvents*(events: var openArray[Event], num_events: int,
    action: EventAction, min_type: EventType, max_type: EventType): int =
  ##  ```c
  ##  int SDL_PeepEvents(SDL_Event *events, int numevents,
  ##                     SDL_eventaction action, Uint32 minType,
  ##                     Uint32 maxType)
  ##  ```
  let n = cint min(num_events, events.len)
  {.cast(gcsafe).}:
    chk_err_if result < 0: SDL_PeepEvents events[0].addr, n, action, min_type, max_type

proc PeepEvents*(events: var openArray[Event],
    action: EventAction, min_type: EventType, max_type: EventType): int {.inline.} =
  PeepEvents events, events.len, action, min_type, max_type

proc PeepEvents*(min_type: EventType, max_type: EventType): int =
  {.cast(gcsafe).}:
    chk_err_if result < 0: SDL_PeepEvents nil, 0, PEEKEVENT, min_type, max_type

proc PollEvent*(): bool {.inline.} =
  ##  ```c
  ##  int SDL_PollEvent(SDL_Event *event)
  ##  ```
  SDL_PollEvent nil

proc PollEvent*(event: var Event): bool {.inline.} =
  ##  ```c
  ##  int SDL_PollEvent(SDL_Event *event)
  ##  ```
  SDL_PollEvent event.addr

proc PumpEvents*() {.inline.} =
  ##  ```c
  ##  void SDL_PumpEvents(void)
  ##  ```
  SDL_PumpEvents()

proc PushEvent*(event: var Event): bool {.inline.} =
  ##  ```c
  ##  int SDL_PushEvent(SDL_Event *event)
  ##  ```
  {.cast(gcsafe).}: SDL_PushEvent event.addr

# Uint32 SDL_RegisterEvents(int numevents)

proc SetEventEnabled*(typ: EventType, state: bool) {.inline.} =
  ##  Set the state of processing events by type.
  ##
  ##  ```c
  ##  void SDL_SetEventEnabled(Uint32 type, SDL_bool enabled)
  ##  ```
  SDL_SetEventEnabled(typ.uint32, state)

# void SDL_SetEventFilter(SDL_EventFilter filter, void *userdata)

proc WaitEvent*(): bool {.inline.} =
  ##  ```c
  ##  int SDL_WaitEvent(SDL_Event *event)
  ##  ```
  SDL_WaitEvent nil

proc WaitEvent*(event: var Event): bool {.inline.} =
  ##  ```c
  ##  int SDL_WaitEvent(SDL_Event *event)
  ##  ```
  SDL_WaitEvent event.addr

proc WaitEventTimeout*(timeout: int32): bool {.inline.} =
  ##  ```c
  ##  int SDL_WaitEventTimeout(SDL_Event *event, Sint32 timeoutMS)
  ##  ```
  SDL_WaitEventTimeout nil, timeout

proc WaitEventTimeout*(event: var Event, timeout: int32): bool {.inline.} =
  ##  ```c
  ##  int SDL_WaitEventTimeout(SDL_Event *event, Sint32 timeoutMS)
  ##  ```
  SDL_WaitEventTimeout event.addr, timeout

# --------------------------------------------------------------------------- #
# <SDL3/SDL_hints.h>                                                          #
# --------------------------------------------------------------------------- #

# int SDL_AddHintCallback(const char *name, SDL_HintCallback callback,
#     void *userdata)
# void SDL_ClearHints(void)
# void SDL_DelHintCallback(const char *name, SDL_HintCallback callback,
#     void *userdata)

proc GetHint*(name: HintName): string {.inline.} =
  ##  ```c
  ##  const char * SDL_GetHint(const char *name)
  ##  ```
  $SDL_GetHint name

# SDL_bool SDL_GetHintBoolean(const char *name, SDL_bool default_value)
# SDL_bool SDL_ResetHint(const char *name)
# void SDL_ResetHints(void)

proc SetHint*(name: HintName, value: string) =
  ##  ```c
  ##  SDL_bool SDL_SetHint(const char *name, const char *value)
  ##  ```
  chk SDL_SetHint(cstring $name, value.cstring)

# SDL_bool SDL_SetHintWithPriority(const char *name, const char *value,
#     SDL_HintPriority priority)

# --------------------------------------------------------------------------- #
# <SDL3/SDL_init.h>                                                           #
# --------------------------------------------------------------------------- #

proc Init*(flags: InitFlags = INIT_VIDEO) =
  ##  Initialize SDL3 library.
  chk SDL_Init(flags)

proc InitSubSystem*(flags: InitFlags) =
  ##  Initialize SDL3 subsystem.
  chk SDL_InitSubSystem(flags)

proc Quit*() =
  ##  Clean up all initialized subsystems.
  SDL_Quit()

proc QuitSubSystem*(flags: InitFlags) {.inline.} =
  ##  ```c
  ##  void SDL_QuitSubSystem(Uint32 flags)
  ##  ```
  SDL_QuitSubSystem flags

proc SetAppMetadata*(appname: string, appversion: string,
                     appidentifier: string) =
  ##  XXX.
  chk SDL_SetAppMetadata(appname, appversion, appidentifier)

proc SetAppMetadataProperty*(name: AppMetadataProperty, value: string) =
  ##  XXX.
  chk SDL_SetAppMetadataProperty(name, value)

proc WasInit*(flags: InitFlags = INIT_NONE): InitFlags {.inline.} =
  ##  ```c
  ##  Uint32 SDL_WasInit(Uint32 flags)
  ##  ```
  SDL_WasInit flags

# --------------------------------------------------------------------------- #
# <SDL3/SDL_log.h>                                                            #
# --------------------------------------------------------------------------- #

# SDL_Log, SDL_LogCritical, SDL_LogDebug, SDL_LogError, SDL_LogInfo,
# SDL_LogVerbose and SDL_LogWarn are emulated by calling SDL_LogMessage.

proc LogMessage*(category: LogCategory, priority: LogPriority, message: string)

proc Log*(message: string) {.inline.} =
  ##  ```c
  ##  void SDL_Log(const char *fmt, ...)
  ##  ```
  LogMessage LOG_CATEGORY_APPLICATION, LOG_PRIORITY_INFO, message

proc LogCritical*(category: LogCategory, message: string) {.inline.} =
  ##  ```c
  ##  void SDL_LogCritical(int category, const char *fmt, ...)
  ##  ```
  LogMessage category, LOG_PRIORITY_CRITICAL, message

proc LogDebug*(category: LogCategory, message: string) {.inline.} =
  ##  ```c
  ##  void SDL_LogDebug(int category, const char *fmt, ...)
  ##  ```
  LogMessage category, LOG_PRIORITY_DEBUG, message

proc LogError*(category: LogCategory, message: string) {.inline.} =
  ##  ```c
  ##  void SDL_LogError(int category, const char *fmt, ...)
  ##  ```
  LogMessage category, LOG_PRIORITY_ERROR, message

# void SDL_LogGetOutputFunction(SDL_LogOutputFunction *callback,
#     void **userdata)
# SDL_LogPriority SDL_LogGetPriority(int category)

proc LogInfo*(category: LogCategory, message: string) {.inline.} =
  ##  ```c
  ##  void SDL_LogInfo(int category, const char *fmt, ...)
  ##  ```
  LogMessage category, LOG_PRIORITY_INFO, message

proc LogMessage*(category: LogCategory, priority: LogPriority,
                 message: string) =
  ##  ```c
  ##  void SDL_LogMessage(int category, SDL_LogPriority priority,
  ##                      const char *fmt, ...)
  ##  ```
  SDL_LogMessage category, priority, "%s", message.cstring

# void SDL_LogMessageV(int category, SDL_LogPriority priority, const char *fmt,
#                      va_list ap)
# void SDL_LogResetPriorities(void)
# void SDL_LogSetAllPriority(SDL_LogPriority priority)

proc SetLogOutputFunction*(callback: LogOutputFunction,
                           userdata: pointer = nil) {.inline.} =
  ##  ```c
  ##  void SDL_SetLogOutputFunction(SDL_LogOutputFunction callback,
  ##                                void *userdata)
  ##  ```
  SDL_SetLogOutputFunction callback, userdata

proc SetLogPriority*(category: LogCategory, priority: LogPriority) {.inline.} =
  ##  ```c
  ##  void SDL_LogSetPriority(int category, SDL_LogPriority priority)
  ##  ```
  SDL_SetLogPriority category, priority

proc LogVerbose*(category: LogCategory, message: string) {.inline.} =
  ##  ```c
  ##  void SDL_LogVerbose(int category, const char *fmt, ...)
  ##  ```
  LogMessage category, LOG_PRIORITY_VERBOSE, message

proc LogWarn*(category: LogCategory, message: string) {.inline.} =
  ##  ```c
  ##  void SDL_LogWarn(int category, const char *fmt, ...)
  ##  ```
  LogMessage category, LOG_PRIORITY_WARN, message

# --------------------------------------------------------------------------- #
# <SDL3/SDL_pixels.h>                                                         #
# --------------------------------------------------------------------------- #

proc CreatePalette*(ncolors: int): ptr Palette =
  ##  ```c
  ##  SDL_Palette *SDL_CreatePalette(int ncolors)
  ##  ```
  chk_nil SDL_CreatePalette(ncolors.cint)

# SDL_PixelFormat * SDL_CreatePixelFormat(Uint32 pixel_format)

proc DestroyPalette*(palette: ptr Palette) =
  ##  ```c
  ##  void SDL_DestroyPalette(SDL_Palette *palette)
  ##  ```
  SDL_DestroyPalette palette

# void SDL_DestroyPixelFormat(SDL_PixelFormat *format)
# SDL_bool SDL_GetMasksForPixelFormatEnum(Uint32 format, int *bpp,
#     Uint32 *Rmask, Uint32 *Gmask, Uint32 *Bmask, Uint32 *Amask)

proc GetPixelFormatDetails*(format: PixelFormatEnum): PixelFormatDetails =
  ##  ```c
  ##  const SDL_PixelFormatDetails * SDL_GetPixelFormatDetails(SDL_PixelFormat format)
  ##  ```
  let details = SDL_GetPixelFormatDetails format
  if details.isNil: raise SDLError.newException("SDL_GetPixelFormatDetails failed: " & $SDL_GetError())
  return details[]

proc GetPixelFormatForMasks*(bpp: int, rmask: uint32, gmask: uint32,
                             bmask: uint32,
                             amask: uint32): PixelFormatEnum {.inline.} =
  ##  Convert bits/pixel value and RGBA masks to pixel format.
  ##
  ##  Return `PIXELFORMAT_UNKNOWN` if the conversion failed.
  ##
  ##  ```c
  ##  Uint32 SDL_GetPixelFormatEnumForMasks(int bpp, Uint32 Rmask,
  ##                                        Uint32 Gmask, Uint32 Bmask,
  ##                                        Uint32 Amask)
  ##  ```
  SDL_GetPixelFormatForMasks bpp.cint, rmask, gmask, bmask, amask

proc GetPixelFormatName*(format: PixelFormatEnum): string =
  $SDL_GetPixelFormatName(format)

# const char* SDL_GetPixelFormatName(Uint32 format)
# void SDL_GetRGB(Uint32 pixel, const SDL_PixelFormat *format, Uint8 *r,
#     Uint8 *g, Uint8 *b)
# void SDL_GetRGBA(Uint32 pixel, const SDL_PixelFormat *format, Uint8 *r,
#     Uint8 *g, Uint8 *b, Uint8 *a)

proc MapRGB*(format: PixelFormatDetails, palette: Palette,
             r: byte, g: byte, b: byte): uint32 =
  ##  ```c
  ##  Uint32 SDL_MapRGB(const SDL_PixelFormat *format,
  ##                    Uint8 r, Uint8 g, Uint8 b)
  ##  ```
  SDL_MapRGB format.addr, palette.addr, r, g, b

proc MapRGBA*(format: PixelFormatDetails, palette: Palette,
              r: byte, g: byte, b: byte, a: byte): uint32 =
  ##  ```c
  ##  Uint32 SDL_MapRGBA(const SDL_PixelFormat *format,
  ##                     Uint8 r, Uint8 g, Uint8 b, Uint8 a)
  ##  ```
  SDL_MapRGBA format.addr, palette.addr, r, g, b, a

proc SetPaletteColors*(palette: var Palette, colors: openArray[Color],
                       firstcolor: int = 0, ncolors: int = 0) =
  let ncolors = if ncolors > 0: ncolors else: colors.len - firstcolor
  chk SDL_SetPaletteColors(palette.addr, colors[0].addr, firstcolor.cint, ncolors.cint)

# int SDL_SetPixelFormatPalette(SDL_PixelFormat *format, SDL_Palette *palette)

# --------------------------------------------------------------------------- #
# <SDL3/SDL_properties.h>                                                     #
# --------------------------------------------------------------------------- #

proc CreateProperties*(): PropertiesID =
  ##  ```c
  ##  SDL_PropertiesID SDL_CreateProperties(void)
  ##  ```
  chk_err_if result == PropertiesID 0: SDL_CreateProperties()

proc DestroyProperties*(props: PropertiesID) {.inline.} =
  ##  ```c
  ##  void SDL_DestroyProperties(SDL_PropertiesID props)
  ##  ```
  SDL_DestroyProperties props

# int SDL_ClearProperty(SDL_PropertiesID props, const char *name)
# int SDL_EnumerateProperties(SDL_PropertiesID props, SDL_EnumeratePropertiesCallback callback, void *userdata)
# SDL_bool SDL_GetBooleanProperty(SDL_PropertiesID props, const char *name, SDL_bool default_value)
# float SDL_GetFloatProperty(SDL_PropertiesID props, const char *name, float default_value)
# SDL_PropertiesID SDL_GetGlobalProperties(void)
# Sint64 SDL_GetNumberProperty(SDL_PropertiesID props, const char *name, Sint64 default_value)
# void * SDL_GetProperty(SDL_PropertiesID props, const char *name, void *default_value)
# SDL_PropertyType SDL_GetPropertyType(SDL_PropertiesID props, const char *name)
# const char * SDL_GetStringProperty(SDL_PropertiesID props, const char *name, const char *default_value)
# int SDL_LockProperties(SDL_PropertiesID props)
# int SDL_SetBooleanProperty(SDL_PropertiesID props, const char *name, SDL_bool value)
# int SDL_SetFloatProperty(SDL_PropertiesID props, const char *name, float value)

proc SetNumberProperty*(props: PropertiesID, name: cstring, value: int64) =
  ##  ```c
  ##  int SDL_SetNumberProperty(SDL_PropertiesID props, const char *name, Sint64 value)
  ##  ```
  chk SDL_SetNumberProperty(props, name, value)

# int SetProperty(SDL_PropertiesID props, const char *name, void *value)
# int SDL_SetPropertyWithCleanup(SDL_PropertiesID props, const char *name,
#     void *value, void (*cleanup)(void *userdata, void *value),
#     void *userdata)

proc SetStringProperty*(props: PropertiesID, name: cstring, value: string) =
  ##  ```c
  ##  int SDL_SetStringProperty(SDL_PropertiesID props, const char *name, const char *value)
  ##  ```
  chk SDL_SetStringProperty(props, name, value)

# void SDL_UnlockProperties(SDL_PropertiesID props)

# --------------------------------------------------------------------------- #
# <SDL3/SDL_rect.h>                                                           #
# --------------------------------------------------------------------------- #

# SDL_bool SDL_GetRectAndLineIntersection(const SDL_Rect *rect, int *X1,
#     int *Y1, int *X2, int *Y2)
# SDL_bool SDL_GetRectAndLineIntersectionFloat(const SDL_FRect *rect,
#     float *X1, float *Y1, float *X2, float *Y2)
# SDL_bool SDL_GetRectEnclosingPoints(const SDL_Point *points, int count,
#     const SDL_Rect *clip, SDL_Rect *result)
# SDL_bool SDL_GetRectEnclosingPointsFloat(const SDL_FPoint *points,
#     int count, const SDL_FRect *clip, SDL_FRect *result)
# SDL_bool SDL_GetRectIntersection(const SDL_Rect *A, const SDL_Rect *B,
#     SDL_Rect *result)
# SDL_bool SDL_GetRectIntersectionFloat(const SDL_FRect *A,
#     const SDL_FRect *B, SDL_FRect *result)

func RectToFRect*(rect: Rect, frect: var FRect) {.inline.} =
  ##  Convert an `Rect` to `FRect`.
  frect.x = cfloat rect.x
  frect.y = cfloat rect.y
  frect.w = cfloat rect.w
  frect.h = cfloat rect.h

# int SDL_GetRectUnion(const SDL_Rect *A, const SDL_Rect *B, SDL_Rect *result)
# int SDL_GetRectUnionFloat(const SDL_FRect *A, const SDL_FRect *B,
#     SDL_FRect *result)
# SDL_bool SDL_HasRectIntersection(const SDL_Rect *A, const SDL_Rect *B)
# SDL_bool SDL_HasRectIntersectionFloat(const SDL_FRect *A, const SDL_FRect *B)

# --------------------------------------------------------------------------- #
# <SDL3/SDL_render.h>                                                         #
# --------------------------------------------------------------------------- #

# int SDL_ConvertEventToRenderCoordinates(SDL_Renderer *renderer,
#     SDL_Event *event)

proc CreateRenderer*(window: Window): Renderer =
  ##  ```c
  ##  SDL_Renderer *SDL_CreateRenderer(SDL_Window *window, const char *name,
  ##                                   Uint32 flags)
  ##  ```
  chk_nil SDL_CreateRenderer(window, nil)

proc CreateRenderer*(window: Window, name: string): Renderer =
  ##  ```c
  ##  SDL_Renderer *SDL_CreateRenderer(SDL_Window *window, const char *name,
  ##                                   Uint32 flags)
  ##  ```
  chk_nil SDL_CreateRenderer(window, name.cstring)

proc CreateRendererWithProperties*(props: PropertiesID): Renderer =
  ##  Create a 2D rendering context for a window, with the specified
  ##  properties.
  ##
  ##  `SDL_CreateRendererWithProperties`
  chk_nil SDL_CreateRendererWithProperties(props)

# SDL_Renderer *SDL_CreateSoftwareRenderer(SDL_Surface *surface)

proc CreateTexture*(renderer: Renderer, format: PixelFormatEnum,
                    access: TextureAccess, width: int, height: int): Texture =
  ##  Create a texture for a rendering context.
  ##
  ##  `SDL_CreateTexture`
  chk_nil SDL_CreateTexture(renderer, format, access, width.cint, height.cint)

proc CreateTextureFromSurface*(renderer: Renderer, surface: SurfacePtr): Texture =
  ##  Create a texture from an existing surface.
  ##
  ##  `SDL_CreateTextureFromSurface`
  chk_nil SDL_CreateTextureFromSurface(renderer, surface)

proc CreateTextureWithProperties*(renderer: Renderer, props: PropertiesID): Texture =
  ##  Create a texture for a rendering context with the specified properties.
  ##
  ##  `SDL_CreateTextureWithProperties`
  chk_nil SDL_CreateTextureWithProperties(renderer, props)

proc CreateWindowAndRenderer*(title: string, width: int, height: int,
                              window_flags: WindowFlags = WindowFlags 0): tuple[window: Window, renderer: Renderer] =
  ##  Create a window and default renderer.
  ##
  ##  `SDL_CreateWindowAndRenderer`
  var out_window    : Window = nil
  var out_renderer  : Renderer = nil
  if SDL_CreateWindowAndRenderer( title, width.cint, height.cint,
    window_flags, out_window.addr, out_renderer.addr ): return (out_window, out_renderer)
  let err = $SDL_GetError()
  if out_renderer != nil: SDL_DestroyRenderer out_renderer
  if out_window != nil: SDL_DestroyWindow out_window
  raise SDLError.newException("SDL_CreateWindowAndRenderer failed: " & err)

proc DestroyRenderer*(renderer: Renderer) {.inline.} =
  ##  Destroy the window rendering context and free all textures.
  ##
  ##  `SDL_DestroyRenderer`
  SDL_DestroyRenderer renderer

proc DestroyTexture*(texture: Texture) {.inline.} =
  ##  Destroy the texture.
  ##
  ##  `SDL_DestroyTexture`
  SDL_DestroyTexture texture

# int SDL_FlushRenderer(SDL_Renderer *renderer)

# int SDL_GL_BindTexture(SDL_Texture *texture, float *texw, float *texh)
# int SDL_GL_UnbindTexture(SDL_Texture *texture)
# int SDL_GetCurrentRenderOutputSize(SDL_Renderer *renderer, int *w, int *h)
# int SDL_GetNumRenderDrivers(void)
# int SDL_GetRenderClipRect(SDL_Renderer *renderer, SDL_Rect *rect)
# int SDL_GetRenderDrawBlendMode(SDL_Renderer *renderer,
#     SDL_BlendMode *blendMode)
# int SDL_GetRenderDrawColor(SDL_Renderer *renderer, Uint8 *r, Uint8 *g,
#     Uint8 *b, Uint8 *a)
# const char *SDL_GetRenderDriver(int index)
# SDL_Renderer * SDL_GetRendererFromTexture(SDL_Texture *texture);
# int SDL_GetRenderLogicalPresentation(SDL_Renderer *renderer, int *w, int *h,
#     SDL_RendererLogicalPresentation *mode, SDL_ScaleMode *scale_mode)
# void *SDL_GetRenderMetalCommandEncoder(SDL_Renderer *renderer)
# void *SDL_GetRenderMetalLayer(SDL_Renderer *renderer)
# int SDL_GetRenderOutputSize(SDL_Renderer *renderer, int *w, int *h)
# SDL_PropertiesID SDL_GetRendererProperties(SDL_Renderer *renderer)
# int SDL_GetRenderScale(SDL_Renderer *renderer, float *scaleX, float *scaleY)
# SDL_Texture *SDL_GetRenderTarget(SDL_Renderer *renderer)
# int SDL_GetRenderVSync(SDL_Renderer *renderer, int *vsync)
# int SDL_GetRenderViewport(SDL_Renderer *renderer, SDL_Rect *rect)
# SDL_Window *SDL_GetRenderWindow(SDL_Renderer *renderer)

proc GetRenderer*(window: Window): Renderer =
  ##  ```c
  ##  SDL_Renderer *SDL_GetRenderer(SDL_Window *window)
  ##  ```
  chk_nil SDL_GetRenderer(window)

# int SDL_GetTextureAlphaMod(SDL_Texture *texture, Uint8 *alpha)
# int SDL_GetTextureBlendMode(SDL_Texture *texture, SDL_BlendMode *blendMode)
# int SDL_GetTextureColorMod(SDL_Texture *texture,
#     Uint8 *r, Uint8 *g, Uint8 *b)

proc GetTextureProperties*(texture: Texture): PropertiesID =
  ##  ```c
  ##  SDL_PropertiesID SDL_GetTextureProperties(SDL_Texture *texture)
  ##  ```
  chk_err_if result == PropertiesID 0: SDL_GetTextureProperties texture

# int SDL_GetTextureScaleMode(SDL_Texture *texture, SDL_ScaleMode *scaleMode)

proc LockTexture*(texture: Texture, pixels: var ptr UncheckedArray[byte],
                  pitch: var int) =
  ##  ```c
  ##  int SDL_LockTexture(SDL_Texture *texture, const SDL_Rect *rect,
  ##                      void **pixels, int *pitch)
  ##  ```
  var raw_pixels: pointer = nil
  var raw_pitch: cint = 0
  chk SDL_LockTexture(texture, nil, raw_pixels.addr, raw_pitch.addr)
  pixels  = cast[ptr UncheckedArray[byte]](raw_pixels)
  pitch   = raw_pitch

proc LockTexture*(texture: Texture, pixels: var ptr UncheckedArray[uint16],
                  pitch: var int) =
  ##  ```c
  ##  int SDL_LockTexture(SDL_Texture *texture, const SDL_Rect *rect,
  ##                      void **pixels, int *pitch)
  ##  ```
  var raw_pixels: pointer = nil
  var raw_pitch: cint = 0
  chk SDL_LockTexture(texture, nil, raw_pixels.addr, raw_pitch.addr)
  pixels  = cast[ptr UncheckedArray[uint16]](raw_pixels)
  pitch   = raw_pitch

proc LockTexture*(texture: Texture, pixels: var ptr UncheckedArray[uint32],
                  pitch: var int) =
  ##  ```c
  ##  int SDL_LockTexture(SDL_Texture *texture, const SDL_Rect *rect,
  ##                      void **pixels, int *pitch)
  ##  ```
  var raw_pixels: pointer = nil
  var raw_pitch: cint = 0
  chk SDL_LockTexture(texture, nil, raw_pixels.addr, raw_pitch.addr)
  pixels  = cast[ptr UncheckedArray[uint32]](raw_pixels)
  pitch   = raw_pitch

proc LockTexture*(texture: Texture, rect: Rect, pixels: var UncheckedArray[byte],
                  pitch: var int) =
  ##  ```c
  ##  int SDL_LockTexture(SDL_Texture *texture, const SDL_Rect *rect,
  ##                      void **pixels, int *pitch)
  ##  ```
  var raw_pitch: cint = 0
  chk SDL_LockTexture(texture, rect.addr, cast[ptr pointer](pixels.addr), raw_pitch.addr)
  pitch = raw_pitch

proc LockTextureToSurface*(texture: Texture, surface: var SurfacePtr) =
  ##  ```c
  ##  int SDL_LockTextureToSurface(SDL_Texture *texture, const SDL_Rect *rect,
  ##                               SDL_Surface **surface)
  ##  ```
  chk SDL_LockTextureToSurface(texture, nil, surface.addr)

proc LockTextureToSurface*(texture: Texture, rect: Rect,
                           surface: var SurfacePtr) =
  ##  ```c
  ##  int SDL_LockTextureToSurface(SDL_Texture *texture, const SDL_Rect *rect,
  ##                               SDL_Surface **surface)
  ##  ```
  chk SDL_LockTextureToSurface(texture, rect.addr, surface.addr)

#[
proc QueryTexture*(texture: Texture, format: var PixelFormatEnum,
                   access: var int, w: var int, h: var int) =
  ##  ```c
  ##  int SDL_QueryTexture(SDL_Texture *texture, Uint32 *format, int *access,
  ##                       int *w, int *h)
  ##  ```
  var outaccess, outw, outh: cint
  chk SDL_QueryTexture(texture, format.addr, outaccess.addr, outw.addr, outh.addr)
  access = outaccess
  w = outw
  h = outh
]#

proc RenderClear*(renderer: Renderer) =
  ##  ```c
  ##  int SDL_RenderClear(SDL_Renderer *renderer)
  ##  ```
  chk SDL_RenderClear(renderer)

# SDL_bool SDL_RenderClipEnabled(SDL_Renderer *renderer)

proc RenderCoordinatesFromWindow*(renderer: Renderer, window_x: float,
                                  window_y: float, x: var float,
                                  y: var float) =
  ##  Get a point in render coordinates when given a point in window coordinates.
  ##
  ##  ```c
  ##  int SDL_RenderCoordinatesFromWindow(SDL_Renderer *renderer,
  ##                                      float window_x, float window_y,
  ##                                      float *x, float *y)
  ##  ```
  var outx, outy: cfloat = 0
  chk SDL_RenderCoordinatesFromWindow(renderer, window_x.cfloat, window_y.cfloat, outx.addr, outy.addr)
  x = outx
  y = outy

# int SDL_RenderCoordinatesToWindow(SDL_Renderer *renderer, float x, float y,
#     float *window_x, float *window_y)

proc RenderFillRect*(renderer: Renderer) =
  ##  ```c
  ##  int SDL_RenderFillRect(SDL_Renderer *renderer, const SDL_FRect *rect)
  ##  ```
  chk SDL_RenderFillRect(renderer, nil)

proc RenderFillRect*(renderer: Renderer, rect: FRect) =
  chk SDL_RenderFillRect(renderer, rect.addr)

proc RenderFillRect*(renderer: Renderer, x: float, y: float, w: float, h: float) {.inline.} =
  RenderFillRect renderer, FRect.init(x, y, w, h)

proc RenderFillRect*(renderer: Renderer, x: int, y: int, w: int, h: int) {.inline.} =
  RenderFillRect renderer, FRect.init(x.float, y.float, w.float, h.float)

# int SDL_RenderFillRects(SDL_Renderer *renderer, const SDL_FRect *rects,
#     int count)

proc RenderGeometry*(renderer: Renderer, texture: Texture,
                     vertices: openArray[Vertex]) =
  ##  ```c
  ##  int SDL_RenderGeometry(SDL_Renderer *renderer, SDL_Texture *texture,
  ##                         const SDL_Vertex *vertices, int num_vertices,
  ##                         const int *indices, int num_indices)
  ##  ```
  chk SDL_RenderGeometry(renderer, texture, vertices[0].addr, vertices.len.cint, nil, 0)

proc RenderGeometry*(renderer: Renderer,
                     vertices: openArray[Vertex]) {.inline.} =
  ##  ```c
  ##  int SDL_RenderGeometry(SDL_Renderer *renderer, SDL_Texture *texture,
  ##                         const SDL_Vertex *vertices, int num_vertices,
  ##                         const int *indices, int num_indices)
  ##  ```
  RenderGeometry renderer, nil, vertices

proc RenderGeometry*(renderer: Renderer, texture: Texture,
                     vertices: openArray[Vertex],
                     indices: openArray[cint]) =
  ##  ```c
  ##  int SDL_RenderGeometry(SDL_Renderer *renderer, SDL_Texture *texture,
  ##                         const SDL_Vertex *vertices, int num_vertices,
  ##                         const int *indices, int num_indices)
  ##  ```
  chk SDL_RenderGeometry( renderer, texture,
                         vertices[0].addr, vertices.len.cint,
                         indices[0].addr, indices.len.cint )

proc RenderGeometry*(renderer: Renderer, vertices: openArray[Vertex],
                     indices: openArray[cint]) {.inline.} =
  ##  ```c
  ##  int SDL_RenderGeometry(SDL_Renderer *renderer, SDL_Texture *texture,
  ##                         const SDL_Vertex *vertices, int num_vertices,
  ##                         const int *indices, int num_indices)
  ##  ```
  RenderGeometry renderer, nil, vertices, indices

# int SDL_RenderGeometryRaw(SDL_Renderer *renderer, SDL_Texture *texture,
#     const float *xy, int xy_stride, const SDL_Color *color, int color_stride,
#     const float *uv, int uv_stride, int num_vertices, const void *indices,
#     int num_indices, int size_indices)

proc RenderLine*(renderer: Renderer, x1: float, y1: float,
                 x2: float, y2: float) =
  ##  ```c
  ##  int SDL_RenderLine(SDL_Renderer *renderer, float x1, float y1,
  ##                     float x2, float y2)
  ##  ```
  chk SDL_RenderLine(renderer, x1.cfloat, y1.cfloat, x2.cfloat, y2.cfloat)

# int SDL_RenderLines(SDL_Renderer *renderer, const SDL_FPoint *points,
#     int count)

proc RenderPoint*(renderer: Renderer, x: float, y: float) =
  ##  ```c
  ##  int SDL_RenderPoint(SDL_Renderer *renderer, float x, float y)
  ##  ```
  chk SDL_RenderPoint(renderer, x.cfloat, y.cfloat)

proc RenderPoint*(renderer: Renderer, x, y: int) {.inline.} =
  RenderPoint renderer, x.float, y.float

# int SDL_RenderPoints(SDL_Renderer *renderer, const SDL_FPoint *points,
#     int count)

proc RenderPresent*(renderer: Renderer) =
  ##  ```c
  ##  int SDL_RenderPresent(SDL_Renderer *renderer)
  ##  ```
  chk SDL_RenderPresent(renderer)

# int SDL_RenderReadPixels(SDL_Renderer *renderer, const SDL_Rect *rect,
#     Uint32 format, void *pixels, int pitch)

proc RenderRect*(renderer: Renderer, rect: FRect) =
  ##  ```c
  ##  int SDL_RenderRect(SDL_Renderer *renderer, const SDL_FRect *rect)
  ##  ```
  chk SDL_RenderRect(renderer, rect.addr)

proc RenderRect*(renderer: Renderer, x, y: float,
                  w, h: float) {.inline.} =
  ##  ```c
  ##  int SDL_RenderRect(SDL_Renderer *renderer, const SDL_FRect *rect)
  ##  ```
  RenderRect renderer, FRect.init(x, y, w, h)

# int SDL_RenderRects(SDL_Renderer *renderer, const SDL_FRect *rects,
#     int count)

proc RenderTexture*(renderer: Renderer, texture: Texture, srcrect: FRect, dstrect: FRect) =
  ##  ```c
  ##  int SDL_RenderTexture(SDL_Renderer *renderer, SDL_Texture *texture,
  ##                        const SDL_FRect *srcrect, const SDL_FRect *dstrect)
  ##  ```
  chk SDL_RenderTexture(renderer, texture, srcrect.addr, dstrect.addr)

proc RenderTexture*(renderer: Renderer, texture: Texture, dst: FRect) =
  chk SDL_RenderTexture(renderer, texture, nil, dst.addr)

proc RenderTexture*(renderer: Renderer, texture: Texture) =
  chk SDL_RenderTexture(renderer, texture, nil, nil)

proc RenderTexture*(renderer: Renderer, texture: Texture, x: int, y: int, w: int, h: int) =
  var dst = FRect(x: x.cfloat, y: y.cfloat, w: w.cfloat, h: h.cfloat)
  chk SDL_RenderTexture(renderer, texture, nil, dst.addr)

proc RenderTexture*(renderer: Renderer, texture: Texture,
    sx: int, sy: int, sw: int, sh: int, dx: int, dy: int, dw: int, dh: int) =
  var
    src = FRect(x: sx.cfloat, y: sy.cfloat, w: sw.cfloat, h: sh.cfloat)
    dst = FRect(x: dx.cfloat, y: dy.cfloat, w: dw.cfloat, h: dh.cfloat)
  chk SDL_RenderTexture(renderer, texture, src.addr, dst.addr)

proc RenderTextureRotated*(renderer: Renderer, texture: Texture,
                           srcrect: FRect, dstrect: FRect, angle: float,
                           center: FPoint, flip: FlipMode) =
  ##  See: `SDL_RenderTextureRotated`.
  chk SDL_RenderTextureRotated( renderer, texture,
    srcrect.addr, dstrect.addr, angle.cdouble, center.addr, flip )

proc SetRenderClipRect*(renderer: Renderer, rect: Rect) =
  ##  ```c
  ##  int SDL_SetRenderClipRect(SDL_Renderer *renderer, const SDL_Rect *rect)
  ##  ```
  chk SDL_SetRenderClipRect(renderer, rect.addr)

proc SetRenderDrawBlendMode*(renderer: Renderer, blend_mode: BlendMode) =
  ##  ```c
  ##  int SDL_SetRenderDrawBlendMode(SDL_Renderer *renderer,
  ##                                 SDL_BlendMode blendMode)
  ##  ```
  chk SDL_SetRenderDrawBlendMode(renderer, blend_mode)

proc SetRenderDrawColor*(renderer: Renderer, r: byte, g: byte, b: byte,
                         a: byte = 0xff) =
  ##  Set the color used for drawing operations (clear, line, rect, etc.).
  ##
  ##  ```c
  ##  int SDL_SetRenderDrawColor(SDL_Renderer *renderer, Uint8 r, Uint8 g,
  ##                             Uint8 b, Uint8 a)
  ##  ```
  chk SDL_SetRenderDrawColor(renderer, r, g, b, a)

proc SetRenderDrawColor*(renderer: Renderer, c: Color) {.inline.} =
  SetRenderDrawColor renderer, c.r, c.g, c.b, c.a

# int SDL_SetRenderLogicalPresentation(SDL_Renderer *renderer, int w, int h,
#     SDL_RendererLogicalPresentation mode, SDL_ScaleMode scale_mode)

proc SetRenderScale*(renderer: Renderer, scale_x: float,
                     scale_y: float) =
  ##  ```c
  ##  int SDL_SetRenderScale(SDL_Renderer *renderer,
  ##                         float scaleX, float scaleY)
  ##  ```
  chk SDL_SetRenderScale(renderer, scale_x.cfloat, scale_y.cfloat)

proc SetRenderTarget*(renderer: Renderer, texture: Texture = nil) =
  ##  ```c
  ##  int SDL_SetRenderTarget(SDL_Renderer *renderer, SDL_Texture *texture)
  ##  ```
  chk SDL_SetRenderTarget(renderer, texture)

proc SetRenderVSync*(renderer: Renderer, vsync: bool) =
  ##  ```c
  ##  int SDL_SetRenderVSync(SDL_Renderer *renderer, int vsync)
  ##  ```
  chk SDL_SetRenderVSync(renderer, vsync.cint)

# int SDL_SetRenderViewport(SDL_Renderer *renderer, const SDL_Rect *rect)

proc SetTextureAlphaMod*(texture: Texture, alpha: byte) =
  ##  ```c
  ##  int SDL_SetTextureAlphaMod(SDL_Texture *texture, Uint8 alpha)
  ##  ```
  chk SDL_SetTextureAlphaMod(texture, alpha)

proc SetTextureBlendMode*(texture: Texture, blend_mode: BlendMode) =
  ##  ```c
  ##  int SDL_SetTextureBlendMode(SDL_Texture *texture,
  ##                              SDL_BlendMode blendMode)
  ##  ```
  chk SDL_SetTextureBlendMode(texture, blend_mode)

proc SetTextureColorMod*(texture: Texture, r: byte, g: byte, b: byte) =
  ##  ```c
  ##  int SDL_SetTextureColorMod(SDL_Texture *texture,
  ##                             Uint8 r, Uint8 g, Uint8 b)
  ##  ```
  chk SDL_SetTextureColorMod(texture, r, g, b)

proc SetTextureScaleMode*(texture: Texture, scale_mode: ScaleMode) =
  ##  ```c
  ##  int SDL_SetTextureScaleMode(SDL_Texture *texture, SDL_ScaleMode scaleMode)
  ##  ```
  chk SDL_SetTextureScaleMode(texture, scale_mode)

proc UnlockTexture*(texture: Texture) =
  ##  ```c
  ##  void SDL_UnlockTexture(SDL_Texture *texture)
  ##  ```
  SDL_UnlockTexture texture

# int SDL_UpdateNVTexture(SDL_Texture *texture, const SDL_Rect *rect,
#     const Uint8 *Yplane, int Ypitch, const Uint8 *UVplane, int UVpitch)

proc UpdateTexture*(texture: Texture, rect: var Rect, pixels: pointer,
                    pitch: int) =
  ##  ```c
  ##  int SDL_UpdateTexture(SDL_Texture *texture, const SDL_Rect *rect,
  ##                        const void *pixels, int pitch)
  ##  ```
  chk SDL_UpdateTexture(texture, rect.addr, pixels, pitch.cint)

proc UpdateTexture*(texture: Texture, pixels: pointer, pitch: int) =
  ##  ```c
  ##  int SDL_UpdateTexture(SDL_Texture *texture, const SDL_Rect *rect,
  ##                        const void *pixels, int pitch)
  ##  ```
  chk SDL_UpdateTexture(texture, nil, pixels, pitch.cint)

# int SDL_UpdateYUVTexture(SDL_Texture *texture, const SDL_Rect *rect,
#     const Uint8 *Yplane, int Ypitch, const Uint8 *Uplane, int Upitch,
#     const Uint8 *Vplane, int Vpitch)

# --------------------------------------------------------------------------- #
# <SDL3/SDL_surface.h>                                                        #
# --------------------------------------------------------------------------- #

# int SDL_BlitSurface (SDL_Surface *src, const SDL_Rect *srcrect,
#     SDL_Surface *dst, SDL_Rect *dstrect)
# int SDL_BlitSurfaceScaled (SDL_Surface *src, const SDL_Rect *srcrect,
#     SDL_Surface *dst, SDL_Rect *dstrect, SDL_ScaleMode scaleMode)
# int SDL_BlitSurfaceUnchecked (SDL_Surface *src, const SDL_Rect *srcrect,
#     SDL_Surface *dst, const SDL_Rect *dstrect)
# int SDL_BlitSurfaceUncheckedScaled (SDL_Surface *src, const SDL_Rect *srcrect,
#     SDL_Surface *dst, const SDL_Rect *dstrect, SDL_ScaleMode scaleMode)
# int SDL_ConvertPixels(int width, int height, Uint32 src_format,
#     const void *src, int src_pitch, Uint32 dst_format, void *dst,
#     int dst_pitch)
# SDL_Surface *SDL_ConvertSurface(SDL_Surface *surface,
#     const SDL_PixelFormat *format)
# SDL_Surface *SDL_ConvertSurfaceFormat(SDL_Surface *surface, Uint32 pixel_format)
# SDL_Surface *SDL_CreateSurface (int width, int height, Uint32 format)

proc CreateSurfaceFrom*(width, height: int, format: PixelFormatEnum,
                        pixels: pointer, pitch: int): SurfacePtr =
  ##  ```c
  ##  SDL_Surface *SDL_CreateSurfaceFrom(void *pixels, int width, int height,
  ##                                    int pitch, Uint32 format)
  ##  ```
  chk_nil SDL_CreateSurfaceFrom(width.cint, height.cint, format, pixels, pitch.cint)

proc DestroySurface*(surface: SurfacePtr) {.inline.} =
  ##  ```c
  ##  void SDL_DestroySurface(SDL_Surface *surface)
  ##  ```
  SDL_DestroySurface surface

# SDL_Surface *SDL_DuplicateSurface(SDL_Surface *surface)
# int SDL_FillSurfaceRect (SDL_Surface *dst, const SDL_Rect *rect, Uint32 color)
# int SDL_FillSurfaceRects (SDL_Surface *dst, const SDL_Rect *rects,
#     int count, Uint32 color)
# extern DECLSPEC int SDLCALL SDL_FlipSurface(SDL_Surface *surface, SDL_FlipMode flip);
# int SDL_GetSurfaceAlphaMod(SDL_Surface *surface, Uint8 *alpha)
# int SDL_GetSurfaceBlendMode(SDL_Surface *surface, SDL_BlendMode *blendMode)
# int SDL_GetSurfaceClipRect(SDL_Surface *surface, SDL_Rect *rect)
# int SDL_GetSurfaceColorKey(SDL_Surface *surface, Uint32 *key)
# int SDL_GetSurfaceColorMod(SDL_Surface *surface, Uint8 *r, Uint8 *g, Uint8 *b)
# SDL_PropertiesID SDL_GetSurfaceProperties(SDL_Surface *surface)
# SDL_YUV_CONVERSION_MODE SDL_GetYUVConversionMode(void)
# SDL_YUV_CONVERSION_MODE SDL_GetYUVConversionModeForResolution(int width, int height)

proc LoadBMP*(file: string): SurfacePtr =
  ##  ```c
  ##  SDL_Surface *SDL_LoadBMP(const char *file)
  ##  ```
  chk_nil SDL_LoadBMP(file)

proc LockSurface*(surface: SurfacePtr) =
  ##  ```c
  ##  int SDL_LockSurface(SDL_Surface *surface)
  ##  ```
  chk SDL_LockSurface(surface)

# int SDL_PremultiplyAlpha(int width, int height, Uint32 src_format,
#     const void *src, int src_pitch, Uint32 dst_format, void *dst,
#     int dst_pitch)

# int SDL_ReadSurfacePixel(SDL_Surface *surface, int x, int y, Uint8 *r, Uint8 *g, Uint8 *b, Uint8 *a);

proc SaveBMP*(surface: SurfacePtr, file: string) =
  ##  ```c
  ##  int SDL_SaveBMP(SDL_Surface *surface, const char *file)
  ##  ```
  chk SDL_SaveBMP(surface, file.cstring)

# int SDL_SaveBMP_RW(SDL_Surface *surface, SDL_RWops *dst, SDL_bool freedst)
# int SDL_SetSurfaceAlphaMod(SDL_Surface *surface, Uint8 alpha)
# int SDL_SetSurfaceBlendMode(SDL_Surface *surface, SDL_BlendMode blendMode)
# SDL_bool SDL_SetSurfaceClipRect(SDL_Surface *surface, const SDL_Rect *rect)

proc SetSurfaceColorKey*(surface: SurfacePtr, flag: bool, key: uint32) =
  ##  ```c
  ##  int SDL_SetSurfaceColorKey(SDL_Surface *surface, int flag, Uint32 key)
  ##  ```
  chk SDL_SetSurfaceColorKey(surface, flag, key)

# int SDL_SetSurfaceColorMod(SDL_Surface *surface, Uint8 r, Uint8 g, Uint8 b)

proc SetSurfacePalette*(surface: SurfacePtr, palette: Palette) =
  chk SDL_SetSurfacePalette(surface, palette.addr)

proc SetSurfaceRLE*(surface: SurfacePtr, flag: bool) =
  ##  XXX.
  chk SDL_SetSurfaceRLE(surface, flag)

# void SDL_SetYUVConversionMode(SDL_YUV_CONVERSION_MODE mode)
# int SDL_SoftStretch(SDL_Surface *src, const SDL_Rect *srcrect,
#     SDL_Surface *dst, const SDL_Rect *dstrect, SDL_ScaleMode scaleMode)
# SDL_bool SDL_SurfaceHasColorKey(SDL_Surface *surface)
# SDL_bool SDL_SurfaceHasRLE(SDL_Surface *surface)

proc UnlockSurface*(surface: SurfacePtr) =
  ##  ```c
  ##  void SDL_UnlockSurface(SDL_Surface *surface)
  ##  ```
  SDL_UnlockSurface surface

proc WriteSurfacePixel*(surface: SurfacePtr, x: int, y: int,
                        r: byte, g: byte, b: byte, a: byte) =
  ##  ```c
  ##  int SDL_WriteSurfacePixel(SDL_Surface *surface, int x, int y,
  ##                            Uint8 r, Uint8 g, Uint8 b, Uint8 a)
  ##  ```
  chk SDL_WriteSurfacePixel(surface, x.cint, y.cint, r, g, b, a)

# --------------------------------------------------------------------------- #
# <SDL3/SDL_syswm.h>                                                          #
# --------------------------------------------------------------------------- #

# int SDL_GetWindowWMInfo(SDL_Window *window, SDL_SysWMinfo *info, Uint32 version)

# --------------------------------------------------------------------------- #
# <SDL3/SDL_timer.h>                                                          #
# --------------------------------------------------------------------------- #

proc AddTimer*(interval: uint32, callback: TimerCallback,
               param: pointer = nil): TimerID =
  ##  ```c
  ##  SDL_TimerID SDL_AddTimer(Uint32 interval, SDL_TimerCallback callback,
  ##                           void *param)
  ##  ```
  chk_err_if result.int == 0: SDL_AddTimer interval, callback, param

proc Delay*(ms: uint32) {.inline.} =
  ##  ```c
  ##  ```
  SDL_Delay ms

proc DelayNS*(ns: uint64) {.inline.} =
  ##  ```c
  ##  ```
  SDL_DelayNS ns

proc GetPerformanceCounter*(): uint64 {.inline.} =
  ##  ```c
  ##  Uint64 SDL_GetPerformanceCounter(void)
  ##  ```
  SDL_GetPerformanceCounter()

proc GetPerformanceFrequency*(): uint64 {.inline.} =
  ##  ```c
  ##  Uint64 SDL_GetPerformanceFrequency(void)
  ##  ```
  SDL_GetPerformanceFrequency()

proc GetTicks*(): uint64 {.inline.} =
  ##  Return the number of milliseconds since the SDL library initialization.
  ##
  ##  ```c
  ##  Uint64 SDL_GetTicks(void)
  ##  ```
  SDL_GetTicks()

proc GetTicksNS*(): uint64 {.inline.} =
  ##  ```c
  ##  Uint64 SDL_GetTicksNS(void)
  ##  ```
  SDL_GetTicks()

proc RemoveTimer*(id: TimerID): bool {.discardable, inline.} =
  ##  ```c
  ##  SDL_bool SDL_RemoveTimer(SDL_TimerID id)
  ##  ```
  SDL_RemoveTimer id

# --------------------------------------------------------------------------- #
# <SDL3/SDL_version.h>                                                        #
# --------------------------------------------------------------------------- #

proc GetRevision*(): string =
  ##  ```c
  ##  const char *SDL_GetRevision(void)
  ##  ```
  $SDL_GetRevision()

proc GetVersion*(): int =
  ##  ```c
  ##  int SDL_GetVersion()
  ##  ```
  SDL_GetVersion()

# --------------------------------------------------------------------------- #
# <SDL3/SDL_video.h>                                                          #
# --------------------------------------------------------------------------- #

proc CreatePopupWindow*(parent: Window, offset_x: int, offset_y: int,
                        w: int, h: int, flags: WindowFlags): Window =
  ##  Create a child popup window of the specified parent window.
  ##
  ##  ```c
  ##  SDL_Window *SDL_CreatePopupWindow(SDL_Window *parent, int offset_x,
  ##                                    int offset_y, int w, int h,
  ##                                    Uint32 flags)
  ##  ```
  chk_nil SDL_CreatePopupWindow(parent, offset_x.cint, offset_y.cint, w.cint, h.cint, flags)

proc CreateWindow*(title: string, w: int, h: int,
                   flags = WindowFlags 0): Window =
  ##  Create a window with the specified dimensions and flags.
  ##
  ##  ```c
  ##  SDL_Window *SDL_CreateWindow(const char *title, int w, int h,
  ##                               Uint32 flags)
  ##  ```
  chk_nil SDL_CreateWindow(title, w.cint, h.cint, flags)

proc CreateWindowWithProperties*(props: PropertiesID): Window =
  ##  Create a window with the specified properties.
  ##
  ##  `SDL_CreateWindowWithProperties`
  chk_nil SDL_CreateWindowWithProperties(props)

proc DestroyWindow*(window: Window) {.inline.} =
  ##  Destroy the window.
  ##
  ##  ```c
  ##  void SDL_DestroyWindow(SDL_Window *window)
  ##  ```
  SDL_DestroyWindow window

# int SDL_DestroyWindowSurface(SDL_Window *window)

proc DisableScreenSaver*() =
  ##  Prevent the screen from being blanked by a screen saver.
  ##
  ##  ```c
  ##  int SDL_DisableScreenSaver(void)
  ##  ```
  chk SDL_DisableScreenSaver()

# SDL_EGLConfig SDL_EGL_GetCurrentEGLConfig(void)
# SDL_EGLDisplay SDL_EGL_GetCurrentEGLDisplay(void)
# SDL_FunctionPointer SDL_EGL_GetProcAddress(const char *proc)
# SDL_EGLSurface SDL_EGL_GetWindowEGLSurface(SDL_Window *window)
# void SDL_EGL_SetEGLAttributeCallbacks(SDL_EGLAttribArrayCallback platformAttribCallback,
#     SDL_EGLIntArrayCallback surfaceAttribCallback, SDL_EGLIntArrayCallback contextAttribCallback)

proc EnableScreenSaver*() =
  ##  Allow the screen to be blanked by a screen saver.
  ##
  ##  ```c
  ##  int SDL_EnableScreenSaver(void)
  ##  ```
  chk SDL_EnableScreenSaver()

proc FlashWindow*(window: Window,
                  operation: FlashOperation) =
  ##  Request a window to demand attention from the user.
  ##
  ##  ```c
  ##  int SDL_FlashWindow(SDL_Window *window, SDL_FlashOperation operation)
  ##  ```
  chk SDL_FlashWindow(window, operation)

# SDL_GLContext SDL_GL_CreateContext(SDL_Window *window)
# int SDL_GL_DeleteContext(SDL_GLContext context)
# SDL_bool SDL_GL_ExtensionSupported(const char *extension)
# int SDL_GL_GetAttribute(SDL_GLattr attr, int *value)
# SDL_GLContext SDL_GL_GetCurrentContext(void)
# SDL_Window *SDL_GL_GetCurrentWindow(void)
# SDL_FunctionPointer SDL_GL_GetProcAddress(const char *proc)
# int SDL_GL_GetSwapInterval(int *interval)
# int SDL_GL_LoadLibrary(const char *path)
# int SDL_GL_MakeCurrent(SDL_Window *window, SDL_GLContext context)
# void SDL_GL_ResetAttributes(void)
# int SDL_GL_SetAttribute(SDL_GLattr attr, int value)
# int SDL_GL_SetSwapInterval(int interval)
# int SDL_GL_SwapWindow(SDL_Window *window)
# void SDL_GL_UnloadLibrary(void)

proc GetClosestFullscreenDisplayMode*(display_id: DisplayID, w: int, h: int,
                                      refresh_rate: float,
                                      include_high_density_modes: bool): ptr DisplayMode =
  ##  Get the closest match to the requested display mode.
  ##
  ##  ```c
  ##  const SDL_DisplayMode *
  ##  SDL_GetClosestFullscreenDisplayMode(SDL_DisplayID displayID,
  ##                                      int w, int h, float refresh_rate,
  ##                                      SDL_bool include_high_density_modes)
  ##  ```
  chk_nil SDL_GetClosestFullscreenDisplayMode( display_id,
    w.cint, h.cint, refresh_rate.cfloat, include_high_density_modes )

# XXX: do a copy instrad of returning ptr?
proc GetCurrentDisplayMode*(display_id: DisplayID): ptr DisplayMode =
  ##  Get information about the current display mode.
  ##
  ##  ```c
  ##  const SDL_DisplayMode *SDL_GetCurrentDisplayMode(SDL_DisplayID displayID)
  ##  ```
  chk_nil SDL_GetCurrentDisplayMode(display_id)

# SDL_DisplayOrientation SDL_GetCurrentDisplayOrientation(SDL_DisplayID displayID)

proc GetCurrentVideoDriver*(): string =
  ##  Get the name of the currently initialized video driver.
  ##
  ##  ```c
  ##  const char *SDL_GetCurrentVideoDriver(void)
  ##  ```
  let driver = SDL_GetCurrentVideoDriver()
  if driver.isNil: return ""
  $driver

# const SDL_DisplayMode *SDL_GetDesktopDisplayMode(SDL_DisplayID displayID)

proc GetDisplayBounds*(display_id: DisplayID, rect: var Rect) =
  ##  Get the desktop area represented by a display.
  ##
  ##  ```c
  ##  int SDL_GetDisplayBounds(SDL_DisplayID displayID, SDL_Rect *rect)
  ##  ```
  chk SDL_GetDisplayBounds(display_id, rect.addr)

proc GetDisplayBounds*(display_id: DisplayID, x: var int, y: var int,
                       width: var int, height: var int) =
  ##  Get the desktop area represented by a display.
  ##
  ##  ```c
  ##  int SDL_GetDisplayBounds(SDL_DisplayID displayID, SDL_Rect *rect)
  ##  ```
  var bounds = Rect(x: 0, y: 0, w: 0, h: 0)
  GetDisplayBounds(display_id, bounds)
  x       = bounds.x.int
  y       = bounds.y.int
  width   = bounds.w.int
  height  = bounds.h.int

proc GetDisplayContentScale*(display_id: DisplayID): float {.inline.} =
  ##  Get the content scale of a display.
  ##
  ##  ```c
  ##  float SDL_GetDisplayContentScale(SDL_DisplayID displayID)
  ##  ```
  # XXX: TODO: return 0.0f on error
  SDL_GetDisplayContentScale display_id

# SDL_DisplayID SDL_GetDisplayForPoint(const SDL_Point *point)
# SDL_DisplayID SDL_GetDisplayForRect(const SDL_Rect *rect)

proc GetDisplayForWindow*(window: Window): DisplayID =
  ##  Get the display associated with a window.
  ##
  ##  ```c
  ##  SDL_DisplayID SDL_GetDisplayForWindow(SDL_Window *window)
  ##  ```
  chk_err_if result.uint32 == 0: SDL_GetDisplayForWindow window

proc GetDisplayName*(display_id: DisplayID): string =
  ##  Get the name of a display in UTF-8 encoding.
  ##
  ##  ```c
  ##  const char *SDL_GetDisplayName(SDL_DisplayID displayID)
  ##  ```
  $SDL_GetDisplayName display_id

# SDL_PropertiesID SDL_GetDisplayProperties(SDL_DisplayID displayID)

# SDL_PropertiesID SDL_GetGlobalProperties(void)

proc GetDisplays*(): seq[DisplayID] =
  ##  Get a list of currently connected displays.
  ##
  ##  ```c
  ##  SDL_DisplayID *SDL_GetDisplays(int *count)
  ##  ```
  var count: cint = 0
  let display_list = SDL_GetDisplays(count.addr)
  if display_list.isNil: return @[]
  result = newSeqOfCap[DisplayID] count
  for i in 0 ..< count: result.add display_list[i]
  c_free display_list

proc GetDisplayUsableBounds*(display_id: DisplayID, rect: var Rect) =
  ##  Get the usable desktop area represented by a display, in screen
  ##  coordinates.
  ##
  ##  ```c
  ##  int SDL_GetDisplayUsableBounds(SDL_DisplayID displayID, SDL_Rect *rect)
  ##  ```
  chk SDL_GetDisplayUsableBounds(display_id, rect.addr)

# XXX: TODO: remove this, leave only Rect or add x and y?
proc GetDisplayUsableBounds*(display_id: DisplayID, width: var int, height: var int) =
  ##  Get the usable desktop area represented by a display, in screen
  ##  coordinates.
  ##
  ##  ```c
  ##  int SDL_GetDisplayUsableBounds(SDL_DisplayID displayID, SDL_Rect *rect)
  ##  ```
  var bounds = Rect(x: 0, y: 0, w: 0, h: 0)
  chk SDL_GetDisplayUsableBounds(display_id, bounds.addr)
  width   = bounds.w.int
  height  = bounds.h.int

# const SDL_DisplayMode **SDL_GetFullscreenDisplayModes(SDL_DisplayID displayID, int *count)

proc GetFullscreenDisplayModes*(display_id: DisplayID): seq[DisplayMode] =
  ##  Get a list of fullscreen display modes available on a display.
  ##
  ##  ```c
  ##  const SDL_DisplayMode **SDL_GetFullscreenDisplayModes(SDL_DisplayID displayID, int *count)
  ##  ```
  var count: cint = 0
  let mode_list = SDL_GetFullscreenDisplayModes(display_id, count.addr)
  if mode_list.isNil: return @[]
  result = newSeqOfCap[DisplayMode] count
  for i in 0 ..< count: result.add mode_list[i][]
  c_free mode_list

proc GetGrabbedWindow*(): Window =
  ##  Get the window that currently has an input grab enabled.
  ##
  ##  ```c
  ##  SDL_Window *SDL_GetGrabbedWindow(void)
  ##  ```
  SDL_GetGrabbedWindow()

# SDL_DisplayOrientation SDL_GetNaturalDisplayOrientation(SDL_DisplayID displayID)

proc GetNumVideoDrivers*(): int =
  ##  Get the number of video drivers compiled into SDL.
  ##
  ##  ```c
  ##  int SDL_GetNumVideoDrivers(void)
  ##  ```
  chk_err_if result <= 0: SDL_GetNumVideoDrivers()

proc GetPrimaryDisplay*(): DisplayID {.inline.} =
  ##  Return the primary display.
  ##
  ##  ```c
  ##  SDL_DisplayID SDL_GetPrimaryDisplay(void)
  ##  ```
  # XXX: check result?
  SDL_GetPrimaryDisplay()

# SDL_SystemTheme SDL_GetSystemTheme(void)
# const char *SDL_GetVideoDriver(int index)
# int SDL_GetWindowBordersSize(SDL_Window *window, int *top, int *left,
#     int *bottom, int *right)

# float SDL_GetWindowDisplayScale(SDL_Window *window)

proc GetWindowFlags*(window: Window): WindowFlags {.inline.} =
  ##  Get the window flags.
  ##
  ##  ```c
  ##  Uint32 SDL_GetWindowFlags(SDL_Window *window)
  ##  ```
  SDL_GetWindowFlags window

# int SDL_SetWindowFocusable(SDL_Window *window, SDL_bool focusable)

proc GetWindowFromID*(id: WindowID or uint32): Window {.inline.} =
  ##  Get a window from a stored ID.
  ##
  ##  ```c
  ##  SDL_Window *SDL_GetWindowFromID(SDL_WindowID id)
  ##  ```
  SDL_GetWindowFromID id.WindowID

proc GetWindowFullscreenMode*(window: Window = nil): ptr DisplayMode =
  ##  Query the display mode to use when a window is visible at fullscreen.
  ##
  ##  ```c
  ##  const SDL_DisplayMode *SDL_GetWindowFullscreenMode(SDL_Window *window)
  ##  ```
  chk_nil SDL_GetWindowFullscreenMode(window)

# void *SDL_GetWindowICCProfile(SDL_Window *window, size_t *size)

proc GetWindowID*(window: Window): WindowID {.inline.} =
  ##  Get the numeric ID of a window.
  ##
  ##  ```c
  ##  SDL_WindowID SDL_GetWindowID(SDL_Window *window)
  ##  ```
  chk_err_if result.int <= 0: SDL_GetWindowID window

proc GetWindowKeyboardGrab*(window: Window): bool {.discardable, inline.} =
  ##  Get a window's keyboard grab mode.
  ##
  ##  ```c
  ##  SDL_bool SDL_GetWindowKeyboardGrab(SDL_Window *window)
  ##  ```
  SDL_GetWindowKeyboardGrab window

proc GetWindowMaximumSize*(window: Window, w: var int, h: var int) =
  ##  Get the maximum size of a window's client area.
  ##
  ##  ```c
  ##  int SDL_GetWindowMaximumSize(SDL_Window *window, int *w, int *h)
  ##  ```
  var outw, outh: cint = 0
  chk SDL_GetWindowMaximumSize(window, outw.addr, outh.addr)
  w = outw
  h = outh

proc GetWindowMinimumSize*(window: Window, w: var int, h: var int) =
  ##  Get the minimum size of a window's client area.
  ##
  ##  ```c
  ##  int SDL_GetWindowMinimumSize(SDL_Window *window, int *w, int *h)
  ##  ```
  var outw, outh: cint = 0
  chk SDL_GetWindowMinimumSize(window, outw.addr, outh.addr)
  w = outw
  h = outh

proc GetWindowMouseGrab*(window: Window): bool =
  ##  Get a window's mouse grab mode.
  ##
  ##  ```c
  ##  SDL_bool SDL_GetWindowMouseGrab(SDL_Window *window)
  ##  ```
  SDL_GetWindowMouseGrab window

# const SDL_Rect *SDL_GetWindowMouseRect(SDL_Window *window)
# int SDL_GetWindowOpacity(SDL_Window *window, float *out_opacity)
# SDL_Window *SDL_GetWindowParent(SDL_Window *window)
# float SDL_GetWindowPixelDensity(SDL_Window *window)

proc GetWindowPixelFormat*(window: Window): PixelFormatEnum =
  ##  Get the pixel format associated with the window.
  ##
  ##  ```c
  ##  Uint32 SDL_GetWindowPixelFormat(SDL_Window *window)
  ##  ```
  SDL_GetWindowPixelFormat window

proc GetWindowPosition*(window: Window, x: var int, y: var int) =
  ##  Get the position of a window.
  ##
  ##  ```c
  ##  int SDL_GetWindowPosition(SDL_Window *window, int *x, int *y)
  ##  ```
  var outx, outy: cint = 0
  chk SDL_GetWindowPosition(window, outx.addr, outy.addr)
  x = outx
  y = outy

# SDL_PropertiesID SDL_GetWindowProperties(SDL_Window *window)

proc GetWindowSize*(window: Window, w, h: var int) =
  ##  Get the size of a window's client area.
  ##
  ##  ```c
  ##  int SDL_GetWindowSize(SDL_Window *window, int *w, int *h)
  ##  ```
  var outw, outh: cint = 0
  chk SDL_GetWindowSize(window, outw.addr, outh.addr)
  w = outw
  h = outh

# int SDL_GetWindowSizeInPixels(SDL_Window *window, int *w, int *h)
# SDL_Surface *SDL_GetWindowSurface(SDL_Window *window)
# const char *SDL_GetWindowTitle(SDL_Window *window)
# SDL_bool SDL_HasWindowSurface(SDL_Window *window)

proc HideWindow*(window: Window) =
  ##  Hide a window.
  ##
  ##  ```c
  ##  int SDL_HideWindow(SDL_Window *window)
  ##  ```
  chk SDL_HideWindow(window)

# int SDL_MaximizeWindow(SDL_Window *window)
# int SDL_MinimizeWindow(SDL_Window *window)

proc RaiseWindow*(window: Window) =
  ##  Raise a window above other windows and set the input focus.
  ##
  ##  ```c
  ##  int SDL_RaiseWindow(SDL_Window *window)
  ##  ```
  chk SDL_RaiseWindow(window)

# int SDL_RestoreWindow(SDL_Window *window)

proc ScreenSaverEnabled*(): bool {.inline.} =
  ##  Check whether the screensaver is currently enabled.
  ##
  ##  ```c
  ##  SDL_bool SDL_ScreenSaverEnabled(void)
  ##  ```
  SDL_ScreenSaverEnabled()

# int SDL_SetWindowAlwaysOnTop(SDL_Window *window, SDL_bool on_top)

proc SetWindowBordered*(window: Window, bordered: bool) =
  ##  Set the border state of a window.
  ##
  ##  ```c
  ##  int SDL_SetWindowBordered(SDL_Window *window, SDL_bool bordered)
  ##  ```
  chk SDL_SetWindowBordered(window, bordered)

# int SDL_SetWindowFocusable(SDL_Window *window, SDL_bool focusable)

proc SetWindowFullscreen*(window: Window, fullscreen: bool) =
  ##  Set a window's fullscreen state.
  ##
  ##  ```c
  ##  int SDL_SetWindowFullscreen(SDL_Window *window, SDL_bool fullscreen)
  ##  ```
  chk SDL_SetWindowFullscreen(window, fullscreen)

proc SetWindowFullscreenMode*(window: Window, mode: ptr DisplayMode) =
  ##  Set the display mode to use when a window is visible and fullscreen.
  ##
  ##  ```c
  ##  int SDL_SetWindowFullscreenMode(SDL_Window *window,
  ##                                  const SDL_DisplayMode *mode)
  ##  ```
  chk SDL_SetWindowFullscreenMode(window, mode)

# int SDL_SetWindowHitTest(SDL_Window *window, SDL_HitTest callback,
#     void *callback_data)

proc SetWindowIcon*(window: Window, surface: SurfacePtr) =
  ##  Set the icon for a window.
  ##
  ##  ```c
  ##  int SDL_SetWindowIcon(SDL_Window *window, SDL_Surface *icon)
  ##  ```
  chk SDL_SetWindowIcon(window, surface)

# int SDL_SetWindowInputFocus(SDL_Window *window)

proc SetWindowKeyboardGrab*(window: Window, grabbed: bool) =
  ##  Set a window's keyboard grab mode.
  ##
  ##  ```c
  ##  int SDL_SetWindowKeyboardGrab(SDL_Window *window, SDL_bool grabbed)
  ##  ```
  chk SDL_SetWindowKeyboardGrab(window, grabbed)

proc SetWindowMaximumSize*(window: Window, min_w: int, min_h: int) =
  ##  Set the maximum size of a window's client area.
  ##
  ##  ```c
  ##  int SDL_SetWindowMaximumSize(SDL_Window *window, int max_w, int max_h)
  ##  ```
  chk SDL_SetWindowMaximumSize(window, min_w.cint, min_h.cint)

proc SetWindowMinimumSize*(window: Window, min_w: int, min_h: int) =
  ##  Set the minimum size of a window's client area.
  ##
  ##  ```c
  ##  int SDL_SetWindowMinimumSize(SDL_Window *window, int min_w, int min_h)
  ##  ```
  chk SDL_SetWindowMinimumSize(window, min_w.cint, min_h.cint)

# int SDL_SetWindowModalFor(SDL_Window *modal_window, SDL_Window *parent_window)

proc SetWindowMouseGrab*(window: Window, grabbed: bool) {.discardable.} =
  ##  Set a window's mouse grab mode.
  ##
  ##  ```c
  ##  int SDL_SetWindowMouseGrab(SDL_Window *window, SDL_bool grabbed)
  ##  ```
  chk SDL_SetWindowMouseGrab(window, grabbed)

# int SDL_SetWindowMouseRect(SDL_Window *window, const SDL_Rect *rect)
# int SDL_SetWindowOpacity(SDL_Window *window, float opacity)

proc SetWindowPosition*(window: Window, x: int, y: int) =
  ##  Set the position of a window.
  ##
  ##  .. note::
  ##    Centering the window after returning from full screen moves
  ##    the window to primary display.
  ##    XXX: TODO: this note comes from SDL2, check this behavior in SDL3.
  ##
  ##  ```c
  ##  int SDL_SetWindowPosition(SDL_Window *window, int x, int y)
  ##  ```
  chk SDL_SetWindowPosition(window, x.cint, y.cint)

proc SetWindowResizable*(window: Window, ontop: bool) =
  ##  Set the user-resizable state of a window.
  ##
  ##  ```c
  ##  int SDL_SetWindowResizable(SDL_Window *window, SDL_bool resizable)
  ##  ```
  chk SDL_SetWindowResizable(window, ontop)

proc SetWindowSize*(window: Window, x: int, y: int) =
  ##  Set the size of a window's client area.
  ##
  ##  ```c
  ##  int SDL_SetWindowSize(SDL_Window *window, int w, int h)
  ##  ```
  chk SDL_SetWindowSize(window, x.cint, y.cint)

proc SetWindowTitle*(window: Window, title: string) =
  ##  Set the title of a window.
  ##
  ##  ```c
  ##  int SDL_SetWindowTitle(SDL_Window *window, const char *title)
  ##  ```
  chk SDL_SetWindowTitle(window, title)

proc ShowWindow*(window: Window) =
  ##  Show a window.
  ##
  ##  ```c
  ##  int SDL_ShowWindow(SDL_Window *window)
  ##  ```
  chk SDL_ShowWindow(window)

# int SDL_ShowWindowSystemMenu(SDL_Window *window, int x, int y)
# int SDL_SyncWindow(SDL_Window *window)

proc UpdateWindowSurface*(window: Window) =
  ##  Copy the window surface to the screen.
  ##
  ##  ```c
  ##  int SDL_UpdateWindowSurface(SDL_Window *window)
  ##  ```
  chk SDL_UpdateWindowSurface(window)

# int SDL_UpdateWindowSurfaceRects(SDL_Window *window, const SDL_Rect *rects,
#     int numrects)

# XXX
# proc get_display_index*(window: Window): int {.deprecated: "use get_display_for_window instead".}

# =========================================================================== #
# ==  C macros                                                             == #
# =========================================================================== #

# --------------------------------------------------------------------------- #
# <SDL/SDL_quit.h>                                                            #
# --------------------------------------------------------------------------- #

proc QuitRequested*(): bool {.inline.} =
  ##  ```c
  ##  #define SDL_QuitRequested() \
  ##      SDL_PumpEvents(), \
  ##      (SDL_PeepEvents(NULL, 0, SDL_PEEKEVENT, SDL_EVENT_QUIT, \
  ##                      SDL_EVENT_QUIT) > 0))
  ##  ```
  PumpEvents()
  PeepEvents(EVENT_QUIT, EVENT_QUIT) > 0

# ------------------------------------------------------------------------- #
# <SDL3/SDL_ttf.h>                                                          #
# ------------------------------------------------------------------------- #

proc XTTFInit*() =
  ##  ```c
  ##  bool TTF_Init(void);
  ##  ```
  chk TTF_Init()

proc XTTFQuit*() =
  ##  ```c
  ##  void TTF_Quit(void);
  ##  ```
  TTF_Quit()

proc OpenFont*(file: string, ptsize: float): Font =
  ##  ```c
  ##  TTF_Font * TTF_OpenFont(const char *file, float ptsize);
  ##  ```
  chk_nil TTF_OpenFont(file.cstring, ptsize.cfloat)

proc CloseFont*(font: Font) =
  ##  ```c
  ##  void TTF_CloseFont(TTF_Font *font);
  ##  ```
  TTF_CloseFont font

proc GetFontStyle*(font: Font): FontStyleFlags =
  ##  ```c
  ##  TTF_FontStyleFlags TTF_GetFontStyle(const TTF_Font *font);
  ##  ```
  TTF_GetFontStyle font

proc SetFontStyle*(font: Font, style: FontStyleFlags) =
  ##  ```c
  ##  void TTF_SetFontStyle(TTF_Font *font, TTF_FontStyleFlags style);
  ##  ```
  TTF_SetFontStyle font, style

proc GetFontOutline*(font: Font): int =
  ##  ```c
  ##  int TTF_GetFontOutline(const TTF_Font *font);
  ##  ```
  TTF_GetFontOutline font

proc SetFontOutline*(font: Font, outline: int) =
  ##  ```c
  ##  bool TTF_SetFontOutline(TTF_Font *font, int outline);
  ##  ```
  chk TTF_SetFontOutline(font, outline.cint)

proc GetFontHinting*(font: Font): HintingFlags =
  ##  ```c
  ##  TTF_HintingFlags TTF_GetFontHinting(const TTF_Font *font);
  ##  ```
  TTF_GetFontHinting font

proc SetFontHinting*(font: Font, hinting: HintingFlags) =
  ##  ```c
  ##  void TTF_SetFontHinting(TTF_Font *font, TTF_HintingFlags hinting);
  ##  ```
  TTF_SetFontHinting font, hinting

proc GetFontHeight*(font: Font): int =
  ##  ```c
  ##  void TTF_SetFontHinting(TTF_Font *font, TTF_HintingFlags hinting);
  ##  ```
  TTF_GetFontHeight font

proc GetStringSize*(font: Font, text: string): (int, int) =
  ##  ```c
  ##  bool TTF_GetStringSize(TTF_Font *font, const char *text, size_t length, int *w, int *h);
  ##  ```
  var w, h: cint
  chk TTF_GetStringSize(font, text.cstring, text.len.csize_t, w.addr, h.addr)
  return (w.int, h.int)

proc RenderText_Blended*(font: Font, text: string, fg: Color): SurfacePtr =
  ##  ```c
  ##  SDL_Surface * TTF_RenderText_Blended(TTF_Font *font, const char *text, size_t length, SDL_Color fg);
  ##  ```
  chk_nil TTF_RenderText_Blended(font, text.cstring, text.len.csize_t, fg)

proc CreateRendererTextEngine*(renderer: Renderer): TextEngine =
  ##  ```c
  ##  TTF_TextEngine * TTF_CreateRendererTextEngine(SDL_Renderer *renderer);
  ##  ```
  chk_nil TTF_CreateRendererTextEngine renderer

proc DestroyRendererTextEngine*(engine: TextEngine) =
  ##  ```c
  ##  void TTF_DestroyRendererTextEngine(TTF_TextEngine *engine);
  ##  ```
  TTF_DestroyRendererTextEngine engine

proc CreateText*(engine: TextEngine, font: Font, text: string, length: int): Text =
  ##  ```c
  ##  TTF_Text * TTF_CreateText(TTF_TextEngine *engine, TTF_Font *font, const char *text, size_t length);
  ##  ```
  chk_nil TTF_CreateText(engine, font, text.cstring, length.csize_t)

proc DestroyText*(text: Text) =
  ##  ```c
  ##  void TTF_DestroyText(TTF_Text *text);
  ##  ```
  TTF_DestroyText text

proc SetTextString*(text: Text, s: string) =
  ##  ```c
  ##  bool TTF_SetTextString(TTF_Text *text, const char *string, size_t length);
  ##  ```
  chk TTF_SetTextString(text, s.cstring, s.len.csize_t)

proc SetTextColor*(text: Text, r: byte, g: byte, b: byte, a: byte) =
  ##  ```c
  ##  bool TTF_SetTextColor(TTF_Text *text, Uint8 r, Uint8 g, Uint8 b, Uint8 a);
  ##  ```
  chk TTF_SetTextColor(text, r, g, b, a)

proc SetTextColor*(text: Text, c: Color) =
  SetTextColor text, c.r, c.g, c.b, c.a

proc DrawRendererText*(text: Text, x: float, y: float) =
  ##  ```c
  ##  bool TTF_DrawRendererText(TTF_Text *text, float x, float y);
  ##  ```
  chk TTF_DrawRendererText(text, x.cfloat, y.cfloat)

proc DrawRendererText*(text: Text, x: int, y: int) {.inline.} =
  DrawRendererText text, x.cfloat, y.cfloat

# =========================================================================== #
# ==  Helper functions                                                     == #
# =========================================================================== #

proc GetVersionString*(): string =
  let ver = GetVersion()
  let major = ver div 1000_000
  let minor = ver div 1000 mod 1000
  let patch = ver mod 1000
  $major & '.' & $minor & '.' & $patch

proc sdl3_avail*(flags = INIT_VIDEO): bool =
  Init flags

# vim: set sts=2 et sw=2:
