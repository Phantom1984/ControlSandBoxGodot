extends Control
class_name Plotter

## 实时曲线图，可显示多条曲线

@export var background_color: Color = Color(0.1, 0.1, 0.15, 1.0)
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var axis_color: Color = Color(0.8, 0.8, 0.8, 1.0)
@export var label_color: Color = Color(0.9, 0.9, 0.9, 1.0)

# 每条曲线独立存储数据
var curves: Dictionary = {}

const MAX_POINTS = 500
const MARGIN_LEFT = 55.0
const MARGIN_RIGHT = 20.0
const MARGIN_TOP = 20.0
const MARGIN_BOTTOM = 45.0


func add_curve(name: String, color: Color):
	curves[name] = {"color": color, "data": []}


func remove_curve(name: String):
	curves.erase(name)


func add_point(curve_name: String, t: float, value: float):
	if not curves.has(curve_name):
		return
	curves[curve_name]["data"].append({"time": t, "value": value})
	if curves[curve_name]["data"].size() > MAX_POINTS:
		curves[curve_name]["data"].pop_front()
	queue_redraw()


func clear_curve(name: String):
	if curves.has(name):
		curves[name]["data"].clear()
	queue_redraw()


func clear_all():
	for key in curves:
		curves[key]["data"].clear()
	queue_redraw()


func _nice_step(rough_step: float) -> float:
	if rough_step <= 0:
		return 1.0
	var exponent = floor(log(rough_step) / log(10.0))
	var fraction = rough_step / pow(10.0, exponent)
	var nice: float
	if fraction <= 1.0:
		nice = 1.0
	elif fraction <= 2.0:
		nice = 2.0
	elif fraction <= 5.0:
		nice = 5.0
	else:
		nice = 10.0
	return nice * pow(10.0, exponent)


func _get_decimals(v_range: float) -> int:
	if v_range >= 100:
		return 0
	elif v_range >= 10:
		return 1
	elif v_range >= 1:
		return 2
	elif v_range >= 0.1:
		return 3
	else:
		return 4


func _gui_input(event: InputEvent):
	if event is InputEventMouseMotion:
		queue_redraw()


