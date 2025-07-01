#? replace(sub = "\t", by = "  ")
#
# Debug build/run: nim c -p=nsdl3 -w=on --hints=on -r widget.nim -h
# Final build: nim c -p=nsdl3 -d:release -d:strip -d:lto_incremental --opt:speed -o=leco-sdl-widget widget.nim
# Usage info: ./leco-sdl-widget -h

import std/[ strutils, strformat, parseopt, math, macros,
	os, osproc, monotimes, logging, re, tables, sets, heapqueue ]
import std/[ typedthreads, locks, posix, inotify, json, base64 ]
import nsdl3 as sdl


type Conf = ref object
	win_title = "LECO Network-Monitor Widget"
	win_ox = 20
	win_oy = 40
	win_w = 600
	win_h = 400
	win_px = 0
	win_py = 0
	win_upd_ns: int64
	win_flags = sdl.WINDOW_RESIZABLE or sdl.WINDOW_NOT_FOCUSABLE or
		sdl.WINDOW_BORDERLESS or sdl.WINDOW_TRANSPARENT or sdl.WINDOW_UTILITY
	font_file = ""
	font_h = 14
	line_h = 0 # to be calculated
	line_uid_chars = 3
	line_uid_fmt = "#$1"
	line_fade_ns: int64 = 60 * 1_000_000_000
	line_fade_curve = (y0: 0.0, y1: 100.0, points: @[0.0, 100.0, 100.0, 0.0])
	color_bg = Color(r:0, g:0x0c, b:0, a:0x66)
	color_fg = Color(r:0xff, g:0xff, b:0xff, a:0xff)
	run_fifo = ""
	run_fifo_buff_sz = 200
	run_debug = false
	rx_proc: seq[(Regex, string)]
	rx_group: seq[(Regex, string)]
	app_version = "0.1"
	app_id = "net.fraggod.leco.widget"

var conf_win_flags: Table[string, WindowFlags] # populated at compile-time
macro conf_win_flags_table_init(names: string): untyped =
	result = new_nim_node nnk_stmt_list
	for k in names.str_val.split:
		let c = ident("WINDOW_" & k.to_upper_ascii)
		result.add(quote do: conf_win_flags[`k`] = `c`)
conf_win_flags_table_init( "resizable borderless transparent" &
	" utility always_on_top fullscreen minimized maximized not_focusable" )


{.passl: "-lm"}
{.passl: "build/tinyspline/lib64/libtinyspline.a"}
type
	tsBSpline {.importc, header:"build/tinyspline/include/tinyspline.h".} = object
	tsStatus {.importc, header:"build/tinyspline/include/tinyspline.h".} = object
		code: cint
		message: cstring
{.push importc, header:"build/tinyspline/include/tinyspline.h".}
proc ts_bspline_interpolate_cubic_natural( points: pointer,
	num_points: csize_t, dimensions: csize_t, spline: ptr tsBSpline, status: ptr tsStatus ): cint
proc ts_bspline_free(spline: ptr tsBSpline)
proc ts_bspline_sample( spline: ptr tsBSpline, num: csize_t,
	points: ptr ptr UncheckedArray[cdouble], actual_num: ptr csize_t, status: ptr tsStatus): cint
{.pop.}
proc c_free(mem: pointer) {.header:"<stdlib.h>", importc:"free", nodecl.}


