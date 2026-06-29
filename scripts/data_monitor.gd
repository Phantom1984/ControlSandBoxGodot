extends Node
class_name DataMonitor

## 数据采集器，每物理帧记录被监控对象的状态

@export var target: RigidBody2D

# 用户勾选要监控的变量
@export var monitor_position: bool = true
@export var monitor_velocity: bool = true
@export var monitor_acceleration: bool = true
@export var monitor_force: bool = true

# 信号：新数据产生时发出
signal data_updated(timestamp: float, data: Dictionary)

# 存储历史数据
var history: Array[Dictionary] = []
var max_history: int = 1000

# 用于计算加速度
var prev_velocity: Vector2 = Vector2.ZERO
var prev_control_force: float = 0.0


func _ready():
	if target:
		prev_velocity = target.linear_velocity


func _physics_process(delta):
	if not target:
		return
	
	var t = Time.get_ticks_msec() / 1000.0
	var record = {"time": t}
	
	if monitor_position:
		record["position_x"] = target.position.x
	
	if monitor_velocity:
		record["velocity_x"] = target.linear_velocity.x
	
	if monitor_acceleration:
		var accel = (target.linear_velocity.x - prev_velocity.x) / delta if delta > 0 else 0.0
		record["acceleration_x"] = accel
		prev_velocity = target.linear_velocity
	
	if monitor_force:
		# 优先读 control（Plant._post_control_update 写入），fallback 到 last_force（旧字段）
		record["force_x"] = target.get_meta("control", target.get_meta("last_force", 0.0))
		
	# 自动收集 target 上的所有 meta 数据
	var meta_list = target.get_meta_list()
	for key in meta_list:
		if not record.has(key):
			record[key] = target.get_meta(key)
			
	history.append(record)
	if history.size() > max_history:
		history.pop_front()
	
	data_updated.emit(t, record)
