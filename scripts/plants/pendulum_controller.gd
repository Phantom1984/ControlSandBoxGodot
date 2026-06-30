extends Plant
class_name PendulumCart

## ============================================================
## 一阶倒立摆被控对象
##
## 状态向量：{angle, position_x, velocity_x, pendulum_angular_velocity}
## 设定值：  {target_angle, target_x}
##
## 控制结构（运行时自动构建）：
##   单环模式：controller = pid（摆角 PID）
##   双环模式：controller = CascadeController
##             ├─ outer = position_pid（位置 → angle_offset）
##             └─ inner = pid（angle_offset + target_angle → force）
##
## 兼容性：保留 @export pid / position_pid / enable_position_loop 字段，
##         旧场景无需重新绑定。
## ============================================================

@export var pid: PIDController
@export var position_pid: PIDController
@export var pendulum: RigidBody2D

@export var target_angle: float = 0.0  # 目标摆角，0=竖直向上
@export var target_x: float = 0.0      # 目标位置x
@export var max_force: float = 3000.0
@export var max_angle_offset: float = 0.15  # 位置环输出的最大偏角（弧度）

@export var enable_position_loop: bool = true:
	set(v):
		enable_position_loop = v
		if _initialized:
			_rebuild_controller()

var _initialized: bool = false

# 初始PID参数，用于复位
var _initial_inner_kp: float
var _initial_inner_ki: float
var _initial_inner_kd: float
var _initial_outer_kp: float
var _initial_outer_ki: float
var _initial_outer_kd: float


func _plant_ready():
	# 配置 PID 字段映射（场景文件中未设置，运行时注入）
	pid.measurement_field = "angle"
	pid.reference_field = "target_angle"
	position_pid.measurement_field = "position_x"
	position_pid.reference_field = "target_x"

	# 保存初始PID参数，用于复位
	_initial_inner_kp = pid.kp
	_initial_inner_ki = pid.ki
	_initial_inner_kd = pid.kd
	_initial_outer_kp = position_pid.kp
	_initial_outer_ki = position_pid.ki
	_initial_outer_kd = position_pid.kd

	target_x = position.x
	_rebuild_controller()
	_initialized = true


func _rebuild_controller():
	if enable_position_loop:
		var cascade := CascadeController.new()
		cascade.inner = pid
		cascade.outer = position_pid
		cascade.coupling_field = "target_angle"
		cascade.outer_output_limit = max_angle_offset
		controller = cascade
	else:
		controller = pid


func get_state() -> Dictionary:
	var angle := pendulum.rotation
	# 归一化角度到 [-PI, PI]
	while angle > PI:
		angle -= 2.0 * PI
	while angle < -PI:
		angle += 2.0 * PI
	return {
		"angle": angle,
		"position_x": position.x,
		"velocity_x": linear_velocity.x,
		"pendulum_angular_velocity": pendulum.angular_velocity,
	}


func get_default_setpoint() -> Dictionary:
	return {
		"target_angle": target_angle,
		"target_x": target_x,
	}


func _apply_control(u: float, _dt: float):
	apply_central_force(Vector2(-u, 0))


func _clamp_control(u: float) -> float:
	return clamp(u, -max_force, max_force)


func _on_stopped():
	super._on_stopped()
	pendulum.linear_velocity = Vector2.ZERO
	pendulum.angular_velocity = 0.0


func _reset_to_initial_impl():
	super._reset_to_initial_impl()
	pendulum.linear_velocity = Vector2.ZERO
	pendulum.angular_velocity = 0.0
	PhysicsServer2D.body_set_state(
		pendulum.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(0.0, initial_position)
	)
	PhysicsServer2D.body_set_state(
		pendulum.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO
	)
	PhysicsServer2D.body_set_state(
		pendulum.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0
	)


func reset_to_initial():
	super.reset_to_initial()
	# 重置PID参数到初始值
	pid.kp = _initial_inner_kp
	pid.ki = _initial_inner_ki
	pid.kd = _initial_inner_kd
	position_pid.kp = _initial_outer_kp
	position_pid.ki = _initial_outer_ki
	position_pid.kd = _initial_outer_kd
	# 重置目标
	target_x = initial_position.x
	target_angle = 0.0


func stop():
	super.stop()
	# 禁用重力，防止摆杆在停止时因重力缓慢旋转
	gravity_scale = 0.0
	pendulum.gravity_scale = 0.0


func resume():
	super.resume()
	gravity_scale = 1.0
	pendulum.gravity_scale = 1.0


# 设置摆杆角度（度数），使用PhysicsServer2D避免被物理引擎覆盖
func set_pendulum_angle_deg(degrees: float):
	var rad := deg_to_rad(degrees)
	pendulum.angular_velocity = 0.0
	pendulum.linear_velocity = Vector2.ZERO
	PhysicsServer2D.body_set_state(
		pendulum.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(rad, pendulum.position)
	)
	PhysicsServer2D.body_set_state(
		pendulum.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0
	)
	PhysicsServer2D.body_set_state(
		pendulum.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO
	)