import std/[ bitops, endians ]
func siphash(data: string, key="leco-sdl-widget1", C=2, D=4): string =
	## SipHash-2-4 with 64b/8B output, from/to strings.
	assert key.len == 16
	template key_xor(v: untyped, o: int) = (v = v xor (key[n+o].uint64 shl (n shl 3)))
	template rounds(n: int) = (for _ in 1..n:
		v0 = v0 + v1; v1 = rotate_left_bits(v1, 13); v1 = v1 xor v0
		v0 = rotate_left_bits(v0, 32); v2 = v2 + v3; v3 = rotate_left_bits(v3, 16)
		v3 = v3 xor v2; v0 = v0 + v3; v3 = rotate_left_bits(v3, 21); v3 = v3 xor v0
		v2 = v2 + v1; v1 = rotate_left_bits(v1, 17); v1 = v1 xor v2; v2 = rotate_left_bits(v2, 32))
	var v0, v1, v2, v3, b: uint64
	(v0, v1, v2, v3, b) = ( 0x736f6d6570736575'u64, 0x646f72616e646f6d'u64,
		0x6c7967656e657261'u64, 0x7465646279746573'u64, data.len.uint64 shl 56 )
	for n in 0..7: key_xor(v0, 0); key_xor(v1, 8); key_xor(v2, 0); key_xor(v3, 8)
	let left = data.len and 7
	for n in countup(0, (data.len - 8) - left, 8):
		var m: uint64
		for nn in 0..7: m = m or (data[n+nn].uint64 shl (nn shl 3))
		v3 = v3 xor m; rounds(C); v0 = v0 xor m
	for n in data.len-left .. data.high: b = b or (data[n].uint64 shl ((n and 7) shl 3))
	v3 = v3 xor b; rounds(C); v0 = v0 xor b; v2 = v2 xor 0xff; rounds(D); b = v0 xor v1 xor v2 xor v3
	result = newString(8); littleEndian64(result.cstring, b.addr)


var
	log_lock: Lock
	log_level {.threadvar.}: Level
proc log_init(debug: bool) =
	let lvl = if debug: lvl_debug else: lvl_info
	if log_level != lvl_all: log_level = lvl; return
	var logger = new_console_logger(
		fmt_str="$levelid $datetime :: ", use_stderr=true,
		level_threshold=lvl_all, flush_threshold=lvl_warn )
	add_handler(logger); set_log_filter(log_level); log_level = lvl
template log_msg(lvl: Level, args: varargs[string, `$`]) =
	if log_level <= lvl:
		with_lock log_lock: log(lvl, args)
template log_debug(args: varargs[string, `$`]) = log_msg(lvl_debug, args)
template log_warn(args: varargs[string, `$`]) = log_msg(lvl_warn, args)
template log_error(args: varargs[string, `$`]) = log_msg(lvl_error, args)


var
	sdl_upd_ns: int64
	sdl_upd_lock: Lock
proc sdl_update_set(ts: int64 = -1) {.inline.} =
	## Set timestamp for sdl_update_check, wake up sdl.WaitEvent().
	with_lock sdl_upd_lock: sdl_upd_ns = if ts < 0: get_mono_time().ticks else: ts
	let ev_user = sdl.EventType.EVENT_USER
	if sdl.PeepEvents(ev_user, ev_user) == 0:
		var ev = sdl.Event(typ: ev_user); discard sdl.PushEvent(ev)
proc sdl_update_check(ts: int64 = -1): bool {.inline.} =
	## Check for whether window update/render is needed since ts.
	let ts = if ts < 0: get_mono_time().ticks else: ts
	with_lock sdl_upd_lock: return ts <= sdl_upd_ns


