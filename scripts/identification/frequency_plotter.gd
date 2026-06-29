extends Control
class_name FrequencyPlotter

## ============================================================
## Bode 图绘制器
##
## 三行子图垂直排列：
##   1. 幅频图 (dB vs log f)
##   2. 相频图 (deg vs log f)
##   3. 相干函数 (γ² vs log f)
##
## 用法：
##   plotter.set_data(freqs, H_mag, H_phase, coh)
##   plotter.queue_redraw()
## ============================================================

var _freqs: PackedFloat64Array = []
var _H_mag: PackedFloat64Array = []       # 线性幅值
var _H_phase: PackedFloat64Array = []     # 弧度
var _coh: PackedFloat64Array = []         # 0~1

## 显示范围（频率对数轴）
var f_min: float = 0.1
var f_max: float = 100.0
var mag_min_db: float = -60.0
var mag_max_db: float = 20.0

## 相干阈值（低于此值的点半透明显示）
var coh_threshold: float = 0.5

# ───────── 颜色（暗主题） ─────────
const COL_BG: Color = Color(0.10, 0.10, 0.12)
const COL_GRID: Color = Color(0.25, 0.25, 0.28)
const COL_GRID_MAJOR: Color = Color(0.38, 0.38, 0.42)
const COL_AXIS: Color = Color(0.55, 0.55, 0.58)
const COL_TEXT: Color = Color(0.75, 0.75, 0.78)
const COL_MAG: Color = Color(0.20, 0.80, 1.00)    # 青色
const COL_PHASE: Color = Color(1.00, 0.60, 0.20)  # 橙色
const COL_COH: Color = Color(0.30, 0.90, 0.40)    # 绿色
const COL_COH_BAD: Color = Color(0.90, 0.40, 0.30, 0.35)
const COL_THRESH: Color = Color(0.80, 0.40, 0.20, 0.4)

## 子图布局
const MAG_RATIO: float = 0.42
const PHASE_RATIO: float = 0.30
const COH_RATIO: float = 0.28
const SUB_GAP: float = 8.0
const MARGIN_L: float = 52.0
const MARGIN_R: float = 12.0
const MARGIN_T: float = 12.0
const MARGIN_B: float = 22.0


func set_data(freqs: PackedFloat64Array, H_mag: PackedFloat64Array, H_phase: PackedFloat64Array, coh: PackedFloat64Array) -> void:
	_freqs = freqs.duplicate()
	_H_mag = H_mag.duplicate()
	_H_phase = H_phase.duplicate()
	_coh = coh.duplicate()
	# 自动适配频率范围（跳过 DC）
	if freqs.size() > 2:
		f_min = max(0.001, freqs[1])
		f_max = freqs[freqs.size() - 1]
	_auto_fit_mag()
	queue_redraw()


func clear_data() -> void:
	_freqs.resize(0)
	_H_mag.resize(0)
	_H_phase.resize(0)
	_coh.resize(0)
	queue_redraw()


func _auto_fit_mag() -> void:
	if _H_mag.is_empty():
		return
	var min_db: float = 1e9
	var max_db: float = -1e9
	for k in _freqs.size():
		if _freqs[k] < f_min or _freqs[k] > f_max:
			continue
		if _coh[k] < coh_threshold:
			continue
		var db := 20.0 * log(max(_H_mag[k], 1e-10)) / log(10.0)
		min_db = min(min_db, db)
		max_db = max(max_db, db)
	if min_db > max_db:
		return
	var margin: float = 10.0
	mag_min_db = floor(min_db / 20.0) * 20.0 - margin
	mag_max_db = ceil(max_db / 20.0) * 20.0 + margin


func _draw() -> void:
	var W: float = size.x
	var H_total: float = size.y
	if W < 80 or H_total < 80:
		return

	var plot_w: float = W - MARGIN_L - MARGIN_R
	var plot_h: float = H_total - MARGIN_T - MARGIN_B
	var h_mag: float = plot_h * MAG_RATIO
	var h_phase: float = plot_h * PHASE_RATIO
	var h_coh: float = plot_h * COH_RATIO

	var mag_rect := Rect2(MARGIN_L, MARGIN_T, plot_w, h_mag)
	var phase_rect := Rect2(MARGIN_L, MARGIN_T + h_mag + SUB_GAP, plot_w, h_phase)
	var coh_rect := Rect2(MARGIN_L, MARGIN_T + h_mag + SUB_GAP + h_phase + SUB_GAP, plot_w, h_coh)

	# 背景
	draw_rect(Rect2(0, 0, W, H_total), COL_BG)

	_draw_mag_plot(mag_rect)
	_draw_phase_plot(phase_rect)
	_draw_coh_plot(coh_rect)


