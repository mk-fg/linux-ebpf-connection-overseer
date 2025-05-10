#? replace(sub = "\t", by = "  ")
#
# Debug build/run: nim c -p=nsdl3 -w=on --hints=on -r widget.nim -h
# Final build: nim c -p=nsdl3 -d:release -d:strip -d:lto_incremental --opt:speed -o=leco-sdl-widget widget.nim
# Usage info: ./leco-sdl-widget -h

# XXX: cleanup later
import std/[ strutils, strformat, parseopt,
	os, osproc, logging, re, tables, monotimes, base64 ]

# XXX: convert ensure_not_nil to simpler macros
import nsdl3 as sdl

{.passl: "-lcrypto"}
proc SHA256( data: cstring, data_len: cint,
	md_buf: cstring ): cstring {.importc, header: "<openssl/sha.h>".}


type Conf = object
	win_title = "LECO Network-Monitor Widget"
	win_ox = 20
	win_oy = 40
	win_w = 600
	win_h = 400
	win_px = 0
	win_py = 0
	win_upd_ns = 0.0
	font_file = ""
	font_h = 10
	line_h = 0 # to be calculated
	line_uid_chars = 3
	line_uid_fmt = "#$1"
	color_bg = Color(r:0, g:20, b:0, a:128)
	color_fg = Color(r:33, g:74, b:206, a:255)
	run_fifo = ""
	run_debug = false
	app_version = "0.1"
	app_id = "net.fraggod.leco.widget"

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
				of "pad-x": conf.win_px = val.parseInt
				of "pad-y": conf.win_py = val.parseInt
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
	CNS = int64 # nanoseconds-based connection ID
	NetConns = object
		conf: Conf
		table: Table[string, ConnInfo] # XXX
	ConnInfo = tuple
		ns: CNS
		line: string

let ns_static = getMonoTime().ticks # XXX
method conn_list(o: var NetConns, limit: int): seq[ConnInfo] {.base.} =
	# XXX: returns N either most-recently-updated rows
	# XXX: no need to return more than the window rows, as those should always fill it up
	# let ns = getMonoTime().ticks # for id/colors/hashes - line strings can change due to traffic counters
	let ns = ns_static
	return @[
		(ns: CNS(ns+1), line: "12:21 :: fraggod :: ssh [tmux.scope] :: somehost.net 22 :: v 7.3M / 13.9M ^"),
		(ns: CNS(ns+2), line: "15:50 :: fraggod :: waterfox [waterfox.scope] :: github.com 443 :: v 4.2M / 8K ^"),
		(ns: CNS(ns+3), line: "15:50 :: fraggod :: waterfox [waterfox.scope] :: live.github.com 443/udp :: v 1.3M / 889K ^"),
		(ns: CNS(ns+4), line: "15:52 :: player :: lutris [lutris.scope] :: lutris.com 443 :: v 76K / 17K ^") ]


type
	Painter = object
		conf: Conf
		conn_list: proc (limit: int): seq[tuple[ns: CNS, line: string]]
		win: Window
		rdr: Renderer
		tex: Texture
		txt_font: Font
		txt_engine: TextEngine
		txt: Text
		ww, wh, tw, th, oy, uid_w: int
		rows_draw = 0
		rows: Table[CNS, PaintedRow]
		closed = false
	PaintedRow = object
		n: int
		ns: CNS
		ts_update: int64
		uid: string
		uid_color: Color
		line: string
		replaced = true
		updated = true

method init(o: var Painter) {.base.} =
	o.txt_font = sdl.OpenFont(o.conf.font_file, o.conf.font_h)
	o.txt_engine = sdl.CreateRendererTextEngine(o.rdr)
	o.txt = o.txt_engine.CreateText(o.txt_font, "", 0)
	o.txt.SetTextColor(o.conf.color_fg) # XXX: other font/text parameters
	let (w, _) = o.txt_font.GetStringSize(
		o.conf.line_uid_fmt % ("W".repeat(o.conf.line_uid_chars) & " ") )
	o.uid_w = w

method close(o: var Painter) {.base.} =
	if o.closed: return
	o.txt.DestroyText()
	o.txt_engine.DestroyRendererTextEngine()
	o.txt_font.CloseFont()
	o.closed = true

method check_texture(o: var Painter) {.base.} =
	## (Re-)Create texture matching window size, to (re-)render all text onto
	var w, h: int
	o.win.GetWindowSize(w, h)
	if not o.tex.isNil:
		if w == o.ww and h == o.wh: return
		o.tex.DestroyTexture()
	o.ww = w; o.wh = h
	w -= 2*o.conf.win_px; h -= 2*o.conf.win_px;
	o.tex = o.rdr.CreateTexture(
		sdl.PIXELFORMAT_ARGB8888, sdl.TEXTUREACCESS_TARGET, w, h )
	o.tex.SetTextureBlendMode(sdl.BLENDMODE_BLEND)
	o.tw = w; o.th = h
	o.oy = o.conf.line_h - o.conf.font_h
	o.rows_draw = (h - o.oy) div o.conf.line_h
	o.oy += ((h - o.oy) - o.rows_draw * o.conf.line_h) div o.rows_draw
	o.rows.clear() # put up all fresh rows