proc parse_conf_file(conf_path: string): Conf =
	var
		conf = Conf()
		re_comm = re"^\s*([#;].*)?$"
		re_name = re"^\s*\[(.*)\]\s*$"
		re_var = re"^\s*(\S.*?)\s*(=\s*(\S.*?)?\s*(\s#\s.*)?)?$"
		line_n = 0
		name = "-top-level-"
		key, val: string
		conf_text_hx = 1.5
		conf_text_gap = 0

	proc parse_curve(val: string): tuple[y0: float, y1: float, points: seq[float]] =
		var
			a, b: float
			ab_set = false
			points: seq[float]
		for s in val.multireplace([("("," "),(")"," "),(","," ")]).split_whitespace():
			if s.startswith("range="):
				let ss = s[6..^1].split(':', 1)
				a = ss[0].parse_float; b = ss[1].parse_float; ab_set = true
			else: points.add(s.parse_float)
		log_debug(&"line-fade-curve: parsed point values = {points}")
		if points.len %% 2 != 0: raise ValueError.new_exception(
			"line-fade-curve: odd number of x-y values, must be even" )
		if a == 0 and b == 0:
			a = points[1]; b = points[^1]
			if a > b: a = b; b = a
		result = (y0: a, y1: b, points: points)
		log_debug(&"line-fade-curve: final shape {result}")

	proc parse_color(val: string): Color =
		let v = val.strip(chars={' ','#'})
		if v.len != 8: raise ValueError.new_exception("rgba: color should be 8 hex-digits")
		let c = v.from_hex[:uint32]
		return Color( r: uint8((c shr 24) and 0xff),
			g: uint8((c shr 16) and 0xff), b: uint8((c shr 8) and 0xff), a: uint8(c and 0xff) )

	template section(sec: string, checks: typed) =
		if name == sec and key != "":
			try: checks
			except ValueError: log_warn( "Failed to parse config" &
				&" value for '{key}' on line {line_n} under [{name}] :: {line}" )
			key = ""
	template section_val_unknown = log_warn(
		&"Ignoring unrecognized config-option line {line_n} under [{name}] :: {line}" )
	for line in (readFile(conf_path) & "\n[end]").split_lines:
		line_n += 1
		if line =~ re_comm: continue
		elif line =~ re_name: name = matches[0]
		elif line =~ re_var:
			key = matches[0].replace("_", "-"); val = matches[2]
			section "window":
				case key:
				of "title": conf.win_title = val
				of "init-offset-left": conf.win_ox = val.parse_int
				of "init-offset-top": conf.win_oy = val.parse_int
				of "init-width": conf.win_w = val.parse_int
				of "init-height": conf.win_h = val.parse_int
				of "pad-x": conf.win_px = val.parse_int
				of "pad-y": conf.win_py = val.parse_int
				of "rgba-bg": conf.color_bg = val.parse_color
				of "rgba-fg": conf.color_fg = val.parse_color
				of "frames-per-second-max":
					let fps = val.parse_float
					if fps > 0: conf.win_upd_ns = int64(1_000_000_000 / fps)
				of "flags":
					conf.win_flags = sdl.WindowFlags 0
					for flag in val.split:
						conf.win_flags = conf.win_flags or conf_win_flags[flag]
				else: section_val_unknown
			section "text":
				case key:
				of "font": conf.font_file = val
				of "font-height": conf.font_h = val.parse_int
				of "line-height":
					if val.contains("."): conf_text_hx = val.parse_float
					elif val.startswith("+"): conf_text_gap = val[1 .. ^1].parse_int
					else: conf_text_hx = val.parse_float * -1
				of "line-fade-time": conf.line_fade_ns = int64(val.parse_float * 1e9)
				of "line-fade-curve": conf.line_fade_curve = val.parse_curve
				of "line-uid-chars": conf.line_uid_chars = val.parse_int
				of "line-uid-fmt": conf.line_uid_fmt = val
				else: section_val_unknown
			section "run":
				case key:
				of "fifo": conf.run_fifo = val
				of "conn-list-cache": conf.run_fifo_buff_sz = val.parse_int
				of "debug": conf.run_debug = case val
					of "y","yes","true","1","on": true
					of "n","no","false","0","off": false
					else: raise ValueError.new_exception("Unrecognized boolean value")
				else: section_val_unknown
			if name == "rx-proc" or name == "rx-group":
				var re_flags = {re_study, re_ignore_case}
				if key.startswith("i:"): key = key.substr(2)
				elif key.startswith("I:"): key = key.substr(2); re_flags.excl(re_ignore_case)
				if val.startswith("\\ "): val = val.substr(1)
				if val.endswith(" \\"): val = val[0 .. ^2]
				let t = (re(key, re_flags), val); key = ""
				if name == "rx-proc": conf.rx_proc.add t else: conf.rx_group.add t
			if key != "": log_warn( "Unrecognized config" &
				&" section [{name}] for '{key}' value on line {line_n} :: {line}" )
		else: log_warn(&"Failed to parse config-file line {line_n} :: {line}")
	if conf.line_h == 0:
		if conf_text_gap != 0: conf.line_h = conf.font_h + conf_text_gap
		elif conf_text_hx >= 0: conf.line_h = int(conf.font_h.float * conf_text_hx)
		else: conf.line_h = int(conf_text_hx)
	return conf


type
	CNS = int64 # nanoseconds-based connection ID
	ConnInfo = tuple
		ns: CNS
		group: string
		ns_trx: int64
		line: string
	ConnInfoBuffer = ptr object
		n, m, gen: int # list = [n, m) + [0, n)
		buff: UncheckedArray[ConnInfo]

var # updated from fifo-conn-reader thread to use by NetConns
	conn_buff: ConnInfoBuffer
	conn_buff_lock: Lock

