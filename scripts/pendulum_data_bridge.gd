extends Node
class_name PendulumDataBridge

@export var monitor: DataMonitor
@export var plotter: Plotter

var available_vars: Dictionary = {
	"摆角":     {"field": "pendulum_angle", "color": Color.RED, "enabled": true},
	"小车位置": {"field": "cart_position", "color": Color.GREEN, "enabled": true},
	"小车速度": {"field": "cart_velocity", "color": Color.BLUE, "enabled": true},
	"控制力":   {"field": "force_x", "color": Color.YELLOW, "enabled": false},
}

signal curve_toggled(curve_name: String, enabled: bool)


func _ready():
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
		if data.has(info["field"]):
			plotter.add_point(var_name, data["time"], data[info["field"]])
