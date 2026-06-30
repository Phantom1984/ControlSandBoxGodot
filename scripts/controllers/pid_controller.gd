extends ControllerBase
class_name PIDController

## ============================================================
## PID 控制器
##
## 通过 measurement_field / reference_field 从 state / setpoint 字典中
## 读取对应字段，实现统一签名 compute(state, setpoint, dt)。
##
## 典型字段约定（倒立摆双环场景）：
##   内环摆角 PID: measurement_field="angle",     reference_field="target_angle"
##   外环位置 PID: measurement_field="position_x", reference_field="target_x"
##
## 输出范围默认不限，可设置 output_max 来限幅
## ============================================================

@export var kp: float = 10.0
@export var ki: float = 0.0
@export var kd: float = 5.0

@export var integral_limit: float = 100.0
@export var output_max: float = 1000.0

## 从 state 中读取测量值的字段名
@export var measurement_field: String = "measurement"
## 从 setpoint 中读取参考值的字段名
@export var reference_field: String = "reference"

var integral: float = 0.0
var prev_measurement: float = 0.0
var first_run: bool = true


func compute(state: Dictionary, setpoint: Dictionary, dt: float) -> float:
	var reference: float = setpoint.get(reference_field, 0.0)
	var measurement: float = state.get(measurement_field, 0.0)
	return _compute_pid(reference, measurement, dt)


## 内部 PID 计算（保留直接调用入口，便于单元测试）
func _compute_pid(reference: float, measurement: float, dt: float) -> float:
	# 比例项
	var error := reference - measurement
	var p_term := kp * error

	# 积分项（带限幅，抗积分饱和）
	integral += error * dt
	integral = clamp(integral, -integral_limit, integral_limit)
	var i_term := ki * integral

	# 微分项（对测量值微分，避免微分冲击）
	var d_term := 0.0
	if not first_run and dt > 0.0001:
		d_term = -kd * (measurement - prev_measurement) / dt
	first_run = false
	prev_measurement = measurement

	# 合成输出
	var output := p_term + i_term + d_term
	output = clamp(output, -output_max, output_max)
	return output


func reset():
	integral = 0.0
	prev_measurement = 0.0
	first_run = true


func get_params() -> Dictionary:
	return {
		"kp": kp,
		"ki": ki,
		"kd": kd,
		"integral_limit": integral_limit,
		"output_max": output_max,
	}


func set_params(p: Dictionary):
	if p.has("kp"): kp = p["kp"]
	if p.has("ki"): ki = p["ki"]
	if p.has("kd"): kd = p["kd"]
	if p.has("integral_limit"): integral_limit = p["integral_limit"]
	if p.has("output_max"): output_max = p["output_max"]


func get_required_inputs() -> Dictionary:
	return {"state": [measurement_field], "setpoint": [reference_field]}