proc sub(rx: Regex, by: string, s: string): tuple[match: bool, s: string] =
  ## Similar to re.replacef, but also returns whether regexp matched anything.
  var pos = 0; var caps: array[re.MaxSubpatterns, string]
	while pos < s.len:
		let m = s.findBounds(rx, caps, pos)
		if m.first < 0: break
		result.match = true
		result.s.add s.substr(pos, m.first-1)
		result.s.addf(by, caps)
		if m.last + 1 == pos: break
		pos = m.last + 1
	result.s.add s.substr(pos)

proc conn_reader(conf: Conf) {.thread, gcsafe.} =
	## Daemon thread that populates conn_buff.
	log_init(conf.run_debug) # logging setup is thread-local
	var
		fifo: File
		fifo_dir = conf.run_fifo.parent_dir
		n = 0
		conn: ConnInfo
	while true:
		block fifo_inotify_open:
			try: fifo = open(conf.run_fifo, fm_read); break fifo_inotify_open
			except IOError as e: log_debug(&"fifo: [ {e.msg} ] - will wait for it")
			var ino_fd = inotify_init()
			defer:
				if close(ino_fd.cint) != 0:
					raise IOError.new_exception("fifo: inotify close failed")
			let wd = ino_fd.inotify_add_watch( fifo_dir.cstring,
				IN_OPEN or IN_CREATE or IN_MOVED_TO or IN_ATTRIB )
			defer: discard ino_fd.inotify_rm_watch(wd)
			var ino_evs: array[2048, byte]
			while true:
				if n == 0:
					try: fifo = open(conf.run_fifo, fm_read); break
					except IOError as e: log_debug(&"fifo: [ {e.msg} ] - waiting for it")
				n = read(ino_fd, ino_evs.addr, 2048)
				if n <= 0: raise IOError.new_exception("fifo: inotify read failed")
				for e in inotify_events(ino_evs.addr, n):
					let name = $cast[cstring](e[].name.addr)
					if conf.run_fifo.extract_filename != name.extract_filename: continue
					log_debug(&"fifo: create/change event detected for [ {name} ]")
					n = 0; break
		defer: fifo.close()
		log_debug("fifo: connected")
		for ev in fifo.lines:
			if ev.strip.len == 0: continue
			log_debug(&"fifo: {ev}")
			try:
				let ej = ev.parse_json
				conn = ( ns: ej["ns"].getBiggestInt.CNS, group: "",
					ns_trx: ej["ns_trx"].getBiggestInt.int64, line: ej["line"].getStr )
			except ValueError as e:
				log_error(&"fifo: failed to decode event :: {e.msg} :: [ {ev} ]")
				continue
			var res: tuple[match: bool, s: string]
			for (rx, tpl) in conf.rx_group:
				res = rx.sub(tpl, conn.line)
				if not res.match: continue
				if res.s != "": conn.group = res.s
				break
			if res.match and res.s == "": continue # empty group = drop line
			for (rx, tpl) in conf.rx_proc: conn.line = conn.line.replacef(rx, tpl)
			with_lock conn_buff_lock:
				conn_buff.buff[conn_buff.n] = conn
				if conn_buff.m < conf.run_fifo_buff_sz: conn_buff.m += 1
				conn_buff.n = (conn_buff.n + 1) %% conf.run_fifo_buff_sz
				conn_buff.gen = (conn_buff.gen + 1) %% 1_073_741_824
			sdl_update_set()


{.push base.}

type
	NetConn = tuple # ConnInfo without internal fields for NetConns
		ns: CNS
		ns_trx: int64
		line: string
	NetConns = object
		list_last: (int, int, int)
		group_ns: Table[string, CNS] # oldest ns value used for group-slots

