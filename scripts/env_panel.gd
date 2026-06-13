extends VBoxContainer
class_name EnvPanel

@export var slider_body: RigidBody2D

@onready var friction_slider: HSlider = $HBoxContainer/HSlider
@onready var friction_label: Label = $HBoxContainer/Label2

@onready var drag_slider: HSlider = $HBoxContainer2/HSlider
@onready var drag_label: Label = $HBoxContainer2/Label2

@onready var dist_force_slider: HSlider = $HBoxContainer3/HSlider
@onready var dist_force_label: Label = $HBoxContainer3/Label2

@onready var dist_freq_slider: HSlider = $HBoxContainer4/HSlider
@onready var dist_freq_label: Label = $HBoxContainer4/Label2

@onready var pulse_input: LineEdit = $HBoxContainer5/PulseInput
@onready var pulse_btn: Button = $HBoxContainer5/PulseButton


func _ready():
	# 地面摩擦
	friction_slider.min_value = 0.0
	friction_slider.max_value = 2.0
	friction_slider.step = 0.01
	friction_slider.value = 0.0
	friction_slider.value_changed.connect(_on_friction_changed)

	# 空气阻力
	drag_slider.min_value = 0.0
	drag_slider.max_value = 5.0
	drag_slider.step = 0.01
	drag_slider.value = 0.0
	drag_slider.value_changed.connect(_on_drag_changed)

	# 扰动幅度
	dist_force_slider.min_value = 0.0
	dist_force_slider.max_value = 500.0
	dist_force_slider.step = 1.0
	dist_force_slider.value = 0.0
	dist_force_slider.value_changed.connect(_on_dist_force_changed)

	# 扰动频率
	dist_freq_slider.min_value = 0.0
	dist_freq_slider.max_value = 10.0
	dist_freq_slider.step = 0.1
	dist_freq_slider.value = 0.0
	dist_freq_slider.value_changed.connect(_on_dist_freq_changed)

	# 脉冲输入
	pulse_input.placeholder_text = "冲量大小"
	pulse_input.text = "100"
	pulse_btn.pressed.connect(_on_pulse_pressed)


func _update_env():
	slider_body.set_environment({
		"friction": friction_slider.value,
		"drag": drag_slider.value,
		"dist_force": dist_force_slider.value,
		"dist_freq": dist_freq_slider.value
	})


func _on_friction_changed(value: float):
	friction_label.text = "%.2f" % value
	_update_env()


func _on_drag_changed(value: float):
	drag_label.text = "%.2f" % value
	_update_env()


func _on_dist_force_changed(value: float):
	dist_force_label.text = "%.0f" % value
	_update_env()


func _on_dist_freq_changed(value: float):
	dist_freq_label.text = "%.1f Hz" % value
	_update_env()


func _on_pulse_pressed():
	if pulse_input.text.is_valid_float():
		var impulse = pulse_input.text.to_float()
		slider_body.apply_pulse_impulse(impulse)
