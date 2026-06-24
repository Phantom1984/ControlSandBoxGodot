extends VBoxContainer

@export var pendulum_pid: PIDController
@export var position_pid: PIDController
@export var cart: RigidBody2D

# 内环（摆角PID）
@onready var inner_kp_slider: HSlider = $InnerPanel/HBoxContainer_Kp/HSlider
@onready var inner_ki_slider: HSlider = $InnerPanel/HBoxContainer_Ki/HSlider
@onready var inner_kd_slider: HSlider = $InnerPanel/HBoxContainer_Kd/HSlider
@onready var inner_kp_spin: SpinBox = $InnerPanel/HBoxContainer_Kp/SpinBox
@onready var inner_ki_spin: SpinBox = $InnerPanel/HBoxContainer_Ki/SpinBox
@onready var inner_kd_spin: SpinBox = $InnerPanel/HBoxContainer_Kd/SpinBox

# 外环（位置PID）
@onready var outer_kp_slider: HSlider = $OuterPanel/HBoxContainer_Kp/HSlider
@onready var outer_ki_slider: HSlider = $OuterPanel/HBoxContainer_Ki/HSlider
@onready var outer_kd_slider: HSlider = $OuterPanel/HBoxContainer_Kd/HSlider
@onready var outer_kp_spin: SpinBox = $OuterPanel/HBoxContainer_Kp/SpinBox
@onready var outer_ki_spin: SpinBox = $OuterPanel/HBoxContainer_Ki/SpinBox
@onready var outer_kd_spin: SpinBox = $OuterPanel/HBoxContainer_Kd/SpinBox
@onready var target_input: LineEdit = $OuterPanel/HBoxContainer_TargetPos/TargetInput
@onready var target_slider: HSlider = $OuterPanel/HBoxContainer_TargetPos/HSlider

# 初始角度设置
@onready var init_angle_slider: HSlider = $InitAnglePanel/HBoxContainer_InitAngle/HSlider
@onready var init_angle_spin: SpinBox = $InitAnglePanel/HBoxContainer_InitAngle/SpinBox

# 控制方式按钮
@onready var btn_single: Button = $ControlMode/HBoxContainer/BtnSingle
@onready var btn_double: Button = $ControlMode/HBoxContainer/BtnDouble
@onready var btn_lqr: Button = $ControlMode/HBoxContainer/BtnLQR

# 停止和复位按钮
@onready var stop_btn: Button = $HBoxContainer_Buttons/StopButton
@onready var reset_btn: Button = $HBoxContainer_Buttons/ResetButton

# 防止循环同步标志
var _syncing: bool = false


func _ready():
	_setup_inner_sliders()
	_setup_outer_sliders()
	_setup_target_input()
	_setup_init_angle()
	_setup_control_mode()
	_setup_buttons()


func _setup_inner_sliders():
	inner_kp_slider.min_value = 0.0
	inner_kp_slider.max_value = 10000.0
	inner_kp_slider.step = 10.0
	inner_kp_slider.value = pendulum_pid.kp
	inner_kp_slider.value_changed.connect(_on_inner_kp_slider_changed)

	inner_ki_slider.min_value = 0.0
	inner_ki_slider.max_value = 100.0
	inner_ki_slider.step = 0.1
	inner_ki_slider.value = pendulum_pid.ki
	inner_ki_slider.value_changed.connect(_on_inner_ki_slider_changed)

	inner_kd_slider.min_value = 0.0
	inner_kd_slider.max_value = 1000.0
	inner_kd_slider.step = 1.0
	inner_kd_slider.value = pendulum_pid.kd
	inner_kd_slider.value_changed.connect(_on_inner_kd_slider_changed)

	_setup_spin(inner_kp_spin, inner_kp_slider)
	_setup_spin(inner_ki_spin, inner_ki_slider)
	_setup_spin(inner_kd_spin, inner_kd_slider)
	inner_kp_spin.value_changed.connect(_on_inner_kp_spin_changed)
	inner_ki_spin.value_changed.connect(_on_inner_ki_spin_changed)
	inner_kd_spin.value_changed.connect(_on_inner_kd_spin_changed)


