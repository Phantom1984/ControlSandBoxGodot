extends RigidBody2D

@export var pid: PIDController
@export var default_target_x: float = 600.0

# 环境参数
var friction_coeff: float = 0.0      # 地面摩擦系数
var drag_coeff: float = 0.0          # 空气阻力系数
var disturbance_force: float = 0.0   # 周期性扰动幅度
var disturbance_freq: float = 0.0    # 周期性扰动频率 (Hz)
var disturbance_timer: float = 0.0   # 扰动计时器

var prev_position_x: float
var initial_position: Vector2        # 初始位置，用于复位
var stopped: bool = false            # 是否已停止

# 初始PID参数，用于复位
var _initial_kp: float
var _initial_ki: float
var _initial_kd: float


func _ready():
	initial_position = position
	prev_position_x = position.x
	set_meta("target_x", default_target_x)
	set_meta("last_force", 0.0)
	# 保存初始PID参数
	_initial_kp = pid.kp
	_initial_ki = pid.ki
	_initial_kd = pid.kd


func _physics_process(delta):
	if stopped:
		linear_velocity = Vector2.ZERO
		set_meta("last_force", 0.0)
		return

	# PID 控制力
	var target_x = get_meta("target_x", default_target_x)
	var control_force = pid.compute(target_x, position.x, delta)

	# 空气阻力（与速度成正比，方向相反）
	var drag_force = -drag_coeff * linear_velocity.x

	# 地面摩擦力（库仑摩擦，与速度方向相反）
	var friction_force = 0.0
	if abs(linear_velocity.x) > 0.01:
		friction_force = -sign(linear_velocity.x) * friction_coeff * mass * 9.8

	# 周期性扰动
	disturbance_timer += delta
	var periodic_disturbance = 0.0
	if disturbance_freq > 0.001:
		periodic_disturbance = disturbance_force * sin(2.0 * PI * disturbance_freq * disturbance_timer)

	# 合成总力
	var total_force = control_force + drag_force + friction_force + periodic_disturbance
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


func stop():
	stopped = true
	linear_velocity = Vector2.ZERO
	pid.reset()


func resume():
	stopped = false


func reset_to_initial():
	# 保存当前停止状态，复位后恢复
	var was_stopped = stopped
	# 先停止物理计算
	stopped = true
	# 清零速度
	linear_velocity = Vector2.ZERO
	# 使用PhysicsServer2D直接设置物理体变换，避免被物理引擎覆盖
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, initial_position))
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	# 重置PID状态和参数
	pid.reset()
	pid.kp = _initial_kp
	pid.ki = _initial_ki
	pid.kd = _initial_kd
	# 重置目标位置
	set_meta("target_x", default_target_x)
	# 恢复之前的停止状态
	stopped = was_stopped
