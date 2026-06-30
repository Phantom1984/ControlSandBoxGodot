extends VBoxContainer

@export var pid_controller: PIDController
@export var slider_body: RigidBody2D   # 新增：引用滑块刚体

@onready var target_input: LineEdit = $HBoxContainer_TargetPos/TargetInput
@onready var target_slider: HSlider = $HBoxContainer_TargetPos/HSlider
@onready var kp_slider: HSlider = $HBoxContainer_Kp/HSlider
@onready var ki_slider: HSlider = $HBoxContainer_Ki/HSlider
@onready var kd_slider: HSlider = $HBoxContainer_Kd/HSlider
@onready var kp_spin: SpinBox = $HBoxContainer_Kp/SpinBox
@onready var ki_spin: SpinBox = $HBoxContainer_Ki/SpinBox
@onready var kd_spin: SpinBox = $HBoxContainer_Kd/SpinBox
@onready var stop_btn: Button = $HBoxContainer_Buttons/StopButton
@onready var reset_btn: Button = $HBoxContainer_Buttons/ResetButton

# 防止循环同步标志
var _syncing: bool = false


func _ready():
	# 目标位置滑动条
	target_slider.min_value = 0.0
	target_slider.max_value = 1900.0
	target_slider.step = 1.0
	target_slider.value = slider_body.default_target_x
	target_slider.value_changed.connect(_on_target_slider_changed)

	target_input.placeholder_text = "目标位置"
	target_input.text = "%.1f" % slider_body.default_target_x
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

	kp_slider.value_changed.connect(_on_kp_slider_changed)
	ki_slider.value_changed.connect(_on_ki_slider_changed)
	kd_slider.value_changed.connect(_on_kd_slider_changed)

	_setup_spin(kp_spin, kp_slider)
	_setup_spin(ki_spin, ki_slider)
	_setup_spin(kd_spin, kd_slider)
	kp_spin.value_changed.connect(_on_kp_spin_changed)
	ki_spin.value_changed.connect(_on_ki_spin_changed)
	kd_spin.value_changed.connect(_on_kd_spin_changed)

	# 停止和复位按钮
	stop_btn.pressed.connect(_on_stop_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)


func _setup_spin(spin: SpinBox, slider: HSlider):
	spin.min_value = slider.min_value
	spin.max_value = slider.max_value
	spin.step = slider.step
	spin.value = slider.value
	spin.custom_minimum_size.x = 80
	spin.select_all_on_focus = true
	spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _on_target_slider_changed(value: float):
	if not _syncing:
		_syncing = true
		target_input.text = "%.1f" % value
		slider_body.set_meta("target_x", value)
		_syncing = false


func _on_target_submitted(new_text: String):
	if new_text.is_valid_float():
		var value = new_text.to_float()
		slider_body.set_meta("target_x", value)
		if not _syncing:
			_syncing = true
			target_slider.value = value
			_syncing = false


# --- Slider → SpinBox 同步 ---
func _on_kp_slider_changed(value: float):
	pid_controller.kp = value
	if not _syncing:
		_syncing = true
		kp_spin.value = value
		_syncing = false

func _on_ki_slider_changed(value: float):
	pid_controller.ki = value
	if not _syncing:
		_syncing = true
		ki_spin.value = value
		_syncing = false

func _on_kd_slider_changed(value: float):
	pid_controller.kd = value
	if not _syncing:
		_syncing = true
		kd_spin.value = value
		_syncing = false


# --- SpinBox → Slider 同步 ---
func _on_kp_spin_changed(value: float):
	pid_controller.kp = value
	if not _syncing:
		_syncing = true
		kp_slider.value = value
		_syncing = false

func _on_ki_spin_changed(value: float):
	pid_controller.ki = value
	if not _syncing:
		_syncing = true
		ki_slider.value = value
		_syncing = false

func _on_kd_spin_changed(value: float):
	pid_controller.kd = value
	if not _syncing:
		_syncing = true
		kd_slider.value = value
		_syncing = false


func _on_stop_pressed():
	if slider_body.stopped:
		slider_body.resume()
		stop_btn.text = "停止"
	else:
		slider_body.stop()
		stop_btn.text = "继续"


func _on_reset_pressed():
	slider_body.reset_to_initial()
	# 不改变停止按钮状态
	# 同步目标位置到UI
	_syncing = true
	target_slider.value = slider_body.default_target_x
	target_input.text = "%.1f" % slider_body.default_target_x
	# 同步PID参数到UI
	kp_slider.value = pid_controller.kp
	ki_slider.value = pid_controller.ki
	kd_slider.value = pid_controller.kd
	kp_spin.value = pid_controller.kp
	ki_spin.value = pid_controller.ki
	kd_spin.value = pid_controller.kd
	_syncing = false