# ─────────────────── 幅频图 ───────────────────

func _draw_mag_plot(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var fs: int = 10

	# 网格 + 刻度
	_draw_freq_grid(rect)
	var db_ticks := _get_linear_ticks(mag_min_db, mag_max_db, 20.0)
	for db in db_ticks:
		var y: float = _db_to_y(db, rect.position.y, rect.size.y)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + rect.size.x, y), COL_GRID, 1.0)
		draw_string(font, Vector2(rect.position.x - 4, y + 3), "%d" % db, HORIZONTAL_ALIGNMENT_RIGHT, -1, fs, COL_TEXT)

	# 标签
	draw_string(font, Vector2(rect.position.x + rect.size.x / 2 - 30, rect.position.y - 2), "Magnitude (dB)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_TEXT)

	# 数据曲线
	_draw_mag_curve(rect)


func _draw_mag_curve(rect: Rect2) -> void:
	if _freqs.size() < 2:
		return
	var pts_good := PackedVector2Array()
	var pts_bad := PackedVector2Array()
	for k in _freqs.size():
		if _freqs[k] < f_min or _freqs[k] > f_max or _freqs[k] <= 0:
			continue
		var x: float = _freq_to_x(_freqs[k], rect.position.x, rect.size.x)
		var db: float = 20.0 * log(max(_H_mag[k], 1e-10)) / log(10.0)
		var y: float = _db_to_y(db, rect.position.y, rect.size.y)
		y = clamp(y, rect.position.y, rect.position.y + rect.size.y)
		if _coh[k] >= coh_threshold:
			pts_good.append(Vector2(x, y))
		else:
			pts_bad.append(Vector2(x, y))
	if pts_bad.size() >= 2:
		draw_polyline(pts_bad, COL_COH_BAD, 1.0, true)
	if pts_good.size() >= 2:
		draw_polyline(pts_good, COL_MAG, 1.5, true)


# ─────────────────── 相频图 ───────────────────

func _draw_phase_plot(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var fs: int = 10

	_draw_freq_grid(rect)
	# 相位刻度 -180 ~ 180，步进 90
	for deg in [-180, -90, 0, 90, 180]:
		var y: float = _phase_to_y(deg, rect.position.y, rect.size.y)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + rect.size.x, y), COL_GRID, 1.0)
		draw_string(font, Vector2(rect.position.x - 4, y + 3), "%d°" % deg, HORIZONTAL_ALIGNMENT_RIGHT, -1, fs, COL_TEXT)

	draw_string(font, Vector2(rect.position.x + rect.size.x / 2 - 25, rect.position.y - 2), "Phase (deg)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_TEXT)
	_draw_phase_curve(rect)


func _draw_phase_curve(rect: Rect2) -> void:
	if _freqs.size() < 2:
		return
	var pts_good := PackedVector2Array()
	var pts_bad := PackedVector2Array()
	for k in _freqs.size():
		if _freqs[k] < f_min or _freqs[k] > f_max or _freqs[k] <= 0:
			continue
		var x: float = _freq_to_x(_freqs[k], rect.position.x, rect.size.x)
		var deg: float = rad_to_deg(_H_phase[k])
		var y: float = _phase_to_y(deg, rect.position.y, rect.size.y)
		y = clamp(y, rect.position.y, rect.position.y + rect.size.y)
		if _coh[k] >= coh_threshold:
			pts_good.append(Vector2(x, y))
		else:
			pts_bad.append(Vector2(x, y))
	if pts_bad.size() >= 2:
		draw_polyline(pts_bad, COL_COH_BAD, 1.0, true)
	if pts_good.size() >= 2:
		draw_polyline(pts_good, COL_PHASE, 1.5, true)


# ─────────────────── 相干图 ───────────────────

func _draw_coh_plot(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var fs: int = 10

	_draw_freq_grid(rect)
	# 相干刻度 0, 0.5, 1.0
	for c in [0.0, 0.5, 1.0]:
		var y: float = _coh_to_y(c, rect.position.y, rect.size.y)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + rect.size.x, y), COL_GRID, 1.0)
		draw_string(font, Vector2(rect.position.x - 4, y + 3), "%.1f" % c, HORIZONTAL_ALIGNMENT_RIGHT, -1, fs, COL_TEXT)

	# 阈值线
	var y_th: float = _coh_to_y(coh_threshold, rect.position.y, rect.size.y)
	draw_line(Vector2(rect.position.x, y_th), Vector2(rect.position.x + rect.size.x, y_th), COL_THRESH, 1.0, true)

	draw_string(font, Vector2(rect.position.x + rect.size.x / 2 - 35, rect.position.y - 2), "Coherence γ²", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_TEXT)
	_draw_coh_curve(rect)


