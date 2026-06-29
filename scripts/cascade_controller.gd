extends ControllerBase
class_name CascadeController

## ============================================================
## 串级控制器容器
##
## 把"外环输出"注入到"内环设定值"中，构成串级控制。
##
## 典型用法（倒立摆双环）：
##   外环：位置 PID，输入 (target_x, position_x)，输出 angle_offset
##   内环：摆角 PID，输入 (target_angle + angle_offset, angle)，输出 force
##
## 耦合方式：外环输出 u_outer 被加到 setpoint[coupling_field] 上，
##           然后传给内环。这样支持"基础设定值 + 外环校正量"的语义。
## ============================================================

@export var inner: ControllerBase
@export var outer: ControllerBase

## 外环输出在 setpoint 中注入的字段名
## 内环会从该字段读取其参考值
@export var coupling_field: String = "reference"

## 外环输出的限幅（INF 表示不限）
@export var outer_output_limit: float = INF


func compute(state: Dictionary, setpoint: Dictionary, dt: float) -> float:
	if not inner:
		push_warning("CascadeController.inner 未设置")
		return 0.0

	# 外环计算（仅当 outer 设置时）
	var outer_out := 0.0
	if outer:
		outer_out = outer.compute(state, setpoint, dt)
		if outer_output_limit < INF:
			outer_out = clamp(outer_out, -outer_output_limit, outer_output_limit)

	# 把外环输出加到 setpoint 的耦合字段上，传给内环
	var inner_setpoint := setpoint.duplicate(true)
	var base_ref: float = inner_setpoint.get(coupling_field, 0.0)
	inner_setpoint[coupling_field] = base_ref + outer_out

	return inner.compute(state, inner_setpoint, dt)


func reset():
	if inner:
		inner.reset()
	if outer:
		outer.reset()


func get_params() -> Dictionary:
	var p := {}
	if inner:
		p["inner"] = inner.get_params()
	if outer:
		p["outer"] = outer.get_params()
	return p


func set_params(p: Dictionary):
	if inner and p.has("inner"):
		inner.set_params(p["inner"])
	if outer and p.has("outer"):
		outer.set_params(p["outer"])


func get_required_inputs() -> Dictionary:
	var req := {"state": [], "setpoint": []}
	if outer:
		var o := outer.get_required_inputs()
		req["state"].append_array(o["state"])
		req["setpoint"].append_array(o["setpoint"])
	if inner:
		var i := inner.get_required_inputs()
		req["state"].append_array(i["state"])
		# 内环的耦合字段由外环提供，不再从 setpoint 直接读
		for f in i["setpoint"]:
			if f != coupling_field and not req["setpoint"].has(f):
				req["setpoint"].append(f)
	return req
