##  SDL3 ABI functions.
##
#[
  SPDX-License-Identifier: NCSA OR MIT OR Zlib
]#

{.push raises: [].}

import dlutils

import sdl3inc/sdl3blendmode
import sdl3inc/sdl3events
import sdl3inc/sdl3hints
import sdl3inc/sdl3init
import sdl3inc/sdl3log
import sdl3inc/sdl3pixels
import sdl3inc/sdl3properties
import sdl3inc/sdl3rect
import sdl3inc/sdl3render
import sdl3inc/sdl3surface
import sdl3inc/sdl3timer
import sdl3inc/sdl3ttf
import sdl3inc/sdl3video

when defined macosx:
  const lib_paths = ["libSDL3.dylib"]
  const lib_paths_ttf = ["libSDL3_ttf.dylib"]
when defined posix:
  const lib_paths = ["libSDL3.so", "libSDL3.so.0"]
  const lib_paths_ttf = ["libSDL3_ttf.so", "libSDL3.so.0"]
elif defined windows:
  const lib_paths = ["SDL3.dll"]
  const lib_paths_ttf = ["SDL3_ttf.dll"]
else:
  {.fatal: "unsupported platform.".}

{.push hint[GlobalVar]: off.}


# =========================================================================== #
# ==  SDL3 library object                                                  == #
# =========================================================================== #