func _draw():
	# 背景
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	if curves.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(50, size.y / 2), "等待数据...",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, label_color)
		return

	# 计算全局范围
	var t_min = INF
	var t_max = -INF
	var v_min = INF
	var v_max = -INF

	for key in curves:
		for pt in curves[key]["data"]:
			t_min = min(t_min, pt["time"])
			t_max = max(t_max, pt["time"])
			v_min = min(v_min, pt["value"])
			v_max = max(v_max, pt["value"])

	if t_min == INF:
		return

	# 扩大范围
	var t_range = t_max - t_min
	var v_range = v_max - v_min
	if t_range < 0.001:
		t_range = 1.0
	if v_range < 1.0:
		v_range = 1.0
	t_min -= t_range * 0.05
	t_max += t_range * 0.05
	v_min -= v_range * 0.1
	v_max += v_range * 0.1
	v_range = v_max - v_min

	# 把 v_min 和 v_max 调整到"好看"的刻度
	var v_step = _nice_step(v_range / 5.0)
	v_min = floor(v_min / v_step) * v_step
	v_max = ceil(v_max / v_step) * v_step
	v_range = v_max - v_min

	t_range = t_max - t_min

	var plot_w = size.x - MARGIN_LEFT - MARGIN_RIGHT
	var plot_h = size.y - MARGIN_TOP - MARGIN_BOTTOM

	var origin = Vector2(MARGIN_LEFT, size.y - MARGIN_BOTTOM)
	var x_axis_y = size.y - MARGIN_BOTTOM

	# ── 画网格 ──
	var grid_lines = 5
	for i in range(1, grid_lines):
		var x = MARGIN_LEFT + plot_w * i / grid_lines
		draw_line(Vector2(x, MARGIN_TOP), Vector2(x, size.y - MARGIN_BOTTOM), grid_color, 0.5)
		var y = MARGIN_TOP + plot_h * i / grid_lines
		draw_line(Vector2(MARGIN_LEFT, y), Vector2(size.x - MARGIN_RIGHT, y), grid_color, 0.5)

	# ── 画坐标轴 ──
	draw_line(Vector2(MARGIN_LEFT, MARGIN_TOP), Vector2(MARGIN_LEFT, x_axis_y), axis_color, 1.5)
	draw_line(Vector2(MARGIN_LEFT, x_axis_y), Vector2(size.x - MARGIN_RIGHT, x_axis_y), axis_color, 1.5)

	# ── Y 轴刻度 ──
	var y_steps = 5
	var y_decimals = _get_decimals(v_range)
	for i in range(y_steps + 1):
		var val = v_min + v_range * i / y_steps
		var y = x_axis_y - plot_h * i / y_steps
		draw_line(Vector2(MARGIN_LEFT - 4, y), Vector2(MARGIN_LEFT, y), axis_color, 1.0)
		var label = ("%." + str(y_decimals) + "f") % val
		var label_size = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(ThemeDB.fallback_font,
			Vector2(MARGIN_LEFT - 8 - label_size.x, y + label_size.y * 0.3),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)

	# ── X 轴刻度 ──
	var x_steps = 5
	for i in range(x_steps + 1):
		var val = t_min + t_range * i / x_steps
		var x = MARGIN_LEFT + plot_w * i / x_steps
		draw_line(Vector2(x, x_axis_y), Vector2(x, x_axis_y + 4), axis_color, 1.0)
		var label = "%.1f" % val
		var label_size = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(ThemeDB.fallback_font,
			Vector2(x - label_size.x / 2, x_axis_y + 6),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)

	# ── 坐标轴标签 ──
	draw_string(ThemeDB.fallback_font,
		Vector2(size.x / 2 - 25, size.y - 4),
		"时间 (s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_color)
	draw_string(ThemeDB.fallback_font,
		Vector2(2, size.y / 2),
		"值", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_color)

	# ── 画曲线 ──
	for key in curves:
		var curve = curves[key]
		var pts = curve["data"]
		if pts.size() < 2:
			continue

		var points: Array[Vector2] = []
		for pt in pts:
			var px = MARGIN_LEFT + (pt["time"] - t_min) / t_range * plot_w
			var py = x_axis_y - (pt["value"] - v_min) / v_range * plot_h
			points.append(Vector2(px, py))

		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], curve["color"], 2.0)

	# ── 图例 ──
	var legend_x = MARGIN_LEFT + 10
	var legend_y = MARGIN_TOP + 10
	for key in curves:
		var col = curves[key]["color"]
		draw_rect(Rect2(legend_x, legend_y, 14, 14), col)
		draw_string(ThemeDB.fallback_font,
			Vector2(legend_x + 18, legend_y + 12),
			key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
		legend_y += 18

	# ── 鼠标悬停数值 ──
	var mouse_pos = get_local_mouse_position()
	if mouse_pos.x < MARGIN_LEFT or mouse_pos.x > size.x - MARGIN_RIGHT:
		return
	if mouse_pos.y < MARGIN_TOP or mouse_pos.y > size.y - MARGIN_BOTTOM:
		return

	# 重新计算时间范围用于鼠标定位
	var _t_min = INF
	var _t_max = -INF
	for key in curves:
		for pt in curves[key]["data"]:
			_t_min = min(_t_min, pt["time"])
			_t_max = max(_t_max, pt["time"])
	if _t_min == INF:
		return
	var _t_range = _t_max - _t_min
	if _t_range < 0.001:
		_t_range = 1.0
	_t_min -= _t_range * 0.05
	_t_range = _t_max - _t_min + _t_range * 0.1

	var _plot_w = size.x - MARGIN_LEFT - MARGIN_RIGHT
	var t_val = _t_min + (mouse_pos.x - MARGIN_LEFT) / _plot_w * _t_range

	# 画跟踪竖线
	draw_line(Vector2(mouse_pos.x, MARGIN_TOP), Vector2(mouse_pos.x, x_axis_y),
		Color(1, 1, 1, 0.3), 1.0)

	# 显示每条曲线在鼠标位置的值
	var y_offset = mouse_pos.y + 15
	for key in curves:
		var pts = curves[key]["data"]
		if pts.size() < 2:
			continue
		var best_pt = pts[0]
		var best_dist = abs(pts[0]["time"] - t_val)
		for pt in pts:
			var dist = abs(pt["time"] - t_val)
			if dist < best_dist:
				best_dist = dist
				best_pt = pt
			else:
				break
		var text = "%s: %.2f" % [key, best_pt["value"]]
		var text_size = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_rect(Rect2(mouse_pos.x + 8, y_offset, text_size.x + 6, text_size.y + 4),
			Color(0, 0, 0, 0.7))
		draw_string(ThemeDB.fallback_font,
			Vector2(mouse_pos.x + 11, y_offset + text_size.y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, curves[key]["color"])
		y_offset += text_size.y + 6
