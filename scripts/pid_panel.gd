extends VBoxContainer

@export var pid_controller: PIDController
@export var slider_body: RigidBody2D   # 新增：引用滑块刚体

@onready var target_input: LineEdit = $HBoxContainer_TargetPos/TargetInput
@onready var kp_slider: HSlider = $HBoxContainer_Kp/HSlider
@onready var ki_slider: HSlider = $HBoxContainer_Ki/HSlider
@onready var kd_slider: HSlider = $HBoxContainer_Kd/HSlider


func _ready():
	target_input.placeholder_text = "目标位置"
	target_input.text = "600.0"
	target_input.text_submitted.connect(_on_target_submitted)

	kp_slider.min_value = 0.0
	kp_slider.max_value = 100.0
	kp_slider.step = 0.1
	kp_slider.value = pid_controller.kp

	ki_slider.min_value = 0.0
	ki_slider.max_value = 50.0
	ki_slider.step = 0.1
	ki_slider.value = pid_controller.ki

	kd_slider.min_value = 0.0
	kd_slider.max_value = 50.0
	kd_slider.step = 0.1
	kd_slider.value = pid_controller.kd

	kp_slider.value_changed.connect(_on_kp_changed)
	ki_slider.value_changed.connect(_on_ki_changed)
	kd_slider.value_changed.connect(_on_kd_changed)


func _on_target_submitted(new_text: String):
	if new_text.is_valid_float():
		slider_body.set_meta("target_x", new_text.to_float())


func _on_kp_changed(value: float):
	pid_controller.kp = value

func _on_ki_changed(value: float):
	pid_controller.ki = value

func _on_kd_changed(value: float):
	pid_controller.kd = value
