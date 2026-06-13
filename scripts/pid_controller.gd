extends Node
class_name PIDController

## PID 控制器
## 输出范围默认不限，可以设置 output_max 来限幅

@export var kp: float = 10.0
@export var ki: float = 0.0
@export var kd: float = 5.0

@export var integral_limit: float = 100.0
@export var output_max: float = 1000.0

var integral: float = 0.0
var prev_measurement: float = 0.0
var first_run: bool = true


func compute(reference: float, measurement: float, dt: float) -> float:
	# 比例项
	var error = reference - measurement
	var p_term = kp * error

	# 积分项（带限幅，抗积分饱和）
	integral += error * dt
	integral = clamp(integral, -integral_limit, integral_limit)
	var i_term = ki * integral

	# 微分项（对测量值微分，避免微分冲击）
	var d_term = 0.0
	if not first_run and dt > 0.0001:
		d_term = -kd * (measurement - prev_measurement) / dt
	first_run = false
	prev_measurement = measurement

	# 合成输出
	var output = p_term + i_term + d_term
	output = clamp(output, -output_max, output_max)
	return output


func reset():
	integral = 0.0
	prev_measurement = 0.0
	first_run = true
