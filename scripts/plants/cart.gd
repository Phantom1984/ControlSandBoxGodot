extends Plant
class_name Cart

## ============================================================
## 滑块被控对象（单 PID 位置控制）
##
## 状态向量：{position_x, velocity_x}
## 设定值：  {target_x}（通过 meta 设置，兼容现有 UI）
##
## 与倒立摆的区别：
##   - 无摆杆，纯位置控制
##   - _apply_control 中额外计算摩擦/阻力/扰动（辨识时应关闭）
##   - 实际作用力 total_force = u + drag + friction + disturbance
##     辨识输入用 u（控制器输出），total_force 仅供监控
## ============================================================

@export var pid: PIDController
@export var default_target_x: float = 600.0

# 环境参数（辨识时应全部置零）
var friction_coeff: float = 0.0      # 地面摩擦系数
var drag_coeff: float = 0.0          # 空气阻力系数
var disturbance_force: float = 0.0   # 周期性扰动幅度
var disturbance_freq: float = 0.0    # 周期性扰动频率 (Hz)
var disturbance_timer: float = 0.0   # 扰动计时器

# 初始PID参数，用于复位
var _initial_kp: float
var _initial_ki: float
var _initial_kd: float


func _plant_ready():
	# 配置 PID 字段映射
	pid.measurement_field = "position_x"
	pid.reference_field = "target_x"

	set_meta("target_x", default_target_x)
	set_meta("last_force", 0.0)

	# 保存初始PID参数
	_initial_kp = pid.kp
	_initial_ki = pid.ki
	_initial_kd = pid.kd

	controller = pid


func get_state() -> Dictionary:
	return {
		"position_x": position.x,
		"velocity_x": linear_velocity.x,
	}


func get_default_setpoint() -> Dictionary:
	return {"target_x": get_meta("target_x", default_target_x)}


func _apply_control(u: float, dt: float):
	# 空气阻力（与速度成正比，方向相反）
	var drag_force := -drag_coeff * linear_velocity.x

	# 地面摩擦力（库仑摩擦，与速度方向相反）
	var friction_force := 0.0
	if abs(linear_velocity.x) > 0.01:
		friction_force = -sign(linear_velocity.x) * friction_coeff * mass * 9.8

	# 周期性扰动
	disturbance_timer += dt
	var periodic_disturbance := 0.0
	if disturbance_freq > 0.001:
		periodic_disturbance = disturbance_force * sin(2.0 * PI * disturbance_freq * disturbance_timer)

	# 合成总力（u 是控制器输出；其余为环境扰动）
	var total_force := u + drag_force + friction_force + periodic_disturbance
	set_meta("last_force", total_force)
	apply_central_force(Vector2(total_force, 0))


func apply_pulse_impulse(impulse: float):
	# 施加瞬时冲量（脉冲干扰）
	apply_central_impulse(Vector2(impulse, 0))


func set_environment(params: Dictionary):
	friction_coeff = params.get("friction", 0.0)
	drag_coeff = params.get("drag", 0.0)
	disturbance_force = params.get("dist_force", 0.0)
	disturbance_freq = params.get("dist_freq", 0.0)


func reset_to_initial():
	super.reset_to_initial()
	pid.kp = _initial_kp
	pid.ki = _initial_ki
	pid.kd = _initial_kd
	set_meta("target_x", default_target_x)
	disturbance_timer = 0.0
