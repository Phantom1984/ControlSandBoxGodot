extends VBoxContainer

@export var pendulum_pid: PIDController
@export var position_pid: PIDController
@export var cart: RigidBody2D

# 内环（摆角PID）
@onready var inner_kp_slider: HSlider = $InnerPanel/HBoxContainer_Kp/HSlider
@onready var inner_ki_slider: HSlider = $InnerPanel/HBoxContainer_Ki/HSlider
@onready var inner_kd_slider: HSlider = $InnerPanel/HBoxContainer_Kd/HSlider

# 外环（位置PID）
@onready var outer_kp_slider: HSlider = $OuterPanel/HBoxContainer_Kp/HSlider
@onready var outer_ki_slider: HSlider = $OuterPanel/HBoxContainer_Ki/HSlider
@onready var outer_kd_slider: HSlider = $OuterPanel/HBoxContainer_Kd/HSlider
@onready var target_input: LineEdit = $OuterPanel/HBoxContainer_TargetPos/TargetInput

# 控制方式按钮
@onready var btn_single: Button = $ControlMode/HBoxContainer/BtnSingle
@onready var btn_double: Button = $ControlMode/HBoxContainer/BtnDouble
@onready var btn_lqr: Button = $ControlMode/HBoxContainer/BtnLQR


func _ready():
	_setup_inner_sliders()
	_setup_outer_sliders()
	_setup_target_input()
	_setup_control_mode()


func _setup_inner_sliders():
	inner_kp_slider.min_value = 0.0
	inner_kp_slider.max_value = 10000.0
	inner_kp_slider.step = 10.0
	inner_kp_slider.value = pendulum_pid.kp
	inner_kp_slider.value_changed.connect(_on_inner_kp_changed)

	inner_ki_slider.min_value = 0.0
	inner_ki_slider.max_value = 100.0
	inner_ki_slider.step = 0.1
	inner_ki_slider.value = pendulum_pid.ki
	inner_ki_slider.value_changed.connect(_on_inner_ki_changed)

	inner_kd_slider.min_value = 0.0
	inner_kd_slider.max_value = 1000.0
	inner_kd_slider.step = 1.0
	inner_kd_slider.value = pendulum_pid.kd
	inner_kd_slider.value_changed.connect(_on_inner_kd_changed)


func _setup_outer_sliders():
	outer_kp_slider.min_value = 0.0
	outer_kp_slider.max_value = 0.1
	outer_kp_slider.step = 0.0001
	outer_kp_slider.value = position_pid.kp
	outer_kp_slider.value_changed.connect(_on_outer_kp_changed)

	outer_ki_slider.min_value = 0.0
	outer_ki_slider.max_value = 1.0
	outer_ki_slider.step = 0.001
	outer_ki_slider.value = position_pid.ki
	outer_ki_slider.value_changed.connect(_on_outer_ki_changed)

	outer_kd_slider.min_value = 0.0
	outer_kd_slider.max_value = 1.0
	outer_kd_slider.step = 0.001
	outer_kd_slider.value = position_pid.kd
	outer_kd_slider.value_changed.connect(_on_outer_kd_changed)


func _setup_target_input():
	target_input.placeholder_text = "目标位置x"
	target_input.text = "%.1f" % cart.target_x
	target_input.text_submitted.connect(_on_target_submitted)


func _setup_control_mode():
	btn_single.pressed.connect(_on_single_pressed)
	btn_double.pressed.connect(_on_double_pressed)
	btn_lqr.disabled = true  # LQR未实现
	_update_mode_buttons()


func _on_inner_kp_changed(value: float):
	pendulum_pid.kp = value

func _on_inner_ki_changed(value: float):
	pendulum_pid.ki = value

func _on_inner_kd_changed(value: float):
	pendulum_pid.kd = value

func _on_outer_kp_changed(value: float):
	position_pid.kp = value

func _on_outer_ki_changed(value: float):
	position_pid.ki = value

func _on_outer_kd_changed(value: float):
	position_pid.kd = value


func _on_target_submitted(new_text: String):
	if new_text.is_valid_float():
		cart.target_x = new_text.to_float()


func _on_single_pressed():
	cart.enable_position_loop = false
	_update_mode_buttons()


func _on_double_pressed():
	cart.enable_position_loop = true
	_update_mode_buttons()


func _update_mode_buttons():
	btn_single.button_pressed = not cart.enable_position_loop
	btn_double.button_pressed = cart.enable_position_loop