func _setup_outer_sliders():
	outer_kp_slider.min_value = 0.0
	outer_kp_slider.max_value = 0.1
	outer_kp_slider.step = 0.0001
	outer_kp_slider.value = position_pid.kp
	outer_kp_slider.value_changed.connect(_on_outer_kp_slider_changed)

	outer_ki_slider.min_value = 0.0
	outer_ki_slider.max_value = 1.0
	outer_ki_slider.step = 0.001
	outer_ki_slider.value = position_pid.ki
	outer_ki_slider.value_changed.connect(_on_outer_ki_slider_changed)

	outer_kd_slider.min_value = 0.0
	outer_kd_slider.max_value = 1.0
	outer_kd_slider.step = 0.001
	outer_kd_slider.value = position_pid.kd
	outer_kd_slider.value_changed.connect(_on_outer_kd_slider_changed)

	_setup_spin(outer_kp_spin, outer_kp_slider)
	_setup_spin(outer_ki_spin, outer_ki_slider)
	_setup_spin(outer_kd_spin, outer_kd_slider)
	outer_kp_spin.value_changed.connect(_on_outer_kp_spin_changed)
	outer_ki_spin.value_changed.connect(_on_outer_ki_spin_changed)
	outer_kd_spin.value_changed.connect(_on_outer_kd_spin_changed)


func _setup_spin(spin: SpinBox, slider: HSlider):
	spin.min_value = slider.min_value
	spin.max_value = slider.max_value
	spin.step = slider.step
	spin.value = slider.value
	spin.custom_minimum_size.x = 80
	spin.select_all_on_focus = true
	spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _setup_target_input():
	# 目标位置滑动条
	target_slider.min_value = 0.0
	target_slider.max_value = 1900.0
	target_slider.step = 1.0
	target_slider.value = cart.target_x
	target_slider.value_changed.connect(_on_target_slider_changed)

	target_input.placeholder_text = "目标位置x"
	target_input.text = "%.1f" % cart.target_x
	target_input.text_submitted.connect(_on_target_submitted)


func _on_target_slider_changed(value: float):
	if not _syncing:
		_syncing = true
		target_input.text = "%.1f" % value
		cart.target_x = value
		_syncing = false


func _setup_init_angle():
	# 初始角度滑动条（度数），范围 -180 到 180
	init_angle_slider.min_value = -180.0
	init_angle_slider.max_value = 180.0
	init_angle_slider.step = 0.1
	init_angle_slider.value = 0.0
	init_angle_slider.value_changed.connect(_on_init_angle_slider_changed)

	_setup_spin(init_angle_spin, init_angle_slider)
	init_angle_spin.value_changed.connect(_on_init_angle_spin_changed)


func _setup_control_mode():
	btn_single.pressed.connect(_on_single_pressed)
	btn_double.pressed.connect(_on_double_pressed)
	btn_lqr.disabled = true  # LQR未实现
	_update_mode_buttons()


func _setup_buttons():
	stop_btn.pressed.connect(_on_stop_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)


# --- 内环 Slider → SpinBox 同步 ---
func _on_inner_kp_slider_changed(value: float):
	pendulum_pid.kp = value
	if not _syncing:
		_syncing = true
		inner_kp_spin.value = value
		_syncing = false

func _on_inner_ki_slider_changed(value: float):
	pendulum_pid.ki = value
	if not _syncing:
		_syncing = true
		inner_ki_spin.value = value
		_syncing = false

func _on_inner_kd_slider_changed(value: float):
	pendulum_pid.kd = value
	if not _syncing:
		_syncing = true
		inner_kd_spin.value = value
		_syncing = false


# --- 内环 SpinBox → Slider 同步 ---
func _on_inner_kp_spin_changed(value: float):
	pendulum_pid.kp = value
	if not _syncing:
		_syncing = true
		inner_kp_slider.value = value
		_syncing = false