dlgencalls "sdl3", lib_paths:

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_blendmode.h>                                                    #
  # ------------------------------------------------------------------------- #

  proc SDL_ComposeCustomBlendMode(
    src_color_factor  : BlendFactor,
    dst_color_factor  : BlendFactor,
    color_operation   : BlendOperation,
    src_alpha_factor  : BlendFactor,
    dst_alpha_factor  : BlendFactor,
    alpha_operation   : BlendOperation
  ): BlendMode

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_error.h>                                                        #
  # ------------------------------------------------------------------------- #

  proc SDL_ClearError(): cbool

  # int SDL_Error(SDL_errorcode code)   XXX: ???

  proc SDL_GetError(): cstring

  # bool SDL_OutOfMemory(void)
  # bool SDL_SetError(const char *fmt, ...)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_events.h>                                                       #
  # ------------------------------------------------------------------------- #

  # bool SDL_AddEventWatch(SDL_EventFilter filter, void *userdata)
  # void *SDL_AllocateEventMemory(size_t size)
  # void SDL_DelEventWatch(SDL_EventFilter filter, void *userdata)
  # bool SDL_EventEnabled(Uint32 type)

  proc SDL_FilterEvents(filter    : EventFilter,
                        userdata  : pointer)

  proc SDL_FlushEvent(typ: EventType)

  proc SDL_FlushEvents(min_type : EventType,
                       max_type : EventType)

  # bool SDL_GetEventFilter(SDL_EventFilter *filter, void **userdata)
  # SDL_Window * SDL_GetWindowFromEvent(const SDL_Event *event)
  # bool SDL_HasEvent(Uint32 type)
  # bool SDL_HasEvents(Uint32 minType, Uint32 maxType)

  proc SDL_PeepEvents(event     : ptr Event,
                      numevents : cint,
                      action    : EventAction,
                      min_type  : EventType,
                      max_type  : EventType): cint

  proc SDL_PollEvent(event: ptr Event): cbool

  proc SDL_PumpEvents()

  proc SDL_PushEvent(event: ptr Event): cbool

  # Uint32 SDL_RegisterEvents(int numevents)

  # void SDL_RemoveEventWatch(SDL_EventFilter filter, void *userdata)

  proc SDL_SetEventEnabled(typ: uint32, enabled: cbool)

  # void SDL_SetEventFilter(SDL_EventFilter filter, void *userdata)

  proc SDL_WaitEvent(event: ptr Event): cbool

  proc SDL_WaitEventTimeout(event: ptr Event, timeout_ms: int32): cbool

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_hints.h>                                                        #
  # ------------------------------------------------------------------------- #

  # bool SDL_AddHintCallback(const char *name, SDL_HintCallback callback,
  #     void *userdata)
  # void SDL_ClearHints(void)
  # void SDL_DelHintCallback(const char *name, SDL_HintCallback callback,
  #     void *userdata)

  proc SDL_GetHint(name: HintName): cstring

  # bool SDL_GetHintBoolean(const char *name, bool default_value)
  # void SDLCALL SDL_RemoveHintCallback(const char *name, SDL_HintCallback callback, void *userdata)
  # bool SDL_ResetHint(const char *name)
  # bool SDL_ResetHints(void)

  proc SDL_SetHint(name: cstring, value: cstring): cbool

  # bool SDL_SetHintWithPriority(const char *name, const char *value,
  #     proc SDL_HintPriority priority)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_init.h>                                                         #
  # ------------------------------------------------------------------------- #

  proc SDL_GetAppMetadataProperty(name: AppMetadataProperty): cstring

  proc SDL_Init(flags: InitFlags): cbool

  proc SDL_InitSubSystem(flags: InitFlags): cbool

  proc SDL_Quit()

  proc SDL_QuitSubSystem(flags: InitFlags)

  proc SDL_SetAppMetadata(appname, appversion, appidentifier: cstring): cbool

  proc SDL_SetAppMetadataProperty(name: AppMetadataProperty, value: cstring): cbool

  proc SDL_WasInit(flags: InitFlags): InitFlags

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_log.h>                                                          #
  # ------------------------------------------------------------------------- #

  # SDL_Log, SDL_LogCritical, SDL_LogDebug, SDL_LogError, SDL_LogInfo,
  # SDL_LogVerbose and SDL_LogWarn are emulated by calling SDL_LogMessage.

  # SDL_DECLSPEC SDL_LogOutputFunction SDLCALL SDL_GetDefaultLogOutputFunction(void)
  # void SDL_LogGetOutputFunction(SDL_LogOutputFunction *callback,
  #                               void **userdata)
  # SDL_LogPriority SDL_GetLogPriority(int category)

  proc SDL_LogMessage(category: LogCategory, priority: LogPriority,
                      fmt: cstring) {.varargs.}

  # void SDL_LogMessageV(int category, SDL_LogPriority priority,
  #                      const char *fmt, va_list ap)
  # void SDL_LogTrace(int category, const char *fmt, ...) SDL_PRINTF_VARARG_FUNC(2)
  # void SDL_ResetLogPriorities(void)

  proc SDL_SetLogOutputFunction(callback: LogOutputFunction, userdata: pointer)

  # void SDL_SetLogPriorities(SDL_LogPriority priority)

  proc SDL_SetLogPriority(category: LogCategory, priority: LogPriority)

  # bool SDL_SetLogPriorityPrefix(SDL_LogPriority priority, const char *prefix)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_pen.h>                                                          #
  # ------------------------------------------------------------------------- #

  # Uint32 SDL_GetPenCapabilities(SDL_PenID instance_id, SDL_PenCapabilityInfo *capabilities)
  # SDL_PenID SDL_GetPenFromGUID(SDL_GUID guid)
  # SDL_GUID SDL_GetPenGUID(SDL_PenID instance_id)
  # const char * SDL_GetPenName(SDL_PenID instance_id)
  # SDL_PenID * SDL_GetPens(int *count)
  # Uint32 SDL_GetPenStatus(SDL_PenID instance_id, float *x, float *y, float *axes, size_t num_axes)
  # SDL_PenSubtype SDL_GetPenType(SDL_PenID instance_id)
  # SDL_bool SDL_PenConnected(SDL_PenID instance_id)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_pixels.h>                                                       #
  # ------------------------------------------------------------------------- #

  proc SDL_CreatePalette(ncolors: cint): ptr Palette

  # SDL_PixelFormat *SDL_CreatePixelFormat(SDL_PixelFormatEnum pixel_format)

  proc SDL_DestroyPalette(palette: ptr Palette)

  # bool SDL_GetMasksForPixelFormatEnum(SDL_PixelFormatEnum format, int *bpp,
  #     Uint32 *Rmask, Uint32 *Gmask, Uint32 *Bmask, Uint32 *Amask)

  proc SDL_GetPixelFormatDetails(format: PixelFormatEnum): PixelFormatDetailsPtr

  proc SDL_GetPixelFormatForMasks(
    bpp     : cint,
    rmask   : uint32,
    gmask   : uint32,
    bmask   : uint32,
    amask   : uint32
  ): PixelFormatEnum

  proc SDL_GetPixelFormatName(format: PixelFormatEnum): cstring

  # const char* SDL_GetPixelFormatName(SDL_PixelFormatEnum format)
  # void SDL_GetRGB(Uint32 pixel, const SDL_PixelFormatDetails *format,
  #     const SDL_Palette *palette, Uint8 *r, Uint8 *g, Uint8 *b)
  # void SDL_GetRGBA(Uint32 pixel, const SDL_PixelFormatDetails *format,
  #     const SDL_Palette *palette, Uint8 *r, Uint8 *g, Uint8 *b, Uint8 *a)

  proc SDL_MapRGB(
    format  : ptr PixelFormatDetails,
    palette : ptr Palette,
    r       : byte,
    g       : byte,
    b       : byte
  ): uint32

  proc SDL_MapRGBA(
    format  : ptr PixelFormatDetails,
    palette : ptr Palette,
    r       : byte,
    g       : byte,
    b       : byte,
    a       : byte
  ): uint32

  proc SDL_SetPaletteColors(
    palette     : ptr Palette,
    colors      : ptr Color,
    firstcolor  : cint,
    ncolors     : cint
  ): cbool

  # int SDL_SetPixelFormatPalette(SDL_PixelFormat *format,
  #     proc SDL_Palette *palette)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_properties.h>                                                   #
  # ------------------------------------------------------------------------- #

  # bool SDL_CopyProperties(SDL_PropertiesID src, SDL_PropertiesID dst)

  proc SDL_CreateProperties(): PropertiesID

  proc SDL_DestroyProperties(props: PropertiesID)

  proc SDL_EnumerateProperties(
    props     : PropertiesID,
    callback  : EnumeratePropertiesCallback,
    userdata  : pointer
  ): cbool

  proc SDL_SetBooleanProperty(
    props     : PropertiesID,
    name      : cstring,
    value     : cbool
  ): cbool

  proc SDL_SetFloatProperty(
    props     : PropertiesID,
    name      : cstring,
    value     : cfloat
  ): cbool

  proc SDL_SetNumberProperty(
    props     : PropertiesID,
    name      : cstring,
    value     : int64
  ): cbool

  # int SDL_ClearProperty(SDL_PropertiesID props, const char *name)
  # SDL_bool SDL_GetBooleanProperty(SDL_PropertiesID props, const char *name, SDL_bool default_value)
  # float SDL_GetFloatProperty(SDL_PropertiesID props, const char *name, float default_value)
  # SDL_PropertiesID SDL_GetGlobalProperties(void)
  # Sint64 SDL_GetNumberProperty(SDL_PropertiesID props, const char *name, Sint64 default_value)
  # void * SDL_GetPointerProperty(SDL_PropertiesID props, const char *name, void *default_value)
  # SDL_PropertyType SDL_GetPropertyType(SDL_PropertiesID props, const char *name)
  # const char * SDL_GetStringProperty(SDL_PropertiesID props, const char *name, const char *default_value)
  # SDL_bool SDL_HasProperty(SDL_PropertiesID props, const char *name);
  # int SDL_LockProperties(SDL_PropertiesID props)
  # int SDL_SetBooleanProperty(SDL_PropertiesID props, const char *name, SDL_bool value)
  # int SDL_SetPointerProperty(SDL_PropertiesID props, const char *name, void *value)
  # int SDL_SetProperty(SDL_PropertiesID props, const char *name, void *value)
  # int SDL_SetPropertyWithCleanup(SDL_PropertiesID props, const char *name,
  #     void *value, SDL_CleanupPropertyCallback cleanup,
  #     void *userdata)

  proc SDL_SetStringProperty(props: PropertiesID, name: cstring,
                             value: cstring): cint

  # void SDL_UnlockProperties(SDL_PropertiesID props)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_rect.h>                                                         #
  # ------------------------------------------------------------------------- #

  # bool SDL_GetRectAndLineIntersection(const SDL_Rect *rect,
  #     int *X1, int *Y1, int *X2, int *Y2)
  # bool SDL_GetRectAndLineIntersectionFloat(const SDL_FRect *rect,
  #     float *X1, float *Y1, float *X2, float *Y2)
  # bool SDL_GetRectEnclosingPoints(const SDL_Point *points, int count,
  #     const SDL_Rect *clip, SDL_Rect *result)
  # bool SDL_GetRectEnclosingPointsFloat(const SDL_FPoint *points,
  #     int count, const SDL_FRect *clip, SDL_FRect *result)
  # bool SDL_GetRectIntersection(const SDL_Rect *A, const SDL_Rect *B,
  #     proc SDL_Rect *result)
  # bool SDL_GetRectIntersectionFloat(const SDL_FRect *A,
  #     const SDL_FRect *B, SDL_FRect *result)
  # bool SDL_GetRectUnion(const SDL_Rect *A, const SDL_Rect *B,
  #     proc SDL_Rect *result)
  # bool SDL_GetRectUnionFloat(const SDL_FRect *A, const SDL_FRect *B,
  #     proc SDL_FRect *result)
  # bool SDL_HasRectIntersection(const SDL_Rect *A, const SDL_Rect *B)
  # bool SDL_HasRectIntersectionFloat(const SDL_FRect *A,
  #     const SDL_FRect *B)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_render.h>                                                       #
  # ------------------------------------------------------------------------- #

  # int SDL_AddVulkanRenderSemaphores(SDL_Renderer *renderer,
  #     Uint32 wait_stage_mask, Sint64 wait_semaphore, Sint64 signal_semaphore);

  # int SDL_ConvertEventToRenderCoordinates(SDL_Renderer *renderer,
  #     proc SDL_Event *event)

  proc SDL_CreateRenderer(
    window    : Window,
    name      : cstring
  ): Renderer

  proc SDL_CreateRendererWithProperties(props: PropertiesID): Renderer

  # SDL_Renderer *SDL_CreateSoftwareRenderer(SDL_Surface *surface)

  proc SDL_CreateTexture(
    renderer  : Renderer,
    format    : PixelFormatEnum,
    access    : TextureAccess,
    w         : cint,
    h         : cint
  ): Texture

  proc SDL_CreateTextureFromSurface(
    renderer  : Renderer,
    surface   : SurfacePtr
  ): Texture

  proc SDL_CreateTextureWithProperties(
    renderer  : Renderer,
    props     : PropertiesID
  ): Texture

  proc SDL_CreateWindowAndRenderer(
    title         : cstring,
    width         : cint,
    height        : cint,
    window_flags  : WindowFlags,
    window        : ptr Window,
    renderer      : ptr Renderer
  ): cbool

  proc SDL_DestroyRenderer(renderer: Renderer)

  proc SDL_DestroyTexture(text: Texture)

  # int SDL_GL_BindTexture(SDL_Texture *texture, float *texw, float *texh)
  # int SDL_GL_UnbindTexture(SDL_Texture *texture)
  # bool SDL_GetCurrentRenderOutputSize(SDL_Renderer *renderer,
  #     int *w, int *h)
  # int SDL_GetNumRenderDrivers(void)
  # int SDL_GetRenderClipRect(SDL_Renderer *renderer, SDL_Rect *rect)
  # int SDL_GetRenderColorScale(SDL_Renderer *renderer, float *scale);
  # int SDL_GetRenderDrawBlendMode(SDL_Renderer *renderer,
  #     proc SDL_BlendMode *blendMode)
  # int SDL_GetRenderDrawColor(SDL_Renderer *renderer,
  #     Uint8 *r, Uint8 *g, Uint8 *b, Uint8 *a)
  # int SDL_GetRenderDrawColorFloat(SDL_Renderer *renderer, float *r, float *g, float *b, float *a);
  # const char *SDL_GetRenderDriver(int index)
  # SDL_Renderer * SDL_GetRendererFromTexture(SDL_Texture *texture);
  # int SDL_GetRenderLogicalPresentation(SDL_Renderer *renderer,
  #     int *w, int *h, SDL_RendererLogicalPresentation *mode)
  # int SDL_GetRenderLogicalPresentationRect(SDL_Renderer *renderer, SDL_FRect *rect)
  # void *SDL_GetRenderMetalCommandEncoder(SDL_Renderer *renderer)
  # void *SDL_GetRenderMetalLayer(SDL_Renderer *renderer)
  # bool SDL_GetRenderOutputSize(SDL_Renderer *renderer, int *w, int *h)
  # SDL_PropertiesID SDL_GetRendererProperties(SDL_Renderer *renderer)
  # int SDL_GetRenderSafeArea(SDL_Renderer *renderer, SDL_Rect *rect)
  # int SDL_GetRenderScale(SDL_Renderer *renderer,
  #     float *scaleX, float *scaleY)
  # SDL_Texture *SDL_GetRenderTarget(SDL_Renderer *renderer)
  # int SDL_GetRenderVSync(SDL_Renderer *renderer, int *vsync)
  # int SDL_GetRenderViewport(SDL_Renderer *renderer, SDL_Rect *rect)
  # SDL_Window *SDL_GetRenderWindow(SDL_Renderer *renderer)

  proc SDL_GetRenderer(window: Window): Renderer

  # const char * SDL_GetRendererName(SDL_Renderer *renderer)
  # int SDL_GetTextureAlphaMod(SDL_Texture *texture, Uint8 *alpha)
  # int SDL_GetTextureBlendMode(SDL_Texture *texture,
  #     proc SDL_BlendMode *blendMode)
  # int SDL_GetTextureColorMod(SDL_Texture *texture,
  #     Uint8 *r, Uint8 *g, Uint8 *b)
  # int SDL_GetTextureAlphaModFloat(SDL_Texture *texture, float *alpha);
  # int SDL_GetTextureColorModFloat(SDL_Texture *texture, float *r, float *g, float *b);

  proc SDL_GetTextureProperties(texture: Texture): PropertiesID

  # int SDL_GetTextureScaleMode(SDL_Texture *texture,
  #     proc SDL_ScaleMode *scaleMode)

  proc SDL_LockTexture(texture: Texture, rect: ptr Rect, pixels: ptr pointer,
                       pitch: ptr cint): cbool

  proc SDL_LockTextureToSurface(texture: Texture, rect: ptr Rect,
                                surface: ptr SurfacePtr): cbool

  proc SDL_GetTextureSize(texture: Texture, w, h: ptr cfloat): cbool

  proc SDL_RenderClear(renderer: Renderer): cbool

  # SDL_bool SDL_RenderClipEnabled(SDL_Renderer *renderer)

  proc SDL_RenderCoordinatesFromWindow(renderer: Renderer,
                                       window_x, window_y: cfloat,
                                       x, y: ptr cfloat): cbool

  # int SDL_RenderCoordinatesToWindow(SDL_Renderer *renderer,
  #     float x, float y, float *window_x, float *window_y)

  # bool SDL_RenderDebugText(SDL_Renderer *renderer, float x, float y, const char *str)

  # bool SDL_RenderDebugTextFormat(SDL_Renderer *renderer, float x, float y, const char *fmt, ...)

  proc SDL_RenderFillRect(renderer: Renderer, rect: ptr FRect): cbool

  # int SDL_RenderFillRects(SDL_Renderer *renderer, const SDL_FRect *rects,
  #     int count)

  proc SDL_RenderGeometry(
    renderer      : Renderer,
    texture       : Texture,
    vertices      : ptr Vertex,
    num_vertices  : cint,
    indices       : ptr cint,
    num_indices   : cint
  ): cbool

  # int SDL_RenderGeometryRaw(SDL_Renderer *renderer,
  #                            SDL_Texture *texture,
  #                            const float *xy, int xy_stride,
  #                            const SDL_Color *color, int color_stride,
  #                            const float *uv, int uv_stride,
  #                            int num_vertices,
  #                            const void *indices, int num_indices, int size_indices)

  proc SDL_RenderLine(
    renderer  : Renderer,
    x1        : cfloat,
    y1        : cfloat,
    x2        : cfloat,
    y2        : cfloat
  ): cbool

  # int SDL_RenderLines(SDL_Renderer *renderer, const SDL_FPoint *points,
  #     int count)

  proc SDL_RenderPoint(renderer: Renderer, x, y: cfloat): cbool

  # int SDL_RenderPoints(SDL_Renderer *renderer, const SDL_FPoint *points,
  #     int count)

  proc SDL_RenderPresent(renderer: Renderer): cbool

  # int SDL_RenderReadPixels(SDL_Renderer *renderer, const SDL_Rect *rect)

  proc SDL_RenderRect(renderer: Renderer, rect: ptr FRect): cbool

  # int SDL_RenderRects(SDL_Renderer *renderer, const SDL_FRect *rects,
  #     int count)

  proc SDL_RenderTexture(renderer: Renderer, texture: Texture,
                         srcrect, dstrect: ptr FRect): cbool

  # int SDL_RenderTexture9Grid(SDL_Renderer *renderer, SDL_Texture *texture, const SDL_FRect *srcrect, float left_width, float right_width, float top_height, float bottom_height, float scale, const SDL_FRect *dstrect);

  # bool SDL_RenderTextureAffine(SDL_Renderer *renderer, SDL_Texture *texture, const SDL_FRect *srcrect, const SDL_FPoint *origin, const SDL_FPoint *right, const SDL_FPoint *down);

  proc SDL_RenderTextureRotated(
    renderer  : Renderer,
    texture   : Texture,
    srcrect   : ptr FRect,
    dstrect   : ptr FRect,
    angle     : cdouble,
    center    : ptr FPoint,
    flip      : FlipMode
  ): cbool

  # int SDL_RenderTextureTiled(SDL_Renderer *renderer, SDL_Texture *texture, const SDL_FRect *srcrect, float scale, const SDL_FRect *dstrect)

  # SDL_bool SDL_RenderViewportSet(SDL_Renderer *renderer);

  proc SDL_SetRenderClipRect(renderer: Renderer, rect: ptr Rect): cbool

  # int SDL_SetRenderColorScale(SDL_Renderer *renderer, float scale);

  proc SDL_SetRenderDrawBlendMode(
    renderer    : Renderer,
    blend_mode  : BlendMode
  ): cbool

  proc SDL_SetRenderDrawColor(renderer: Renderer, r, g, b, a: byte): cbool

  # int SDL_SetRenderDrawColorFloat(SDL_Renderer *renderer, float r, float g, float b, float a);

  # int SDL_SetRenderLogicalPresentation(SDL_Renderer *renderer,
  #     int w, int h, SDL_RendererLogicalPresentation mode)

  proc SDL_SetRenderScale(renderer: Renderer,
                          scale_x, scale_y: cfloat): cbool

  proc SDL_SetRenderTarget(renderer: Renderer, texture: Texture): cbool

  proc SDL_SetRenderVSync(renderer: Renderer, vsync: cint): cbool

  proc SDL_SetRenderViewport(renderer: Renderer, rect: ptr Rect): cbool

  proc SDL_SetTextureAlphaMod(texture: Texture, alpha: byte): cbool

  # int SDL_SetTextureAlphaModFloat(SDL_Texture *texture, float alpha);

  proc SDL_SetTextureBlendMode(
    texture     : Texture,
    blend_mode  : BlendMode
  ): cbool

  proc SDL_SetTextureColorMod(texture: Texture, r, g, b: byte): cbool

  # int SDL_SetTextureColorModFloat(SDL_Texture *texture, float r, float g, float b);

  proc SDL_SetTextureScaleMode(texture: Texture,
                               scale_mode: ScaleMode): cbool

  proc SDL_UnlockTexture(texture: Texture)

  # int SDL_UpdateNVTexture(SDL_Texture *texture, const SDL_Rect *rect,
  #                         const Uint8 *Yplane, int Ypitch,
  #                         const Uint8 *UVplane, int UVpitch)

  proc SDL_UpdateTexture(texture: Texture, rect: ptr Rect, pixels: pointer,
                         pitch: cint): cbool

  # int SDL_UpdateYUVTexture(SDL_Texture *texture, const SDL_Rect *rect,
  #                          const Uint8 *Yplane, int Ypitch,
  #                          const Uint8 *Uplane, int Upitch,
  #                          const Uint8 *Vplane, int Vpitch)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_surface.h>                                                      #
  # ------------------------------------------------------------------------- #

  # int SDL_AddSurfaceAlternateImage(SDL_Surface *surface, SDL_Surface *image)
  # int SDL_BlitSurface (SDL_Surface *src, const SDL_Rect *srcrect,
  #     proc SDL_Surface *dst, const SDL_Rect *dstrect)
  # int SDL_BlitSurface9Grid(SDL_Surface *src, const SDL_Rect *srcrect, int left_width, int right_width, int top_height, int bottom_height, float scale, SDL_ScaleMode scaleMode, SDL_Surface *dst, const SDL_Rect *dstrect);
  # int SDL_BlitSurfaceScaled (SDL_Surface *src, const SDL_Rect *srcrect,
  #     proc SDL_Surface *dst, SDL_Rect *dstrect, SDL_ScaleMode scaleMode)
  # int SDL_BlitSurfaceTiled(SDL_Surface *src, const SDL_Rect *srcrect, SDL_Surface *dst, const SDL_Rect *dstrect)
  # int SDL_BlitSurfaceTiledWithScale(SDL_Surface *src, const SDL_Rect *srcrect, float scale, SDL_ScaleMode scaleMode, SDL_Surface *dst, const SDL_Rect *dstrect)
  # int SDL_BlitSurfaceUnchecked (SDL_Surface *src, const SDL_Rect *srcrect,
  #     proc SDL_Surface *dst, const SDL_Rect *dstrect)
  # int SDL_BlitSurfaceUncheckedScaled (SDL_Surface *src,
  #     const SDL_Rect *srcrect, SDL_Surface *dst, const SDL_Rect *dstrect, SDL_ScaleMode scaleMode)
  # int SDL_ConvertPixels(int width, int height, SDL_PixelFormatEnum src_format,
  #     const void *src, int src_pitch, SDL_PixelFormatEnum dst_format, void *dst,
  #     int dst_pitch)
  # int SDL_ConvertPixelsAndColorspace(int width, int height, SDL_PixelFormatEnum src_format, SDL_Colorspace src_colorspace, const void *src, int src_pitch, SDL_PixelFormatEnum dst_format, SDL_Colorspace dst_colorspace, void *dst, int dst_pitch);
  # SDL_Surface *SDL_ConvertSurface(SDL_Surface *surface,
  #     const SDL_PixelFormat *format)
  # SDL_Surface *SDL_ConvertSurfaceFormat(SDL_Surface *surface,
  #     SDL_PixelFormatEnum pixel_format)
  # SDL_Surface *SDL_ConvertSurfaceFormatAndColorspace(SDL_Surface *surface, SDL_PixelFormatEnum pixel_format, SDL_Colorspace colorspace);

  # SDL_Surface *SDL_CreateSurface (int width, int height, SDL_PixelFormatEnum format)

  proc SDL_CreateSurfaceFrom(width, height: cint, format: PixelFormatEnum,
                             pixels: pointer, pitch: cint): SurfacePtr

  # SDL_Palette * SDL_CreateSurfacePalette(SDL_Surface *surface)

  proc SDL_DestroySurface(surface: SurfacePtr)

  # SDL_Surface *SDL_DuplicateSurface(SDL_Surface *surface)
  # int SDL_FillSurfaceRect (SDL_Surface *dst, const SDL_Rect *rect,
  #     Uint32 color)
  # int SDL_FillSurfaceRects (SDL_Surface *dst, const SDL_Rect *rects,
  #     int count, Uint32 color)
  # int SDL_FlipSurface(SDL_Surface *surface, SDL_FlipMode flip);
  # int SDL_GetSurfaceAlphaMod(SDL_Surface *surface, Uint8 *alpha)
  # int SDL_GetSurfaceBlendMode(SDL_Surface *surface,
  #     proc SDL_BlendMode *blendMode)
  # int SDL_GetSurfaceClipRect(SDL_Surface *surface, SDL_Rect *rect)
  # int SDL_GetSurfaceColorKey(SDL_Surface *surface, Uint32 *key)
  # int SDL_GetSurfaceColorMod(SDL_Surface *surface,
  #     Uint8 *r, Uint8 *g, Uint8 *b)
  # SDL_Colorspace SDL_GetSurfaceColorspace(SDL_Surface *surface)
  # SDL_Surface ** SDL_GetSurfaceImages(SDL_Surface *surface, int *count)
  # SDL_Palette * SDL_GetSurfacePalette(SDL_Surface *surface)
  # SDL_PropertiesID SDL_GetSurfaceProperties(SDL_Surface *surface)

  proc SDL_LoadBMP(file: cstring): SurfacePtr

  # proc SDL_LoadBMP_IO(src: IOStream, closeio: cint): SurfacePtr

  proc SDL_LockSurface(surface: SurfacePtr): cbool

  # Uint32 SDL_MapSurfaceRGB(SDL_Surface *surface, Uint8 r, Uint8 g, Uint8 b)
  # Uint32 SDL_MapSurfaceRGBA(SDL_Surface *surface, Uint8 r, Uint8 g, Uint8 b, Uint8 a)
  # int SDL_PremultiplyAlpha(int width, int height, SDL_PixelFormat src_format, const void *src, int src_pitch, SDL_PixelFormat dst_format, void *dst, int dst_pitch, SDL_bool linear)
  # int SDL_PremultiplySurfaceAlpha(SDL_Surface *surface, SDL_bool linear)

  # int SDL_ReadSurfacePixel(SDL_Surface *surface, int x, int y, Uint8 *r, Uint8 *g, Uint8 *b, Uint8 *a)
  # int SDL_ReadSurfacePixelFloat(SDL_Surface *surface, int x, int y, float *r, float *g, float *b, float *a)
  # void SDL_RemoveSurfaceAlternateImages(SDL_Surface *surface)

  proc SDL_SaveBMP(surface: SurfacePtr, file: cstring): cbool

  # proc SDL_SaveBMP_IO(surface: SurfacePtr, dst: IOStream, closeio: cint): cbool

  # SDL_Surface * SDL_ScaleSurface(SDL_Surface *surface, int width, int height, SDL_ScaleMode scaleMode);
  # int SDL_SetSurfaceAlphaMod(SDL_Surface *surface, Uint8 alpha)
  # int SDL_SetSurfaceBlendMode(SDL_Surface *surface,
  #     proc SDL_BlendMode blendMode)
  # SDL_bool SDL_SetSurfaceClipRect(SDL_Surface *surface,
  #     const SDL_Rect *rect)

  proc SDL_SetSurfaceColorKey(surface: SurfacePtr, enabled: cbool,
                              key: uint32): cbool

  # int SDL_SetSurfaceColorMod(SDL_Surface *surface,
  #     Uint8 r, Uint8 g, Uint8 b)
  # int SDL_SetSurfaceColorspace(SDL_Surface *surface, SDL_Colorspace colorspace)

  proc SDL_SetSurfacePalette(surface: SurfacePtr, palette: ptr Palette): cbool

  proc SDL_SetSurfaceRLE(surface: SurfacePtr, enabled: cbool): cbool

  # int SDL_SoftStretch(SDL_Surface *src, const SDL_Rect *srcrect,
  #     proc SDL_Surface *dst, const SDL_Rect *dstrect, SDL_ScaleMode scaleMode)
  # extern SDL_DECLSPEC bool SDLCALL SDL_StretchSurface(SDL_Surface *src, const SDL_Rect *srcrect, SDL_Surface *dst, const SDL_Rect *dstrect, SDL_ScaleMode scaleMode)  # 3.4.0+.
  # SDL_bool SDL_SurfaceHasAlternateImages(SDL_Surface *surface)
  # SDL_bool SDL_SurfaceHasColorKey(SDL_Surface *surface)
  # SDL_bool SDL_SurfaceHasRLE(SDL_Surface *surface)

  proc SDL_UnlockSurface(surface: SurfacePtr)

  proc SDL_WriteSurfacePixel(surface: SurfacePtr, x: cint, y: cint,
                             r: byte, g: byte, b: byte, a: byte): cbool

  # int SDL_WriteSurfacePixelFloat(SDL_Surface *surface, int x, int y, float r, float g, float b, float a)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_syswm.h>                                                        #
  # ------------------------------------------------------------------------- #

  # int SDL_GetWindowWMInfo(SDL_Window *window, SDL_SysWMinfo *info,
  #     Uint32 version)

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_timer.h>                                                        #
  # ------------------------------------------------------------------------- #

  proc SDL_AddTimer(interval: uint32, callback: TimerCallback,
                    param: pointer): TimerID

  # SDL_TimerID SDL_AddTimerNS(Uint64 interval, SDL_NSTimerCallback callback, void *userdata)

  proc SDL_Delay(ms: uint32)

  proc SDL_DelayNS(ns: uint64)

  proc SDL_GetPerformanceCounter(): uint64

  proc SDL_GetPerformanceFrequency(): uint64

  proc SDL_GetTicks(): uint64

  proc SDL_GetTicksNS(): uint64

  proc SDL_RemoveTimer(id: TimerID): cbool

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_version.h>                                                      #
  # ------------------------------------------------------------------------- #

  proc SDL_GetRevision(): cstring

  proc SDL_GetVersion(): cint

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_video.h>                                                        #
  # ------------------------------------------------------------------------- #

  proc SDL_CreatePopupWindow(
    window    : Window,
    offset_x  : cint,
    offset_y  : cint,
    w         : cint,
    h         : cint,
    flags     : WindowFlags
  ): Window

  proc SDL_CreateWindow(
    title     : cstring,
    w         : cint,
    h         : cint,
    flags     : WindowFlags
  ): Window

  proc SDL_CreateWindowWithProperties(props: PropertiesID): Window

  proc SDL_DestroyWindow(window: Window)

  # int SDL_DestroyWindowSurface(SDL_Window *window)

  proc SDL_DisableScreenSaver(): cbool

  # SDL_EGLConfig SDL_EGL_GetCurrentEGLConfig(void)
  # SDL_EGLDisplay SDL_EGL_GetCurrentEGLDisplay(void)
  # SDL_FunctionPointer SDL_EGL_GetProcAddress(const char *proc)
  # SDL_EGLSurface SDL_EGL_GetWindowEGLSurface(SDL_Window *window)
  # void SDL_EGL_SetEGLAttributeCallbacks(
  #     proc SDL_EGLAttribArrayCallback platformAttribCallback,
  #     proc SDL_EGLIntArrayCallback surfaceAttribCallback,
  #     proc SDL_EGLIntArrayCallback contextAttribCallback)

  proc SDL_EnableScreenSaver(): cbool

  proc SDL_FlashWindow(
    window    : Window,
    operation : FlashOperation
  ): cbool

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

  proc SDL_GetClosestFullscreenDisplayMode(display_id: DisplayID, w, h: cint,
                                           refresh_rate: cfloat,
                                           include_high_density_modes: cbool): ptr DisplayMode

  proc SDL_GetCurrentDisplayMode(display_id: DisplayID): ptr DisplayMode

  # SDL_DisplayOrientation SDL_GetCurrentDisplayOrientation(
  #     proc SDL_DisplayID displayID)

  proc SDL_GetCurrentVideoDriver(): cstring

  # const SDL_DisplayMode *SDL_GetDesktopDisplayMode(SDL_DisplayID displayID)

  proc SDL_GetDisplayBounds(display_id: DisplayID, rect: ptr Rect): cbool

  proc SDL_GetDisplayContentScale(display_id: DisplayID): cfloat

  # SDL_DisplayID SDL_GetDisplayForPoint(const SDL_Point *point)
  # SDL_DisplayID SDL_GetDisplayForRect(const SDL_Rect *rect)

  proc SDL_GetDisplayForWindow(window: Window): DisplayID

  proc SDL_GetDisplayName(display_id: DisplayID): cstring

  # SDL_PropertiesID SDL_GetDisplayProperties(SDL_DisplayID displayID)

  proc SDL_GetDisplays(count: ptr cint): ptr UncheckedArray[DisplayID]

  proc SDL_GetDisplayUsableBounds(display_id: DisplayID, rect: ptr Rect): cbool

  proc SDL_GetFullscreenDisplayModes(display_id: DisplayID,
                                     count: ptr cint): ptr UncheckedArray[ptr DisplayMode]

  proc SDL_GetGrabbedWindow(): Window

  # SDL_DisplayOrientation SDL_GetNaturalDisplayOrientation(
  #     proc SDL_DisplayID displayID)

  proc SDL_GetNumVideoDrivers(): cint

  proc SDL_GetPrimaryDisplay(): DisplayID

  # SDL_SystemTheme SDL_GetSystemTheme(void)
  # const char *SDL_GetVideoDriver(int index)

  # int SDL_GetWindowAspectRatio(SDL_Window *window, float *min_aspect, float *max_aspect)

  # int SDL_GetWindowBordersSize(SDL_Window *window, int *top, int *left,
  #     int *bottom, int *right)

  # float SDL_GetWindowDisplayScale(SDL_Window *window)

  proc SDL_GetWindowFlags(window: Window): WindowFlags

  # int SDL_SetWindowFocusable(SDL_Window *window, SDL_bool focusable)

  proc SDL_GetWindowFromID(id: WindowID): Window

  proc SDL_GetWindowFullscreenMode(window: Window): ptr DisplayMode

  # void *SDL_GetWindowICCProfile(SDL_Window *window, size_t *size)

  proc SDL_GetWindowID(window: Window): WindowID

  proc SDL_GetWindowKeyboardGrab(window: Window): cbool

  proc SDL_GetWindowMaximumSize(window: Window, w, h: ptr cint): cbool

  proc SDL_GetWindowMinimumSize(window: Window, w, h: ptr cint): cbool

  proc SDL_GetWindowMouseGrab(window: Window): cbool

  # SDL_GetWindowMouseRect(
  #   window: Window
  #): ptr Rect

  # int SDL_GetWindowOpacity(SDL_Window *window, float *out_opacity)
  # SDL_Window *SDL_GetWindowParent(SDL_Window *window)
  # float SDL_GetWindowPixelDensity(SDL_Window *window)

  proc SDL_GetWindowPixelFormat(window: Window): PixelFormatEnum

  proc SDL_GetWindowPosition(window: Window, x, y: ptr cint): cbool

  # SDL_PropertiesID SDL_GetWindowProperties(SDL_Window *window)

  # SDL_Window ** SDLCALL SDL_GetWindows(int *count)

  # int SDL_GetWindowSafeArea(SDL_Window *window, SDL_Rect *rect);

  proc SDL_GetWindowSize(window: Window, width, height: ptr cint): cbool

  # int SDL_GetWindowSizeInPixels(SDL_Window *window, int *w, int *h)
  # SDL_Surface *SDL_GetWindowSurface(SDL_Window *window)
  # int SDL_GetWindowSurfaceVSync(SDL_Window *window, int *vsync)
  # const char *SDL_GetWindowTitle(SDL_Window *window)

  proc SDL_HideWindow(window: Window): cbool

  # int SDL_MaximizeWindow(SDL_Window *window)
  # int SDL_MinimizeWindow(SDL_Window *window)

  proc SDL_RaiseWindow(window: Window): cbool

  # int SDL_RestoreWindow(SDL_Window *window)

  proc SDL_ScreenSaverEnabled(): cbool

  # int SDL_SetWindowAlwaysOnTop(SDL_Window *window, SDL_bool on_top)

  # int SDL_SetWindowAspectRatio(SDL_Window *window, float min_aspect, float max_aspect)

  proc SDL_SetWindowBordered(window: Window, bordered: cbool): cbool

  # int SDL_SetWindowFocusable(SDL_Window *window, SDL_bool focusable)

  proc SDL_SetWindowFullscreen(window: Window, fullscreen: cbool): cbool

  proc SDL_SetWindowFullscreenMode(window: Window,
                                   mode: ptr DisplayMode): cbool

  # int SDL_SetWindowHitTest(SDL_Window *window, SDL_HitTest callback,
  #     void *callback_data)

  proc SDL_SetWindowIcon(window: Window, surface: SurfacePtr): cbool

  proc SDL_SetWindowKeyboardGrab(window: Window, grabbed: cbool): cbool

  proc SDL_SetWindowMaximumSize(window: Window, max_w, max_h: cint): cbool

  proc SDL_SetWindowMinimumSize(window: Window, min_w, min_h: cint): cbool

  # int SDL_SetWindowModalFor(SDL_Window *modal_window,
  #     proc SDL_Window *parent_window)

  proc SDL_SetWindowMouseGrab(window: Window, grabbed: cbool): cbool

  # int SDL_SetWindowMouseRect(SDL_Window *window, const SDL_Rect *rect)
  # int SDL_SetWindowOpacity(SDL_Window *window, float opacity)

  proc SDL_SetWindowPosition(window: Window, x, y: cint): cbool

  proc SDL_SetWindowResizable(window: Window, ontop: cbool): cbool

  # int SDL_SetWindowShape(SDL_Window *window, SDL_Surface *shape);

  proc SDL_SetWindowSize(window: Window, x, y: cint): cbool

  # int SDL_SetWindowSurfaceVSync(SDL_Window *window, int vsync)

  proc SDL_SetWindowTitle(window: Window, title: cstring): cbool

  proc SDL_ShowWindow(window: Window): cbool

  # int SDL_ShowWindowSystemMenu(SDL_Window *window, int x, int y)
  # int SDL_SyncWindow(SDL_Window *window)

  proc SDL_UpdateWindowSurface(window: Window): cbool

  # int SDL_UpdateWindowSurfaceRects(SDL_Window *window,
  #     const SDL_Rect *rects, int numrects)

  # SDL_bool SDL_WindowHasSurface(SDL_Window *window)


