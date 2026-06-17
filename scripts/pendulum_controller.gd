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


func _ready():
	set_meta("last_force", 0.0)
	set_meta("pendulum_angle", 0.0)
	set_meta("cart_position", position.x)
	set_meta("cart_velocity", linear_velocity.x)
	prev_pendulum_angle = pendulum.rotation
	target_x = position.x


func _physics_process(delta):
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