func _draw_coh_curve(rect: Rect2) -> void:
	if _freqs.size() < 2:
		return
	var pts := PackedVector2Array()
	for k in _freqs.size():
		if _freqs[k] < f_min or _freqs[k] > f_max or _freqs[k] <= 0:
			continue
		var x: float = _freq_to_x(_freqs[k], rect.position.x, rect.size.x)
		var y: float = _coh_to_y(_coh[k], rect.position.y, rect.size.y)
		pts.append(Vector2(x, y))
	if pts.size() >= 2:
		draw_polyline(pts, COL_COH, 1.5, true)


# ─────────────────── 共用：频率网格 ───────────────────

func _draw_freq_grid(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var fs: int = 9
	# 频率刻度（对数）
	var ticks := _get_log_ticks(f_min, f_max)
	for i in ticks.size():
		var f: float = ticks[i]
		var x: float = _freq_to_x(f, rect.position.x, rect.size.x)
		var is_major: bool = _is_decade(f)
		var col: Color = COL_GRID_MAJOR if is_major else COL_GRID
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + rect.size.y), col, 1.0)
		# 只在最底层子图画频率标签
		if rect.position.y + rect.size.y > size.y - MARGIN_B - 5:
			var label: String = _format_freq(f)
			draw_string(font, Vector2(x - 12, rect.position.y + rect.size.y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_TEXT)
	# 边框
	draw_rect(rect, COL_AXIS, false, 1.0)


# ─────────────────── 坐标变换 ───────────────────

func _freq_to_x(f: float, x0: float, w: float) -> float:
	var log_f: float = log(f) / log(10.0)
	var log_min: float = log(f_min) / log(10.0)
	var log_max: float = log(f_max) / log(10.0)
	return x0 + (log_f - log_min) / (log_max - log_min) * w


func _db_to_y(db: float, y0: float, h: float) -> float:
	return y0 + h * (1.0 - (db - mag_min_db) / (mag_max_db - mag_min_db))


func _phase_to_y(deg: float, y0: float, h: float) -> float:
	return y0 + h * (1.0 - (deg + 180.0) / 360.0)


func _coh_to_y(c: float, y0: float, h: float) -> float:
	return y0 + h * (1.0 - c)


# ─────────────────── 刻度生成 ───────────────────

func _get_log_ticks(f_lo: float, f_hi: float) -> PackedFloat64Array:
	var ticks := PackedFloat64Array()
	var d_start: float = pow(10.0, floor(log(f_lo) / log(10.0)))
	var d: float = d_start
	while d <= f_hi * 1.01:
		for mult in [1.0, 2.0, 5.0]:
			var f: float = d * mult
			if f >= f_lo * 0.99 and f <= f_hi * 1.01:
				ticks.append(f)
		d *= 10.0
	return ticks


func _is_decade(f: float) -> bool:
	var lg: float = log(f) / log(10.0)
	return abs(lg - round(lg)) < 0.01


func _get_linear_ticks(v_min: float, v_max: float, step: float) -> PackedFloat64Array:
	var ticks := PackedFloat64Array()
	var v: float = ceil(v_min / step) * step
	while v <= v_max + 0.001:
		ticks.append(v)
		v += step
	return ticks


func _format_freq(f: float) -> String:
	# GDScript 不支持 %g，手动处理
	if f >= 1000.0:
		return "%.0fk" % (f / 1000.0)
	elif f >= 1.0:
		return "%.0f" % f
	else:
		return "%.2f" % f