# =========================================================================== #
# ==  SDL3 library object                                                  == #
# =========================================================================== #

dlgencalls "sdl3_ttf", lib_paths_ttf:

  # ------------------------------------------------------------------------- #
  # <SDL3/SDL_ttf.h>                                                          #
  # ------------------------------------------------------------------------- #

  proc TTF_Init(): cbool
  proc TTF_Quit()

  proc TTF_OpenFont(file: cstring, ptsize: cfloat): Font
  proc TTF_CloseFont(font: Font)

  proc TTF_GetFontStyle(font: Font): FontStyleFlags
  proc TTF_SetFontStyle(font: Font, style: FontStyleFlags)
  proc TTF_GetFontOutline(font: Font): cint
  proc TTF_SetFontOutline(font: Font, outline: cint): cbool
  proc TTF_GetFontHinting(font: Font): HintingFlags
  proc TTF_SetFontHinting(font: Font, hinting: HintingFlags)

  proc TTF_GetFontHeight(font: Font): cint
  proc TTF_GetStringSize(font: Font, text: cstring, length: csize_t, w: ptr cint, h: ptr cint): cbool
  proc TTF_RenderText_Blended(font: Font, text: cstring, length: csize_t, fg: Color): SurfacePtr

  proc TTF_CreateRendererTextEngine(renderer: Renderer): TextEngine
  proc TTF_DestroyRendererTextEngine(engine: TextEngine)
  proc TTF_CreateText(engine: TextEngine, font: Font, text: cstring, length: csize_t): Text
  proc TTF_DestroyText(text: Text)
  proc TTF_SetTextString(text: Text, s: cstring, length: csize_t): cbool
  proc TTF_SetTextColor(text: Text, r: byte, g: byte, b: byte, a: byte): cbool
  proc TTF_DrawRendererText(text: Text, x: cfloat, y: cfloat): cbool

{.push hint[GlobalVar]: on.}


# =========================================================================== #
# ==  Loading/unloading functions                                          == #
# =========================================================================== #

# vim: set sts=2 et sw=2:
