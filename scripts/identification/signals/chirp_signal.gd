extends ExcitationSignal
class_name ChirpSignal

## ============================================================
## 线性扫频信号 Chirp
##
## 瞬时频率 f(t) = f0 + k·t，从 f0 线性增至 f1
## 相位 φ(t) = 2π·(f0·t + (k/2)·t²)
## u(t) = A·sin(φ(t))
##
## 用法：辨识主力信号，单次激励覆盖 [f0, f1] 全段频率。
## 配合 Welch 法可直接估计频响函数。
## ============================================================

## 扫频起始频率 (Hz)
@export var f0: float = 0.1

## 扫频终止频率 (Hz)
@export var f1: float = 10.0

## 扫频总时长 (s)
@export var duration: float = 20.0

## 扫频模式：0=线性, 1=对数
@export_enum("Linear", "Logarithmic") var sweep_mode: int = 0

## 起始相位 (rad)
@export var phase_offset: float = 0.0

var _k: float = 0.0          # 线性扫频速率
var _log_ratio: float = 0.0  # f1/f0，对数扫频用
var _ended: bool = false


func _ready():
	_recompute_params()


func _recompute_params():
	if duration <= 0.0:
		duration = 1.0
	_k = (f1 - f0) / duration
	if f0 > 0.0:
		_log_ratio = f1 / f0
	else:
		_log_ratio = 1.0
		_log_ratio = max(_log_ratio, 1.0)
	_ended = false


func get_value(t: float) -> float:
	t = _to_relative(t)
	if t < 0.0:
		return 0.0
	if t >= duration:
		if auto_stop and not _ended:
			_ended = true
			finished.emit()
		# 信号结束后保持最后频率的 sin
		t = duration

	var phi: float
	if sweep_mode == 0:
		# 线性：φ = 2π·(f0·t + (k/2)·t²)
		phi = TAU * (f0 * t + 0.5 * _k * t * t)
	else:
		# 对数：f(t) = f0·(f1/f0)^(t/T)
		# φ = 2π · f0·T/ln(f1/f0) · ((f1/f0)^(t/T) - 1)
		var ln_ratio := log(_log_ratio) if _log_ratio > 1.0 else 1.0
		phi = TAU * f0 * duration / ln_ratio * (pow(_log_ratio, t / duration) - 1.0)

	return amplitude * sin(phi + phase_offset)


func get_duration() -> float:
	return duration


func get_frequency_range() -> Vector2:
	return Vector2(f0, f1)


func reset():
	_ended = false
	_recompute_params()


func get_config() -> Dictionary:
	return {
		"type": "Chirp",
		"amplitude": amplitude,
		"f0": f0,
		"f1": f1,
		"duration": duration,
		"sweep_mode": "Linear" if sweep_mode == 0 else "Log",
	}