func _on_inner_ki_spin_changed(value: float):
	pendulum_pid.ki = value
	if not _syncing:
		_syncing = true
		inner_ki_slider.value = value
		_syncing = false

func _on_inner_kd_spin_changed(value: float):
	pendulum_pid.kd = value
	if not _syncing:
		_syncing = true
		inner_kd_slider.value = value
		_syncing = false


# --- 外环 Slider → SpinBox 同步 ---
func _on_outer_kp_slider_changed(value: float):
	position_pid.kp = value
	if not _syncing:
		_syncing = true
		outer_kp_spin.value = value
		_syncing = false

func _on_outer_ki_slider_changed(value: float):
	position_pid.ki = value
	if not _syncing:
		_syncing = true
		outer_ki_spin.value = value
		_syncing = false

func _on_outer_kd_slider_changed(value: float):
	position_pid.kd = value
	if not _syncing:
		_syncing = true
		outer_kd_spin.value = value
		_syncing = false


# --- 外环 SpinBox → Slider 同步 ---
func _on_outer_kp_spin_changed(value: float):
	position_pid.kp = value
	if not _syncing:
		_syncing = true
		outer_kp_slider.value = value
		_syncing = false

func _on_outer_ki_spin_changed(value: float):
	position_pid.ki = value
	if not _syncing:
		_syncing = true
		outer_ki_slider.value = value
		_syncing = false

func _on_outer_kd_spin_changed(value: float):
	position_pid.kd = value
	if not _syncing:
		_syncing = true
		outer_kd_slider.value = value
		_syncing = false


func _on_target_submitted(new_text: String):
	if new_text.is_valid_float():
		var value = new_text.to_float()
		cart.target_x = value
		if not _syncing:
			_syncing = true
			target_slider.value = value
			_syncing = false


# --- 初始角度 Slider/SpinBox 同步 ---
func _on_init_angle_slider_changed(value: float):
	if not _syncing:
		_syncing = true
		init_angle_spin.value = value
		_syncing = false
	# 使用PhysicsServer2D设置摆杆角度，避免被物理引擎覆盖
	cart.set_pendulum_angle_deg(value)


func _on_init_angle_spin_changed(value: float):
	if not _syncing:
		_syncing = true
		init_angle_slider.value = value
		_syncing = false
	# 使用PhysicsServer2D设置摆杆角度，避免被物理引擎覆盖
	cart.set_pendulum_angle_deg(value)


func _on_single_pressed():
	cart.enable_position_loop = false
	_update_mode_buttons()


func _on_double_pressed():
	cart.enable_position_loop = true
	_update_mode_buttons()


func _update_mode_buttons():
	btn_single.button_pressed = not cart.enable_position_loop
	btn_double.button_pressed = cart.enable_position_loop


func _on_stop_pressed():
	if cart.stopped:
		cart.resume()
		stop_btn.text = "停止"
	else:
		cart.stop()
		stop_btn.text = "继续"


func _on_reset_pressed():
	cart.reset_to_initial()
	# 不改变停止按钮状态
	# 同步初始角度UI
	_syncing = true
	init_angle_slider.value = 0.0
	init_angle_spin.value = 0.0
	# 同步内环PID参数到UI
	inner_kp_slider.value = pendulum_pid.kp
	inner_ki_slider.value = pendulum_pid.ki
	inner_kd_slider.value = pendulum_pid.kd
	inner_kp_spin.value = pendulum_pid.kp
	inner_ki_spin.value = pendulum_pid.ki
	inner_kd_spin.value = pendulum_pid.kd
	# 同步外环PID参数到UI
	outer_kp_slider.value = position_pid.kp
	outer_ki_slider.value = position_pid.ki
	outer_kd_slider.value = position_pid.kd
	outer_kp_spin.value = position_pid.kp
	outer_ki_spin.value = position_pid.ki
	outer_kd_spin.value = position_pid.kd
	# 同步目标位置到UI
	target_slider.value = cart.target_x
	target_input.text = "%.1f" % cart.target_x
	_syncing = false