method row_uid(o: Painter, ns: CNS): (string, Color) {.base.} =
	var
		ns_str = $ns
		uid_str = newString(32)
	discard SHA256(ns_str.cstring, ns_str.len.cint, uid_str.cstring)
	let
		uid = o.conf.line_uid_fmt % uid_str.encode(safe=true)[0 .. o.conf.line_uid_chars]
		uid_color = Color(r:uid_str[0].byte, g:uid_str[1].byte, b:uid_str[2].byte, a:255)
	return (uid, uid_color)

method row_get(o: var Painter, ns: CNS, line: string): PaintedRow {.base.} =
	## Returns either matching PaintedRow or a new one,
	##   replacing oldest row in a table if if's at full capacity.
	let ts = getMonoTime().ticks
	if o.rows.contains(ns): # update existing row
		result = o.rows[ns]; result.replaced = false
		if result.line == line: result.updated = false
		else: result.line = line; result.ts_update = ts; result.updated = true
		return
	if o.rows.len < o.rows_draw:
		result = PaintedRow(n: o.rows.len) # new row
	else: # replace row
		var ns0 = ts
		for r in o.rows.values:
			if r.ts_update <= ns0: ns0 = r.ts_update; result = r
		o.rows.del(result.ns)
	result.ns = ns; result.ts_update = ts; result.line = line
	(result.uid, result.uid_color) = o.row_uid(ns)
	o.rows[ns] = result

method draw(o: var Painter) {.base.} =
	## Clear/update window contents buffer.
	## Maintains single texture with all text lines in the right places,
	##   and copies those to window with appropriate effects applied per-frame.
	o.check_texture()
	for conn in o.conn_list(o.rows_draw):
		let row = o.row_get(conn.ns, conn.line)
		if not row.updated: continue
		var y = row.n * o.conf.line_h
		o.rdr.SetRenderTarget(o.tex)
		o.rdr.SetRenderDrawBlendMode(sdl.BLENDMODE_NONE)
		o.rdr.SetRenderDrawColor(0, 0, 0, 0)
		o.rdr.RenderFillRect(0, y, o.tw, o.conf.line_h)
		y += o.oy
		if row.replaced:
			o.txt.SetTextColor(row.uid_color)
			o.txt.SetTextString(row.uid)
			o.txt.DrawRendererText(0, y)
			o.txt.SetTextColor(o.conf.color_fg)
		o.txt.SetTextString(row.line)
		o.txt.DrawRendererText(o.uid_w, y)

	o.rdr.SetRenderTarget()
	o.rdr.SetRenderDrawBlendMode(sdl.BLENDMODE_NONE)
	o.rdr.SetRenderDrawColor(o.conf.color_bg)
	o.rdr.RenderClear()

	# XXX: render row-rectangles with effects
	o.rdr.SetRenderDrawBlendMode(sdl.BLENDMODE_BLEND)
	o.rdr.RenderTexture(o.tex, o.conf.win_px, o.conf.win_py, o.tw, o.th)


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
	else: conf.font_file = conf.font_file.expandTilde()

	if not (sdl.open_sdl3_library() and sdl.open_sdl3_ttf_library()):
		raise SDLError.newException("Failed to open sdl3/sdl3_ttf libs")
	defer: sdl.close_sdl3_library(); sdl.close_sdl3_ttf_library()
	sdl.Init(sdl.INIT_VIDEO or sdl.INIT_EVENTS)
	defer: sdl.Quit()
	sdl.XTTFInit()
	defer: sdl.XTTFQuit()
	sdl.SetAppMetadata(conf.win_title, conf.app_version, conf.app_id)

	let (win, win_rdr) = sdl.CreateWindowAndRenderer( conf.win_title,
		conf.win_w, conf.win_h, sdl.WINDOW_VULKAN or sdl.WINDOW_RESIZABLE or
			sdl.WINDOW_BORDERLESS or sdl.WINDOW_UTILITY or sdl.WINDOW_TRANSPARENT )
	defer: win_rdr.DestroyRenderer(); win.DestroyWindow()
	win_rdr.SetRenderVSync(true)
	win.SetWindowPosition(conf.win_ox, conf.win_oy)
	let pxfmt = win.GetWindowPixelFormat()
	if pxfmt != sdl.PIXELFORMAT_XRGB8888: warn(
		"Potential issue - window pixel format is expected to always" &
			&" be RGBX8888, but is actually {pxfmt.GetPixelFormatName()}" )

	# XXX: add bg thread that schedules render-UserEvents from NetConns read-loop
	var
		conns = NetConns(conf: conf)
		paint = Painter( conf: conf, win: win, rdr: win_rdr,
			conn_list: (proc (rows: int): seq[ConnInfo] = return conns.conn_list(rows)) )
		running = true
		ev: sdl.Event
	paint.init()
	defer: paint.close()
	assert sdl.PushEvent(ev)
	while running:
		while running and sdl.PollEvent(ev): # XXX: sdl.WaitEvent with render-UserEvents
			case ev.typ
			of sdl.EventType.EVENT_QUIT: running = false; break
			of sdl.EventType.EVENT_USER: break
			else: discard
		# XXX: fps frame delays for render-UserEvent
		paint.draw()
		win_rdr.RenderPresent()

when is_main_module: main(os.commandLineParams())