proc list(o: var NetConns, limit: int, cache_cookie: int = 0): seq[NetConn] =
	## Returns specified number of last-changed connections to display in a window.
	var ns: CNS; var line: string; var groups: HashSet[string]
	template append =
		if result.len >= limit: break
		let ev = conn_buff.buff[n]
		ns = ev.ns; line = substr(ev.line) # make sure to not ref strings shared with thread
		if ev.group != "":
			if groups.contains(ev.group): continue # only one conn per group is needed
			if o.group_ns.has_key_or_put(ev.group, ev.ns): ns = o.group_ns[ev.group]
			groups.incl(ev.group)
		result.add (ns: ns, ns_trx: ev.ns_trx, line: line)
	with_lock conn_buff_lock:
		if o.list_last == (conn_buff.gen, limit, cache_cookie): return result # no changes
		for n in countdown(conn_buff.n-1, 0): append
		for n in countdown(conn_buff.m-1, conn_buff.n+1): append
		o.list_last = (conn_buff.gen, limit, cache_cookie)
	var groups_del: seq[string]
	for group in o.group_ns.keys():
		if not groups.contains(group): groups_del.add(group)
	for group in groups_del: o.group_ns.del(group)

type
	Painter = object
		conf: Conf
		conn_list: proc (limit, cache_n: int): seq[NetConn] # empty result for "no changes"
		win: Window
		rdr: Renderer
		tex: Texture
		txt_font: Font
		txt_engine: TextEngine
		txt: Text
		ww, wh, tw, th, oy, uid_w: int
		rows_draw = 0
		rows: Table[CNS, PaintedRow]
		fade_out: seq[(int64, byte)] # (td[0..fade_ns], alpha) changes
		closed = false
	PaintedRow = ref object
		n: int
		ns: CNS
		ns_trx: int64
		ts_update: int64
		uid: string
		uid_color: Color
		line: string
		fade_out_n = 0
		listed = true
		replaced = true

proc `<`(a, b: PaintedRow): bool =
	## Used to pick "oldest" row to replace visually.
	## Ones not "listed" in conn_list are replaced before ones that still are.
	if a.listed and not b.listed: false
	elif b.listed and not a.listed: true
	elif a.ts_update != b.ts_update: a.ts_update < b.ts_update
	else: a.ns < b.ns

method init_fade_timeline(o: var Painter): seq[(int64, byte)] =
	let
		pts = o.conf.line_fade_curve.points
		y0 = o.conf.line_fade_curve.y0
		ys = o.conf.line_fade_curve.y1 - y0
		x0 = pts[0]
		xs = pts[^2] - x0
		xns = o.conf.line_fade_ns
	var
		points_ptr = alloc(pts.len * float.sizeof)
		points = cast[ptr UncheckedArray[cdouble]](points_ptr)
		s: tsBSpline
		st: tsStatus
		samples_ptr: ptr UncheckedArray[cdouble]
		samples_n = csize_t((o.conf.line_fade_ns div 1_000_000) div 30) # ~30fps
		a0: byte
	defer: dealloc(points_ptr)
	for n in 0 ..< pts.len: points[n] = pts[n] # seq -> array
	discard ts_bspline_interpolate_cubic_natural(
		points_ptr, csize_t(pts.len div 2), 2, s.addr, st.addr )
	if st.code == 0:
		defer: ts_bspline_free(s.addr)
		discard ts_bspline_sample(
			s.addr, samples_n, samples_ptr.addr, samples_n.addr, st.addr )
	if st.code != 0: raise ValueError.new_exception(
		"Failed to interpolate/sample line-fade-curve [{st.code}]: {st.message}" )
	defer: c_free(samples_ptr)
	let ss = cast[ptr UncheckedArray[cdouble]](samples_ptr[])
	for n in countup(0, (samples_n.int - 1) * 2, 2):
		let a = round(255 * ((ss[n+1] - y0) / ys).clamp(0, 1.0)).byte
		# echo &"{ss[n]} {ss[n+1]}" # https://www.graphreader.com/plotter can plot this
		if result.len > 0 and a == a0: continue
		a0 = a; result.add((int64(float(xns) * (ss[n] - x0) / xs).clamp(0, xns), a))

method init(o: var Painter) =
	o.txt_font = sdl.OpenFont(o.conf.font_file, o.conf.font_h)
	o.txt_engine = sdl.CreateRendererTextEngine(o.rdr)
	o.txt = o.txt_engine.CreateText(o.txt_font, "", 0)
	o.txt.SetTextColor(o.conf.color_fg)
	(o.uid_w, _) = o.txt_font.GetStringSize( # W should be widest base64 letter
		o.conf.line_uid_fmt % "W".repeat(o.conf.line_uid_chars) )
	o.fade_out = o.init_fade_timeline()

