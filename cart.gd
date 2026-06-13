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


func _ready():
	prev_position_x = position.x
	set_meta("target_x", default_target_x)
	set_meta("last_force", 0.0)


func _physics_process(delta):
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
