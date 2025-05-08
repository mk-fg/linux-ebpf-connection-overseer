#? replace(sub = "\t", by = "  ")
#
# Debug build/run: nim c -p=sdl2 -w=on --hints=on -r widget.nim -h
# Final build: nim c -p=sdl2 -d:release -d:strip -d:lto_incremental --opt:speed -o=leco-sdl-widget widget.nim
# Usage info: ./leco-sdl-widget -h

# XXX: cleanup later
import std/[ strutils, strformat, parseopt,
	os, osproc, logging, re, tables, monotimes, base64 ]
import sdl2, sdl2/ttf


const SDL_WINDOW_SKIP_TASKBAR = 0x00010000
const SDL_WINDOW_UTILITY = 0x00020000

{.passl: "-lcrypto"}
proc SHA256( data: cstring, data_len: cint,
	md_buf: cstring ): cstring {.importc, header: "<openssl/sha.h>".}


type Conf = object
	win_title = "LECO Network-Monitor Widget"
	win_ox = 20
	win_oy = 40
	win_w = 600
	win_h = 400
	win_upd_ns = 0.0
	font_file = ""
	font_h = 10
	line_h = 0 # to be calculated
	line_uid_chars = 3
	line_uid_fmt = "#$1"
	color_fg = color(255, 255, 255, 0) # XXX
	run_fifo = ""
	run_debug = false

proc parse_conf_file(conf_path: string): Conf =
	# XXX: check that all parsed opts are in Conf and vice-versa
	var
		conf = Conf()
		re_comm = re"^\s*([#;].*)?$"
		re_name = re"^\s*\[(.*)\]\s*$"
		re_var = re"^\s*(\S.*?)\s*(=\s*(\S.*?)?\s*(\s#.*)?)?$"
		line_n = 0
		name = "-top-level-"
		key, val: string
		conf_text_hx = 1.5
		conf_text_gap = 0
	template section(sec: string, checks: typed) =
		if name == sec and key != "":
			try: checks
			except ValueError: warn( "Failed to parse config" &
				&" value for '{key}' on line {line_n} under [{name}] :: {line}" )
			key = ""
	template section_val_unknown = warn(
		&"Ignoring unrecognized config-option line {line_n} under [{name}] :: {line}" )
	for line in (readFile(conf_path) & "\n[end]").splitLines:
		line_n += 1
		if line =~ re_comm: continue
		elif line =~ re_name: name = matches[0]
		elif line =~ re_var:
			key = matches[0].replace("_", "-"); val = matches[2]
			section "window":
				case key:
				of "title": conf.win_title = val
				of "init-offset-left": conf.win_ox = val.parseInt
				of "init-offset-top": conf.win_oy = val.parseInt
				of "init-width": conf.win_w = val.parseInt
				of "init-height": conf.win_w = val.parseInt
				of "frames-per-second-max":
					let fps = val.parseFloat
					if fps > 0: conf.win_upd_ns = 1_000_000_000 / fps
				else: section_val_unknown
			section "text":
				case key:
				of "font": conf.font_file = val
				of "font-height": conf.font_h = val.parseInt
				of "line-height":
					if val.contains("."): conf_text_hx = val.parseFloat
					elif val.startswith("+"): conf_text_gap = val[1 .. ^1].parseInt
					else: conf_text_hx = val.parseFloat * -1
				else: section_val_unknown
			section "run":
				case key:
				of "fifo": conf.run_fifo = val
				of "debug": conf.run_debug = case val
					of "y","yes","true","1","on": true
					of "n","no","false","0","off": false
					else: raise newException(ValueError, "Unrecognized boolean value")
				else: section_val_unknown
			if key != "": warn( "Unrecognized config" &
				&" section [{name}] for '{key}' value on line {line_n} :: {line}" )
		else: warn(&"Failed to parse config-file line {line_n} :: {line}")
	if conf.line_h == 0:
		if conf_text_gap != 0: conf.line_h = conf.font_h + conf_text_gap
		elif conf_text_hx >= 0: conf.line_h = int(float(conf.font_h) * conf_text_hx)
		else: conf.line_h = int(conf_text_hx)
	return conf


type
	CNS = int64
	NetConns = object
		conf: Conf
		table: Table[string, ConnInfo] # XXX
	ConnInfo = tuple
		ns: CNS
		line: string