method close(o: var Painter) =
	if o.closed: return
	o.txt.DestroyText()
	o.txt_engine.DestroyRendererTextEngine()
	o.txt_font.CloseFont()
	o.closed = true

method check_texture(o: var Painter): bool =
	## (Re-)Create texture matching window size, to (re-)render all text onto.
	## Returns true if fresh texture was created.
	var w, h: int
	o.win.GetWindowSize(w, h)
	if not o.tex.isNil:
		if w == o.ww and h == o.wh: return false
		o.tex.DestroyTexture()
	o.ww = w; o.wh = h
	w -= 2*o.conf.win_px; h -= 2*o.conf.win_px;
	o.tex = o.rdr.CreateTexture(
		sdl.PIXELFORMAT_ARGB8888, sdl.TEXTUREACCESS_TARGET, w, h )
	o.rdr.SetRenderTarget(o.tex); o.rdr.RenderClear()
	o.tex.SetTextureBlendMode(sdl.BLENDMODE_BLEND)
	o.tw = w; o.th = h
	o.oy = o.conf.line_h - o.conf.font_h
	o.rows_draw = (h - o.oy) div o.conf.line_h
	o.oy += ((h - o.oy) - o.rows_draw * o.conf.line_h) div o.rows_draw
	o.rows.clear() # put up all fresh rows
	return true

method row_uid(o: Painter, ns: CNS): (string, Color) =
	let
		uid_str = siphash($ns)
		uid = o.conf.line_uid_fmt % uid_str.encode(safe=true)[0 .. o.conf.line_uid_chars]
		uid_color = Color(r:uid_str[0].byte, g:uid_str[1].byte, b:uid_str[2].byte, a:255)
	return (uid, uid_color)

method row_updates(o: var Painter, ts: int64): seq[PaintedRow] =
	## Returns updated/replaced rows that need to be repainted.
	## For new conns, replaces oldest rows without a matching conn first.
	var
		conns_new: seq[NetConn]
		r: PaintedRow
	let conn_list = o.conn_list(o.rows_draw, o.rows.len)
	if conn_list.len == 0: return result # no conns or no changes since last call
	for r in o.rows.mvalues: r.listed = false; r.replaced = false
	for conn in conn_list:
		if o.rows.contains(conn.ns):
			r = o.rows[conn.ns]; if r.listed: continue
			r.listed = true # heap-sorts these last for replacement
			if conn.ns_trx > r.ns_trx:
				r.ns_trx = conn.ns_trx; r.line = conn.line; r.ts_update = ts; result.add(r)
			continue
		conns_new.add(conn)
	if conns_new.len == 0: return result
	var rows_replace = initHeapQueue[PaintedRow]()
	for r in o.rows.mvalues: rows_replace.push(r)
	for conn in conns_new:
		if o.rows.len < o.rows_draw: # new row
			r = PaintedRow(n: o.rows.len)
		elif rows_replace.len != 0: # replace row
			r = rows_replace.pop; o.rows.del(r.ns); r.replaced = true
		else: log_debug(&"draw: no slot for new conn {conn}"); continue
		r.ns = conn.ns; r.ns_trx = r.ns_trx; r.line = conn.line; r.ts_update = ts
		(r.uid, r.uid_color) = o.row_uid(conn.ns)
		o.rows[conn.ns] = r; result.add(r)

