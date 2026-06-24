extends RigidBody2D
class_name PendulumCart

@export var pid: PIDController
@export var position_pid: PIDController
@export var pendulum: RigidBody2D

@export var target_angle: float = 0.0  # 目标摆角，0=竖直向上
@export var target_x: float = 0.0      # 目标位置x
@export var max_force: float = 3000.0
@export var max_angle_offset: float = 0.15  # 位置环输出的最大偏角（弧度）
@export var enable_position_loop: bool = true  # 是否激活位置环

var prev_pendulum_angle: float = 0.0
var initial_position: Vector2        # 初始位置，用于复位
var stopped: bool = false            # 是否已停止

# 初始PID参数，用于复位
var _initial_inner_kp: float
var _initial_inner_ki: float
var _initial_inner_kd: float
var _initial_outer_kp: float
var _initial_outer_ki: float
var _initial_outer_kd: float


func _ready():
	initial_position = position
	set_meta("last_force", 0.0)
	set_meta("pendulum_angle", 0.0)
	set_meta("cart_position", position.x)
	set_meta("cart_velocity", linear_velocity.x)
	prev_pendulum_angle = pendulum.rotation
	target_x = position.x
	# 保存初始PID参数
	_initial_inner_kp = pid.kp
	_initial_inner_ki = pid.ki
	_initial_inner_kd = pid.kd
	_initial_outer_kp = position_pid.kp
	_initial_outer_ki = position_pid.ki
	_initial_outer_kd = position_pid.kd


func _physics_process(delta):
	if stopped:
		linear_velocity = Vector2.ZERO
		pendulum.linear_velocity = Vector2.ZERO
		pendulum.angular_velocity = 0.0
		set_meta("last_force", 0.0)
		return

	# 外环：位置PID → 输出目标偏角（可开关）
	var angle_offset = 0.0
	if enable_position_loop:
		angle_offset = position_pid.compute(target_x, position.x, delta)
		angle_offset = clamp(angle_offset, -max_angle_offset, max_angle_offset)

	# 内环：摆角PID → 输出控制力
	var angle = pendulum.rotation

	# 归一化角度到 [-PI, PI]
	while angle > PI:
		angle -= 2.0 * PI
	while angle < -PI:
		angle += 2.0 * PI

	var effective_target = target_angle + angle_offset
	var force = pid.compute(effective_target, angle, delta)
	force = clamp(force, -max_force, max_force)

	set_meta("last_force", force)
	set_meta("pendulum_angle", angle)
	set_meta("cart_position", position.x)
	set_meta("cart_velocity", linear_velocity.x)
	apply_central_force(Vector2(-force, 0))


func stop():
	stopped = true
	linear_velocity = Vector2.ZERO
	pendulum.linear_velocity = Vector2.ZERO
	pendulum.angular_velocity = 0.0
	# 禁用重力，防止摆杆在停止时因重力缓慢旋转
	gravity_scale = 0.0
	pendulum.gravity_scale = 0.0
	pid.reset()
	position_pid.reset()


func resume():
	stopped = false
	# 恢复重力
	gravity_scale = 1.0
	pendulum.gravity_scale = 1.0


func reset_to_initial():
	# 保存当前停止状态，复位后恢复
	var was_stopped = stopped
	# 先停止物理计算
	stopped = true
	# 清零速度
	linear_velocity = Vector2.ZERO
	pendulum.linear_velocity = Vector2.ZERO
	pendulum.angular_velocity = 0.0
	# 使用PhysicsServer2D直接设置物理体变换，避免被物理引擎覆盖
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, initial_position))
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(pendulum.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, initial_position))
	PhysicsServer2D.body_set_state(pendulum.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(pendulum.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	# 重置PID状态和参数
	pid.reset()
	pid.kp = _initial_inner_kp
	pid.ki = _initial_inner_ki
	pid.kd = _initial_inner_kd
	position_pid.reset()
	position_pid.kp = _initial_outer_kp
	position_pid.ki = _initial_outer_ki
	position_pid.kd = _initial_outer_kd
	# 重置目标位置和角度
	target_x = initial_position.x
	target_angle = 0.0
	# 恢复之前的停止状态
	stopped = was_stopped


# 设置摆杆角度（度数），使用PhysicsServer2D避免被物理引擎覆盖
func set_pendulum_angle_deg(degrees: float):
	var rad = deg_to_rad(degrees)
	pendulum.angular_velocity = 0.0
	pendulum.linear_velocity = Vector2.ZERO
	PhysicsServer2D.body_set_state(pendulum.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(rad, pendulum.position))
	PhysicsServer2D.body_set_state(pendulum.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	PhysicsServer2D.body_set_state(pendulum.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