method conn_list(o: var NetConns, limit: int): seq[ConnInfo] {.base.} =
	# XXX: returns N either most-recently-updated rows
	# XXX: no need to return more than the window rows, as those should always fill it up
	let ns = getMonoTime().ticks # for id/colors/hashes - line strings can change due to traffic counters
	return @[
		(ns: CNS(ns+1), line: "12:21 :: fraggod :: ssh [tmux.scope] :: somehost.net 22 :: v 7.3M / 13.9M ^"),
		(ns: CNS(ns+2), line: "15:50 :: fraggod :: waterfox [waterfox.scope] :: github.com 443 :: v 4.2M / 8K ^"),
		(ns: CNS(ns+3), line: "15:50 :: fraggod :: waterfox [waterfox.scope] :: live.github.com 443/udp :: v 1.3M / 889K ^"),
		(ns: CNS(ns+4), line: "15:52 :: player :: lutris [lutris.scope] :: lutris.com 443 :: v 76K / 17K ^") ]


type
	Painter = object
		conf: Conf
		conn_list: proc (limit: int): seq[tuple[ns: CNS, line: string]]
		win: WindowPtr
		rdr: RendererPtr
		font: FontPtr
		tex: TexturePtr
		w, h, oy, ox, uid_w: cint
		rows_draw = 0
		rows: Table[CNS, PaintedRow]
	PaintedRow = object
		n: int
		ns: CNS
		ns_update: int64
		uid: string
		uid_color: Color
		line: string
		updated = true

method init(o: Painter) {.base.} =
	assert o.font.sizeUtf8(cstring(o.conf.line_uid_fmt % (
		"W".repeat(o.conf.line_uid_chars) & " " )), o.uid_w.addr, o.h.addr) != 0

method row_uid(o: Painter, ns: CNS): (string, Color) {.base.} =
	var
		ns_str = $ns
		uid_str = newString(32)
	discard SHA256(ns_str.cstring, ns_str.len.cint, uid_str.cstring)
	let
		uid = uid_str.encode(safe=true)[0 .. o.conf.line_uid_chars]
		uid_color = color(uid_str[0].uint8, uid_str[1].uint8, uid_str[2].uint8, 0)
	return (uid, uid_color)

method row_get(o: var Painter, ns: CNS, line: string): PaintedRow {.base.} =
	## Returns either matching PaintedRow or a new one,
	##   replacing oldest row in a table if if's at full capacity.
	let ts = getMonoTime().ticks
	if o.rows.contains(ns): # update existing row
		result = o.rows[ns]
		if result.line == line: result.updated = false
		else: result.line = line; result.ns_update = ts; result.updated = true
		return
	if o.rows.len < o.rows_draw:
		result = PaintedRow(n: o.rows.len) # new row
	else: # replace row
		var ns0 = ts
		for r in o.rows.values:
			if r.ns_update <= ns0: ns0 = r.ns_update; result = r
		o.rows.del(result.ns)
	result.ns = ns; result.ns_update = ts; result.line = line
	let (uid, uid_color) = o.row_uid(ns)
	result.uid = uid; result.uid_color = uid_color
	o.rows[ns] = result

method draw(o: var Painter) {.base.} =
	var w, h: cint
	o.win.getSize(w, h)
	if o.tex.isNil or w != o.w or h != o.h:
		if not o.tex.isNil: o.tex.destroyTexture
		o.tex = o.rdr.createTexture( # XXX: use streaming texture
			o.win.getPixelFormat(), SDL_TEXTUREACCESS_STATIC, w, h )
		o.rdr.setRenderTarget(o.tex)
		o.rdr.setDrawBlendMode(BlendMode_None)
		o.rdr.setDrawColor(40, 0, 0, 255)
		o.rdr.clear()
		o.rdr.setRenderTarget(nil)
		o.tex.setBlendMode(BlendMode_Blend)
		o.w = w; o.h = h
		o.oy = cint(o.conf.line_h - o.conf.font_h)
		o.rows_draw = (h - o.oy) div o.conf.line_h
		o.oy += cint(((h - o.oy) - o.rows_draw * o.conf.line_h) div o.rows_draw)
		o.rows.clear # repaint the whole thing

	for conn in o.conn_list(o.rows_draw):
		let row = o.row_get(conn.ns, conn.line)
		if not row.updated: continue
		var
			surf = o.font.renderUtf8Blended(row.line.cstring, o.conf.color_fg)
			# XXX: render uid as well
			slice = rect(x=o.uid_w, y=cint(o.oy + row.n * o.conf.line_h), w=surf.w, h=surf.h)
		# XXX: use SDL_LockTexture / SDL_UnlockTexture instead
		o.tex.updateTexture(slice.addr, surf.pixels, surf.pitch)
		surf.freeSurface()

	o.rdr.setDrawBlendMode(BlendMode_None)
	o.rdr.setDrawColor(0, 40, 0, 255)
	o.rdr.clear()

	# o.rdr.setDrawBlendMode(BlendMode_Blend)
  # o.rdr.copy(o.tex, nil, nil)