method draw(o: var Painter): bool =
	## Clear/update window contents buffer, returns true if there are any changes.
	## Maintains single texture with all text lines in the right places,
	##   and copies those to window with appropriate effects applied per-frame.
	let
		ts = get_mono_time().ticks
		new_texture = o.check_texture()

	# Update any new/changed rows on the texture
	var updates = o.row_updates(ts)
	for row in updates.mitems:
		row.fade_out_n = 0
		var y = row.n * o.conf.line_h
		o.rdr.SetRenderTarget(o.tex)
		if not new_texture: # no need to cleanup if it's fresh
			let x = if row.replaced: 0 else: o.uid_w
			o.rdr.SetRenderDrawBlendMode(sdl.BLENDMODE_NONE)
			o.rdr.SetRenderDrawColor(0, 0, 0, 0)
			o.rdr.RenderFillRect(x, y, o.tw - x, o.conf.line_h)
		y += o.oy
		if row.replaced:
			o.txt.SetTextColor(row.uid_color)
			o.txt.SetTextString(row.uid)
			o.txt.DrawRendererText(0, y)
			o.txt.SetTextColor(o.conf.color_fg)
		o.txt.SetTextString(row.line)
		o.txt.DrawRendererText(o.uid_w, y)
		result = true
		log_debug( "Row " &
			(if row.replaced: "replace" else: "update") &
			&": #{row.n} :: {row.uid} {row.line}" )

	# Prepare main output buffer
	o.rdr.SetRenderTarget()
	o.rdr.SetRenderDrawBlendMode(sdl.BLENDMODE_NONE)
	o.rdr.SetRenderDrawColor(o.conf.color_bg)
	o.rdr.RenderClear()

	# Copy rows from texture, with per-row alpha/effects
	o.rdr.SetRenderDrawBlendMode(sdl.BLENDMODE_BLEND)
	let fade_ns = o.fade_out.len - 1
	for row in o.rows.mvalues:
		if row.fade_out_n < fade_ns:
			let td = ts - row.ts_update
			if td >= o.conf.line_fade_ns: row.fade_out_n = fade_ns
			while row.fade_out_n < fade_ns and
				o.fade_out[row.fade_out_n+1][0] < td: row.fade_out_n += 1
			result = true
		let alpha = o.fade_out[row.fade_out_n][1]
		if alpha == 0: continue
		let y = row.n * o.conf.line_h
		o.tex.SetTextureAlphaMod(alpha)
		o.rdr.RenderTexture( o.tex,
			0, y, o.tw, o.conf.line_h, o.conf.win_px,
			o.conf.win_py + y, o.tw, o.conf.line_h )

{.pop.}


proc main_help(err="") =
	proc print(s: string) =
		let dst = if err == "": stdout else: stderr
		write(dst, s); write(dst, "\n")
	let app = get_app_filename().last_path_part
	if err != "": print &"ERROR: {err}"
	print &"\nUsage: {app} [options] <config.ini>"
	if err != "": print &"Run '{app} --help' for more information"; quit 1
	print dedent(&"""

		Graphical SDL3 UI tool, to read network information/events
			from leco-event-pipe output fifo socket, and render those
			as fading text lines to a semi-transparent desktop window.
		Intended to run indefinitely as a desktop network-monitoring widget.
		Options specified on the command line override ones in the ini configuration file.

		Arguments and options (in "{app} [options] [config.ini]" command):

			<config.ini>
				Configuration ini-file to read. See example in the repository for all options.

			-f/--fifo <path>
				Path to an input FIFO socket, used by leco-event-pipe script for its output.
				Can be initially missing/inaccessible, tool will wait for it.
				Must be specified either in configuration file, or with this option.

			-d/--debug - enable verbose logging to stderr, incl. during config file loading.
		""")
	quit 0

