extends Control
class_name IdentificationPanel

## ============================================================
## 系统辨识 UI 面板
##
## 左侧：信号配置（类型选择 + 参数）+ 实验参数 + 启停按钮
## 右侧：Bode 图（FrequencyPlotter）
##
## 用法：
##   1. 在编辑器中将此节点添加到场景
##   2. 在 Inspector 中绑定 plant（被控对象）
##   3. 运行场景，配置参数后点击"开始辨识"
## ============================================================

const ChirpSignal = preload("res://scripts/identification/chirp_signal.gd")
const SteppedSine = preload("res://scripts/identification/stepped_sine.gd")
const PRBSSignal = preload("res://scripts/identification/prbs_signal.gd")
const IdentificationExperiment = preload("res://scripts/identification/identification_experiment.gd")
const FrequencyPlotter = preload("res://scripts/identification/frequency_plotter.gd")

@export var plant: Plant

var _plotter: FrequencyPlotter
var _experiment: IdentificationExperiment

# ─── UI 元素 ───
var _signal_type_opt: OptionButton
var _param_container: VBoxContainer
var _nfft_opt: OptionButton
var _overlap_spin: SpinBox
var _output_field_opt: OptionButton
var _start_btn: Button
var _stop_btn: Button
var _status_label: Label
var _progress_bar: ProgressBar

# 当前信号参数（动态读写）
var _signal_params: Dictionary = {}

enum SigType { CHIRP, STEPPED_SINE, PRBS }

var _ui_built: bool = false


func _ready():
	_build_ui()
	_rebuild_param_ui()


