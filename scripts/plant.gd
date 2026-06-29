extends RigidBody2D
class_name Plant

## ============================================================
## 被控对象基类
##
## 所有被控对象（Cart / Pendulum1Plant / Pendulum2Plant ...）继承此类。
## Plant 负责物理仿真 + 状态广播，控制器负责计算控制量。
##
## 每 physics tick 的处理流程：
##   1. get_state()         → 采集当前状态
##   2. _build_setpoint(t)  → 构建设定值（可注入辨识激励）
##   3. controller.compute  → 算控制量 u
##   4. _apply_control(u)   → 施加到物理体
##   5. _post_control_update → 广播 state_updated 信号
##
## 子类需实现：
##   - get_state()           返回状态字典
##   - _apply_control(u)     施加控制力
##   - get_default_setpoint() 默认设定值
## 可重写：
##   - _on_stopped()         停止时的额外清理
##   - _reset_to_initial_impl() 复位时的状态恢复
##   - _clamp_control(u)     控制量限幅
## ============================================================

signal state_updated(t: float, state: Dictionary)

@export var controller: ControllerBase

## 辨识激励源（可选，需实现 get_value(t) -> float）
@export var excitation: Node

var stopped: bool = false
var initial_position: Vector2
var initial_rotation: float = 0.0


func _ready():
	initial_position = position
	initial_rotation = rotation
	_plant_ready()


func _physics_process(delta):
	if stopped:
		_on_stopped()
		return

	var t := Time.get_ticks_msec() / 1000.0
	var state := get_state()
	var setpoint := _build_setpoint(t)

	var u := 0.0
	if controller:
		u = controller.compute(state, setpoint, delta)
	u = _clamp_control(u)

	_apply_control(u, delta)
	_post_control_update(state, u, t, delta)


# ───────── 子类重写接口 ─────────

## 返回当前状态字典（必须重写）
func get_state() -> Dictionary:
	return {}


## 施加控制量到物理体（必须重写）
## dt 由 _physics_process 传入，用于扰动计算等需要时间的场景
func _apply_control(u: float, dt: float):
	pass


## 默认设定值（可重写）
func get_default_setpoint() -> Dictionary:
	return {}


## 控制量限幅（可重写）
func _clamp_control(u: float) -> float:
	return u


## 停止时的额外清理（可重写，子物理体清零等）
func _on_stopped():
	linear_velocity = Vector2.ZERO


## 复位时的状态恢复（可重写，恢复子物理体等）
func _reset_to_initial_impl():
	linear_velocity = Vector2.ZERO
	PhysicsServer2D.body_set_state(
		get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(initial_rotation, initial_position)
	)
	PhysicsServer2D.body_set_state(
		get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO
	)


## 子类初始化钩子（_ready 中调用，可重写）
func _plant_ready():
	pass


# ───────── 内部辅助 ─────────

## 构建设定值字典（注入辨识激励）
func _build_setpoint(t: float) -> Dictionary:
	var sp := get_default_setpoint()
	if excitation and excitation.has_method("get_value"):
		sp["excitation"] = excitation.get_value(t)
	return sp


## 控制后广播状态（可被 DataMonitor / 辨识器监听）
func _post_control_update(state: Dictionary, u: float, t: float, _dt: float):
	state["control"] = u
	state["time"] = t
	# 同步写入 meta，兼容现有 DataMonitor 自动采集
	for key in state:
		set_meta(key, state[key])
	state_updated.emit(t, state)


# ───────── 对外控制接口 ─────────

func stop():
	stopped = true
	_on_stopped()
	if controller:
		controller.reset()


func resume():
	stopped = false


func reset_to_initial():
	var was_stopped := stopped
	stopped = true
	_reset_to_initial_impl()
	if controller:
		controller.reset()
	stopped = was_stopped
