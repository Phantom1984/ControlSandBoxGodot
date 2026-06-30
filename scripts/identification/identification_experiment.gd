extends Node
class_name IdentificationExperiment

## ============================================================
## 辨识实验状态机
##
## 职责：
##   1. 接入 Plant，注入激励信号（开环辨识）
##   2. 同步采集 u/y 时间序列（DataAcquirer）
##   3. 实验结束后调用 WelchEstimator 分析
##   4. 广播完成信号，携带 Bode 图数据
##
## 状态流转：IDLE → RUNNING → ANALYZING → DONE
##
## 用法：
##   var exp := IdentificationExperiment.new()
##   exp.configure(plant, chirp, "control", "position_x", 1024, 0.5)
##   exp.start()
##   await exp.completed
##   var result = exp.get_result()
## ============================================================

signal completed(result: Dictionary)
signal progress(ratio: float)  # 0~1，实验进度
signal state_changed(state: int)

enum State { IDLE, RUNNING, ANALYZING, DONE, ERROR }

const DataAcquirer = preload("res://scripts/identification/estimators/data_acquirer.gd")
const WelchEstimator = preload("res://scripts/identification/estimators/welch_estimator.gd")
const PassThroughController = preload("res://scripts/identification/pass_through_controller.gd")

var state: int = State.IDLE

var _plant: Plant = null
var _excitation: ExcitationSignal = null
var _acquirer: DataAcquirer = null
var _estimator: WelchEstimator = null
var _pass_through: PassThroughController = null

var _original_controller: ControllerBase = null
var _original_excitation: Node = null

var _start_time: float = 0.0
var _duration: float = 0.0  # 0 表示由激励信号决定
var _result: Dictionary = {}


## 配置实验
## plant:         被控对象
## excitation:    激励信号
## input_field:   采集的输入字段（通常 "control"）
## output_field:  采集的输出字段（如 "position_x"）
## nfft:          Welch FFT 长度
## overlap:       Welch 重叠比例
## duration:      实验时长（0 = 由激励信号自动决定）
func configure(
		plant: Plant,
		excitation: ExcitationSignal,
		input_field: String = "control",
		output_field: String = "position_x",
		nfft: int = 1024,
		overlap: float = 0.5,
		duration: float = 0.0
	) -> void:
	_plant = plant
	_excitation = excitation
	_duration = duration

	_acquirer = DataAcquirer.new()
	_acquirer.input_field = input_field
	_acquirer.output_field = output_field

	_estimator = WelchEstimator.new()
	_estimator.nfft = nfft
	_estimator.overlap_ratio = overlap


func start() -> void:
	if state != State.IDLE:
		push_warning("[IdentificationExperiment] 非空闲状态，无法启动")
		return
	if not _plant or not _excitation:
		push_error("[IdentificationExperiment] plant 或 excitation 未设置")
		_set_state(State.ERROR)
		return

	# 保存 Plant 原始配置
	_original_controller = _plant.controller
	_original_excitation = _plant.excitation

	# 创建直通控制器（开环辨识）
	if _pass_through == null:
		_pass_through = PassThroughController.new()
	_plant.controller = _pass_through
	_plant.excitation = _excitation

	# 确保激励信号在场景树中（Plant._build_setpoint 需要 excitation.has_method）
	if not _excitation.is_inside_tree():
		_plant.add_child(_excitation)

	# 启动
	_plant.resume()
	_start_time = Time.get_ticks_msec() / 1000.0
	_excitation.start(_start_time)
	_acquirer.start()

	# 连接信号
	if not _plant.state_updated.is_connected(_on_state_updated):
		_plant.state_updated.connect(_on_state_updated)
	if _excitation.auto_stop and not _excitation.finished.is_connected(_on_excitation_finished):
		_excitation.finished.connect(_on_excitation_finished)

	_set_state(State.RUNNING)


func stop() -> void:
	if state != State.RUNNING:
		return
	_finish_experiment()


func _on_state_updated(t: float, state_dict: Dictionary) -> void:
	if state != State.RUNNING:
		return
	_acquirer.record_from_state(t, state_dict)

	# 进度
	var ratio: float = 0.0
	var dur: float = _duration if _duration > 0 else _excitation.get_duration()
	if dur > 0 and dur != INF:
		ratio = clampf((t - _start_time) / dur, 0.0, 1.0)
		progress.emit(ratio)

	# 超时检查
	if _duration > 0 and (t - _start_time) >= _duration:
		_finish_experiment()


func _on_excitation_finished() -> void:
	if state != State.RUNNING:
		return
	# 激励信号结束，再采集一小段（让暂态衰减）
	# 这里直接结束，后续可以加 settle_time
	_finish_experiment()


func _finish_experiment() -> void:
	_set_state(State.ANALYZING)

	# 断开信号
	if _plant.state_updated.is_connected(_on_state_updated):
		_plant.state_updated.disconnect(_on_state_updated)
	if _excitation and _excitation.finished.is_connected(_on_excitation_finished):
		_excitation.finished.disconnect(_on_excitation_finished)

	_acquirer.stop()

	# 恢复 Plant 原始配置
	_plant.controller = _original_controller
	_plant.excitation = _original_excitation

	# 分析
	var data: Dictionary = _acquirer.get_data()
	var N: int = data["n"]
	var sr: float = data["sample_rate"]
	if N < _estimator.nfft * 2 or sr <= 0:
		push_error("[IdentificationExperiment] 数据不足: N=%d, 需要 >= %d" % [N, _estimator.nfft * 2])
		_result = {}
		_set_state(State.ERROR)
		completed.emit({})
		return

	var inputs: PackedFloat64Array = data["inputs"]
	var outputs: PackedFloat64Array = data["outputs"]
	_result = _estimator.estimate(inputs, outputs, sr)
	_result["sample_rate"] = sr
	_result["n_samples"] = N
	_result["duration"] = data["duration"]

	_set_state(State.DONE)
	completed.emit(_result)


func get_result() -> Dictionary:
	return _result


func get_acquirer() -> DataAcquirer:
	return _acquirer


func is_running() -> bool:
	return state == State.RUNNING


func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)
