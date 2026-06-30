extends Node
class_name DataBridge

@export var monitor: DataMonitor
@export var plotter: Plotter

# 所有可监控的变量
var available_vars: Dictionary = {
	"位置 X": {"field": "position_x", "color": Color.RED, "enabled": true},
	"速度 X": {"field": "velocity_x", "color": Color.GREEN, "enabled": true},
	"加速度 X": {"field": "acceleration_x", "color": Color.BLUE, "enabled": true},
	"控制力":   {"field": "control", "color": Color.YELLOW, "enabled": false},
}

signal curve_toggled(curve_name: String, enabled: bool)


func _ready():
	# 初始化所有曲线
	for var_name in available_vars:
		var info = available_vars[var_name]
		plotter.add_curve(var_name, info["color"])
	
	monitor.data_updated.connect(_on_data_updated)


func toggle_variable(var_name: String, enabled: bool):
	if available_vars.has(var_name):
		available_vars[var_name]["enabled"] = enabled


func get_available_vars() -> Dictionary:
	return available_vars


func _on_data_updated(_timestamp: float, data: Dictionary):
	for var_name in available_vars:
		var info = available_vars[var_name]
		if not info["enabled"]:
			continue
		var field = info["field"]
		if data.has(field):
			plotter.add_point(var_name, data["time"], data[field])