proc main(argv: seq[string]) =
	var
		conf = Conf()
		opt_conf_file = ""
		opt_fifo_path = ""
		opt_debug = false

	block cli_parser:
		var opt_last = ""
		proc opt_fmt(opt: string): string =
			if opt.len == 1: &"-{opt}" else: &"--{opt}"
		proc opt_empty_check =
			if opt_last == "": return
			main_help &"{opt_fmt(opt_last)} option unrecognized or requires a value"
		proc opt_set(k: string, v: string) =
			if k in ["f", "fifo"]: opt_fifo_path = v
			else: main_help &"Unrecognized option [ {opt_fmt(k)} = {v} ]"
		for t, opt, val in getopt(argv):
			case t
			of cmd_end: break
			of cmd_short_option, cmd_long_option:
				if opt in ["h", "help"]: main_help()
				elif opt in ["d", "debug"]: opt_debug = true
				elif val == "": opt_empty_check(); opt_last = opt
				else: opt_set(opt, val)
			of cmd_argument:
				if opt_last != "": opt_set(opt_last, opt); opt_last = ""
				elif opt_conf_file == "": opt_conf_file = opt
				else: main_help(&"Unrecognized argument: {opt}")
		opt_empty_check()

	log_init(opt_debug)
	if opt_conf_file != "": conf = parse_conf_file(opt_conf_file)
	if opt_debug and not conf.run_debug: conf.run_debug = true
	elif conf.run_debug and not opt_debug: log_init(conf.run_debug)
	if opt_fifo_path != "": conf.run_fifo = opt_fifo_path
	if conf.run_fifo == "": main_help "Input FIFO path must be set via config/option"
	if conf.line_h == 0: conf.line_h = int(conf.font_h.float * 1.5)

	if conf.font_file == "":
		let fc_lookup = "sans:lang=en"
		log_warn( "No font path specified for text.font option, trying" &
			&" to find one via 'fc-match {fc_lookup}' command (fontconfig)" )
		conf.font_file = exec_process( "fc-match",
			args=["-f", "%{file}", fc_lookup], options={po_use_path} ).strip
	else: conf.font_file = conf.font_file.expandTilde()

	if not (sdl.open_sdl3_library() and sdl.open_sdl3_ttf_library()):
		raise SDLError.new_exception("Failed to open sdl3/sdl3_ttf libs")
	defer: sdl.close_sdl3_library(); sdl.close_sdl3_ttf_library()
	sdl.Init(sdl.INIT_VIDEO or sdl.INIT_EVENTS); defer: sdl.Quit()
	sdl.XTTFInit(); defer: sdl.XTTFQuit()
	sdl.SetAppMetadata(conf.win_title, conf.app_version, conf.app_id)
	sdl.EnableScreenSaver() # gets disabled by default

	let (win, win_rdr) = sdl.CreateWindowAndRenderer( conf.win_title,
		conf.win_w, conf.win_h, sdl.WINDOW_VULKAN or conf.win_flags )
	defer: win_rdr.DestroyRenderer(); win.DestroyWindow()
	win_rdr.SetRenderVSync(true)
	win.SetWindowPosition(conf.win_ox, conf.win_oy)
	let pxfmt = win.GetWindowPixelFormat()
	if pxfmt != sdl.PIXELFORMAT_XRGB8888: log_warn(
		"Potential issue - window pixel format is expected to always" &
			&" be XRGB8888, but is actually {pxfmt.GetPixelFormatName()}" )

	conn_buff = cast[ConnInfoBuffer](alloc_shared0(
		sizeof(ConnInfoBuffer) + sizeof(ConnInfo) * conf.run_fifo_buff_sz ))
	conn_buff_lock.init_lock(); defer: conn_buff_lock.release()
	var fifo_reader: Thread[Conf]
	fifo_reader.create_thread(conn_reader, conf)

	var
		conns = NetConns()
		paint = Painter( conf: conf, win: win, rdr: win_rdr,
			conn_list: (proc (rows, cache_n: int): seq[NetConn] = conns.list(rows, cache_n)) )
	paint.init(); defer: paint.close()

	var
		running = true
		ev_upd = false
		ev: sdl.Event
		ts_render: int64
	template ev_proc =
		case ev.typ
		of sdl.EventType.EVENT_QUIT: running = false; ev_upd = true; break
		of sdl.EventType.EVENT_USER: ev_upd = true
		of sdl.EventType.EVENT_WINDOW_MOUSE_ENTER: discard
		of sdl.EventType.EVENT_WINDOW_MOUSE_LEAVE: discard
		elif ( ev.typ >= sdl.EventType.EVENT_DISPLAY_RMIN and
					ev.typ <= sdl.EventType.EVENT_DISPLAY_RMAX ) or
				( ev.typ >= sdl.EventType.EVENT_WINDOW_RMIN and
					ev.typ <= sdl.EventType.EVENT_WINDOW_RMAX ):
			ev_upd = true; sdl_update_set() # redraw for display/win changes
		else: discard # key/mouse events, etc
	sdl_update_set()
	while running and fifo_reader.running:
		while sdl.WaitEvent(ev): # blocks when redraw isn't needed
			ev_upd = false; ev_proc
			while sdl.PollEvent(ev): ev_proc
			if ev_upd: break
		if paint.draw(): sdl_update_set()

		if not sdl_update_check(ts_render): continue
		let td = conf.win_upd_ns - (get_mono_time().ticks - ts_render)
		if td > 0: sleep(td div 1_000 - 1) # vsync-independent frame delay
		win_rdr.RenderPresent()
		ts_render = get_mono_time().ticks

when is_main_module: main(os.command_line_params())