proc main_help(err="") =
	proc print(s: string) =
		let dst = if err == "": stdout else: stderr
		write(dst, s); write(dst, "\n")
	let app = getAppFilename().lastPathPart
	if err != "": print &"ERROR: {err}"
	print &"\nUsage: {app} [options] <config.ini>"
	if err != "": print &"Run '{app} --help' for more information"; quit 1
	print dedent(&"""

		Graphical SDL3 UI tool, to read network information/events
			from leco-event-pipe output fifo socket, and render those
			as fading text lines to a semi-transparent desktop window.
		Intended to run indefinitely as a desktop network-monitoring widget.

		Arguments and options (in "{app} [options] <config.ini>" command):

			<config.ini>
				Configuration ini-file to read. See example in the repository for all options.

			-d/--debug - enable verbose logging to stderr, incl. during config file loading.
		""")
	quit 0

proc main(argv: seq[string]) =
	var
		opt_conf_file = ""
		opt_debug = false

	block cli_parser:
		var opt_last = ""
		proc opt_fmt(opt: string): string =
			if opt.len == 1: &"-{opt}" else: &"--{opt}"
		proc opt_empty_check =
			if opt_last == "": return
			main_help &"{opt_fmt(opt_last)} option unrecognized or requires a value"
		proc opt_set(k: string, v: string) =
			# if k in ["x", "some-delay"]: opt_some_delay = parseFloat(v)
			main_help &"Unrecognized option [ {opt_fmt(k)} = {v} ]"

		for t, opt, val in getopt(argv):
			case t
			of cmdEnd: break
			of cmdShortOption, cmdLongOption:
				if opt in ["h", "help"]: main_help()
				elif opt in ["d", "debug"]: opt_debug = true
				elif val == "": opt_empty_check(); opt_last = opt
				else: opt_set(opt, val)
			of cmdArgument:
				if opt_last != "": opt_set(opt_last, opt); opt_last = ""
				elif opt_conf_file == "": opt_conf_file = opt
				else: main_help(&"Unrecognized argument: {opt}")
		opt_empty_check()

		if opt_conf_file == "":
			main_help "Missing required configuration file argument"

	var logger = newConsoleLogger(
		fmtStr="$levelid $datetime :: ", useStderr=true,
		levelThreshold=lvlAll, flushThreshold=lvlWarn )
	addHandler(logger)
	setLogFilter(if opt_debug: lvlAll else: lvlInfo)
	var conf = parse_conf_file(opt_conf_file)
	setLogFilter(if conf.run_debug or opt_debug: lvlAll else: lvlInfo)

	if conf.font_file == "":
		let fc_lookup = "sans:lang=en"
		warn( "No font path specified for text.font option, trying" &
			&" to find one via 'fc-match {fc_lookup}' command (fontconfig)" )
		conf.font_file = execProcess( "fc-match",
			args=["-f", "%{file}", fc_lookup], options={poUsePath} ).strip

	type SDL2Err = object of Defect
	template sdl_chk(condition: typed, msg: string) =
		if condition: raise SDL2Err.newException(msg & " :: SDL2 Error: " & $getError())
	template sdl_init(name: untyped, exp: typed) = # checks for nil error
		let `name` = exp
		sdl_chk `name`.isNil: "Init failure [" & astToStr(exp).replacef(re"^\s*([\w.]+).*", "$1") & "]"
	sdl_chk not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS): "SDL2 init failed"
	defer: sdl2.quit()
	sdl_chk not ttfInit(): "SDL2_TTF init failed"
	defer: ttfQuit()
	# XXX: need x11-specific hacks as well to make window transparent
	sdl_init win: createWindow(
		x=conf.win_ox.cint, y=conf.win_oy.cint, w=conf.win_w.cint, h=conf.win_h.cint,
		title=conf.win_title.cstring, flags=SDL_WINDOW_SHOWN or
			SDL_WINDOW_SKIP_TASKBAR or SDL_WINDOW_UTILITY or SDL_WINDOW_BORDERLESS )
	defer: win.destroy()
	sdl_init win_rdr: createRenderer( window=win, index=0,
		flags=Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture )
	defer: win_rdr.destroy()
	sdl_init win_font: ttf.openFont(conf.font_file.cstring, conf.font_h.cint)
	defer: win_font.close()

	# XXX: add bg thread that schedules render-UserEvents from NetConns read-loop
  var
		conns = NetConns(conf: conf)
		paint = Painter( conf: conf, win: win, rdr: win_rdr, font: win_font,
			conn_list: (proc (rows: int): seq[ConnInfo] = return conns.conn_list(rows)) )
		running = true
		ev = defaultEvent
	ev.kind = UserEvent; discard pushEvent(ev.addr)
	while running:
		while running and pollEvent(ev): # XXX: waitEvent with render-UserEvents
			case ev.kind
			of QuitEvent: running = false; break
			of UserEvent: break
			else: discard
		# XXX: fps frame delays for render-UserEvent
		paint.draw()
		win_rdr.present()

when is_main_module: main(os.commandLineParams())