func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true
	# 根 HBoxContainer：左面板 + 右 Bode 图
	var root_box := HBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 8)
	add_child(root_box)

	# ─── 左侧配置面板（固定宽度 + 滚动）───
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(320, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(left_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(scroll)

	var config_vbox := VBoxContainer.new()
	config_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(config_vbox)

	# 标题
	config_vbox.add_child(_make_label("系统辨识", 14, true))

	# ── 信号类型 ──
	config_vbox.add_child(_make_label("激励信号类型", 11, true))
	_signal_type_opt = OptionButton.new()
	_signal_type_opt.add_item("Chirp（扫频）", SigType.CHIRP)
	_signal_type_opt.add_item("SteppedSine（步进正弦）", SigType.STEPPED_SINE)
	_signal_type_opt.add_item("PRBS（伪随机）", SigType.PRBS)
	_signal_type_opt.item_selected.connect(_on_signal_type_changed)
	config_vbox.add_child(_signal_type_opt)

	# ── 信号参数容器（动态）──
	config_vbox.add_child(_make_label("信号参数", 11, true))
	_param_container = VBoxContainer.new()
	_param_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_param_container.add_theme_constant_override("separation", 4)
	config_vbox.add_child(_param_container)

	# ── 实验参数 ──
	config_vbox.add_child(_make_label("实验参数", 11, true))

	_nfft_opt = OptionButton.new()
	for n in [256, 512, 1024, 2048, 4096]:
		_nfft_opt.add_item("%d" % n, n)
	_nfft_opt.select(1)  # 默认 512
	config_vbox.add_child(_make_row("FFT 长度", _nfft_opt))

	_overlap_spin = SpinBox.new()
	_overlap_spin.min_value = 0.0
	_overlap_spin.max_value = 0.9
	_overlap_spin.step = 0.1
	_overlap_spin.value = 0.5
	_overlap_spin.custom_minimum_size.x = 80
	config_vbox.add_child(_make_row("重叠比例", _overlap_spin))

	_output_field_opt = OptionButton.new()
	_output_field_opt.add_item("velocity_x（速度）", 0)
	_output_field_opt.add_item("position_x（位置）", 1)
	config_vbox.add_child(_make_row("输出通道", _output_field_opt))

	# ── 按钮 ──
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 6)
	config_vbox.add_child(btn_box)

	_start_btn = Button.new()
	_start_btn.text = "开始辨识"
	_start_btn.custom_minimum_size = Vector2(120, 32)
	_start_btn.pressed.connect(_on_start_pressed)
	btn_box.add_child(_start_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "停止"
	_stop_btn.custom_minimum_size = Vector2(80, 32)
	_stop_btn.disabled = true
	_stop_btn.pressed.connect(_on_stop_pressed)
	btn_box.add_child(_stop_btn)

	# ── 状态 ──
	config_vbox.add_child(_make_label("状态", 11, true))
	_status_label = _make_label("空闲", 10, false)
	config_vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.custom_minimum_size = Vector2(0, 20)
	config_vbox.add_child(_progress_bar)

	# ─── 右侧 Bode 图 ───
	_plotter = FrequencyPlotter.new()
	_plotter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plotter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_plotter)


# ───────── 信号参数 UI 构建 ─────────

func _on_signal_type_changed(_idx: int) -> void:
	_rebuild_param_ui()


func _rebuild_param_ui() -> void:
	for child in _param_container.get_children():
		child.queue_free()
	_signal_params.clear()

	var sig_type: int = _signal_type_opt.get_selected_id()
	match sig_type:
		SigType.CHIRP:
			_build_chirp_params()
		SigType.STEPPED_SINE:
			_build_stepped_sine_params()
		SigType.PRBS:
			_build_prbs_params()


func _build_chirp_params() -> void:
	_add_float_row("f0 (Hz)", "f0", 0.1, 0.01, 50.0, 0.1, 0.1)
	_add_float_row("f1 (Hz)", "f1", 10.0, 0.01, 100.0, 0.1, 10.0)
	_add_float_row("时长 (s)", "duration", 20.0, 1.0, 120.0, 1.0, 20.0)
	_add_float_row("幅值", "amplitude", 500.0, 1.0, 5000.0, 10.0, 500.0)
	_add_option_row("扫频模式", "sweep_mode", ["线性", "对数"], 0)


func _build_stepped_sine_params() -> void:
	_add_float_row("f_min (Hz)", "f_min", 0.1, 0.01, 50.0, 0.1, 0.1)
	_add_float_row("f_max (Hz)", "f_max", 10.0, 0.01, 100.0, 0.1, 10.0)
	_add_int_row("频率点数", "num_points", 5, 100, 1, 20)
	_add_float_row("驻留 (s)", "dwell_time", 2.0, 0.5, 30.0, 0.5, 2.0)
	_add_float_row("幅值", "amplitude", 500.0, 1.0, 5000.0, 10.0, 500.0)
	_add_option_row("频率分布", "freq_spacing", ["对数", "线性"], 0)


func _build_prbs_params() -> void:
	_add_option_row("LFSR 阶数", "lfsr_order", ["7", "9", "10", "11", "15", "20", "23", "31"], 4)
	_add_float_row("时钟周期 (s)", "clock_period", 0.01, 0.001, 0.5, 0.001, 0.01)
	_add_int_row("重复次数", "repeat_count", 1, 50, 1, 1)
	_add_float_row("幅值", "amplitude", 500.0, 1.0, 5000.0, 10.0, 500.0)


# ───────── 辅助：UI 行构建 ─────────

func _make_label(text: String, font_size: int, bold: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	if bold:
		lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	return lbl


func _make_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl := _make_label(label_text, 10, false)
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _add_float_row(label: String, key: String, default: float, min_v: float, max_v: float, step: float, _unused: float) -> void:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = default
	spin.custom_minimum_size.x = 100
	spin.suffix = ""
	spin.value_changed.connect(func(v: float): _signal_params[key] = v)
	_signal_params[key] = default
	_param_container.add_child(_make_row(label, spin))


func _add_int_row(label: String, key: String, min_v: int, max_v: int, step: int, default: int) -> void:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = default
	spin.custom_minimum_size.x = 100
	spin.value_changed.connect(func(v: float): _signal_params[key] = int(v))
	_signal_params[key] = default
	_param_container.add_child(_make_row(label, spin))


func _add_option_row(label: String, key: String, options: Array, default_idx: int) -> void:
	var opt := OptionButton.new()
	for i in options.size():
		opt.add_item(options[i], i)
	opt.select(default_idx)
	opt.item_selected.connect(func(idx: int): _signal_params[key] = idx)
	_signal_params[key] = default_idx
	_param_container.add_child(_make_row(label, opt))


# ───────── 实验流程 ─────────

func _on_start_pressed() -> void:
	if Engine.is_editor_hint():
		return
	if not plant:
		_status_label.text = "错误：未绑定 Plant"
		return

	# 创建激励信号
	var excitation: Node = _create_excitation()
	if excitation == null:
		_status_label.text = "错误：信号创建失败"
		return

	# 关闭环境扰动
	if plant.has_method("set_environment"):
		plant.set_environment({"friction": 0.0, "drag": 0.0, "dist_force": 0.0, "dist_freq": 0.0})

	# 创建实验
	if _experiment:
		_experiment.queue_free()
	_experiment = IdentificationExperiment.new()
	add_child(_experiment)

	var output_field: String = "velocity_x" if _output_field_opt.get_selected_id() == 0 else "position_x"
	var nfft: int = _nfft_opt.get_selected_id()
	var overlap: float = _overlap_spin.value
	_experiment.configure(plant, excitation, "control", output_field, nfft, overlap, 0.0)

	_experiment.state_changed.connect(_on_exp_state_changed)
	_experiment.progress.connect(_on_exp_progress)
	_experiment.completed.connect(_on_exp_completed)

	_status_label.text = "启动中..."
	_progress_bar.value = 0.0
	_start_btn.disabled = true
	_stop_btn.disabled = false
	_plotter.clear_data()

	_experiment.start()


func _on_stop_pressed() -> void:
	if _experiment and _experiment.is_running():
		_experiment.stop()
		_status_label.text = "已停止"


func _on_exp_state_changed(s: int) -> void:
	var names := ["IDLE", "RUNNING", "ANALYZING", "DONE", "ERROR"]
	_status_label.text = "状态: %s" % names[s]
	if s == IdentificationExperiment.State.DONE or s == IdentificationExperiment.State.ERROR:
		_start_btn.disabled = false
		_stop_btn.disabled = true


func _on_exp_progress(ratio: float) -> void:
	_progress_bar.value = ratio


func _on_exp_completed(result: Dictionary) -> void:
	if result.is_empty():
		_status_label.text = "辨识失败（数据不足）"
		_progress_bar.value = 0.0
		return

	# 显示 Bode 图
	var freqs: PackedFloat64Array = result["freqs"]
	var H_mag: PackedFloat64Array = result["H_mag"]
	var H_phase: PackedFloat64Array = result["H_phase"]
	var coh: PackedFloat64Array = result["coh"]
	_plotter.set_data(freqs, H_mag, H_phase, coh)

	var n: int = result["n_samples"]
	var sr: float = result["sample_rate"]
	var nseg: int = result["nseg"]
	_status_label.text = "完成: N=%d, fs=%.0fHz, 分段=%d" % [n, sr, nseg]
	_progress_bar.value = 1.0


# ───────── 信号创建 ─────────

func _create_excitation() -> Node:
	var sig_type: int = _signal_type_opt.get_selected_id()
	var exc: Node = null
	match sig_type:
		SigType.CHIRP:
			exc = _create_chirp()
		SigType.STEPPED_SINE:
			exc = _create_stepped_sine()
		SigType.PRBS:
			exc = _create_prbs()
	if exc:
		exc.auto_stop = true
	return exc


func _create_chirp() -> ChirpSignal:
	var s := ChirpSignal.new()
	s.f0 = _signal_params.get("f0", 0.1)
	s.f1 = _signal_params.get("f1", 10.0)
	s.duration = _signal_params.get("duration", 20.0)
	s.amplitude = _signal_params.get("amplitude", 500.0)
	s.sweep_mode = _signal_params.get("sweep_mode", 0)
	return s


func _create_stepped_sine() -> SteppedSine:
	var s := SteppedSine.new()
	s.f_min = _signal_params.get("f_min", 0.1)
	s.f_max = _signal_params.get("f_max", 10.0)
	s.num_points = _signal_params.get("num_points", 20)
	s.dwell_time = _signal_params.get("dwell_time", 2.0)
	s.amplitude = _signal_params.get("amplitude", 500.0)
	s.freq_spacing = _signal_params.get("freq_spacing", 0)
	return s


func _create_prbs() -> PRBSSignal:
	var s := PRBSSignal.new()
	var orders := [7, 9, 10, 11, 15, 20, 23, 31]
	var idx: int = _signal_params.get("lfsr_order", 4)
	s.lfsr_order = orders[idx]
	s.clock_period = _signal_params.get("clock_period", 0.01)
	s.repeat_count = _signal_params.get("repeat_count", 1)
	s.amplitude = _signal_params.get("amplitude", 500.0)
	return s
