extends ExcitationSignal
class_name SteppedSine

## ============================================================
## 步进正弦信号 Stepped Sine
##
## 逐个频率点驻留，每个频率输出纯正弦：
##   u(t) = A·sin(2π·fk·(t - tk_start) + φk)
##
## 频率切换时相位连续（避免宽频瞬态）。
## φk 由前一频点结束时的相位累积而来。
##
## 优势：每个频点 SNR 极高，适合高精度频响测量。
## 劣势：慢，总时长 = Σ dwell_k
## ============================================================

## 最低频率 (Hz)
@export var f_min: float = 0.1

## 最高频率 (Hz)
@export var f_max: float = 10.0

## 频率点数（对数分布）
@export var num_points: int = 20

## 每个频点驻留时长 (s)
@export var dwell_time: float = 2.0

## 频率分布：0=对数, 1=线性
@export_enum("Logarithmic", "Linear") var freq_spacing: int = 0

## 用户自定义频率列表（非空时覆盖自动生成）
@export var custom_freqs: PackedFloat64Array = []

var _frequencies: PackedFloat64Array = []
var _start_times: PackedFloat64Array = []  # 每个频点的起始时间
var _start_phases: PackedFloat64Array = [] # 每个频点的起始相位
var _total_duration: float = 0.0
var _ended: bool = false


func _ready():
	_build_schedule()


func _build_schedule():
	if custom_freqs.size() > 0:
		_frequencies = custom_freqs.duplicate()
	else:
		_frequencies.resize(num_points)
		for i in num_points:
			if freq_spacing == 0:
				# 对数分布
				var ratio := pow(f_max / f_min, 1.0 / (num_points - 1))
				_frequencies[i] = f_min * pow(ratio, i)
			else:
				_frequencies[i] = f_min + (f_max - f_min) * i / (num_points - 1)

	var n := _frequencies.size()
	_start_times.resize(n)
	_start_phases.resize(n)
	_total_duration = 0.0
	var phase: float = 0.0
	for i in n:
		_start_times[i] = _total_duration
		_start_phases[i] = phase
		# 本频点结束时累积的相位
		phase += TAU * _frequencies[i] * dwell_time
		_total_duration += dwell_time
	_ended = false


## 根据时间 t 找到当前频点索引（二分查找）
func _find_segment(t: float) -> int:
	var n := _frequencies.size()
	if n == 0:
		return -1
	if t < _start_times[0]:
		return 0
	# 二分查找最后一个 start_times[i] <= t 的 i
	var lo := 0
	var hi := n - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if _start_times[mid] <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo


func get_value(t: float) -> float:
	t = _to_relative(t)
	if t < 0.0 or _frequencies.is_empty():
		return 0.0
	if t >= _total_duration:
		if auto_stop and not _ended:
			_ended = true
			finished.emit()
		# 信号结束后输出 0
		return 0.0

	var idx := _find_segment(t)
	var fk: float = _frequencies[idx]
	var tk: float = _start_times[idx]
	var phi_k: float = _start_phases[idx]
	var local_t := t - tk

	return amplitude * sin(TAU * fk * local_t + phi_k)


func get_duration() -> float:
	return _total_duration


func get_frequency_range() -> Vector2:
	if _frequencies.is_empty():
		return Vector2.ZERO
	return Vector2(_frequencies[0], _frequencies[_frequencies.size() - 1])


func get_frequencies() -> PackedFloat64Array:
	return _frequencies


func reset():
	_ended = false
	_build_schedule()


func get_config() -> Dictionary:
	return {
		"type": "SteppedSine",
		"amplitude": amplitude,
		"f_min": f_min,
		"f_max": f_max,
		"num_points": num_points,
		"dwell_time": dwell_time,
		"spacing": "Log" if freq_spacing == 0 else "Linear",
		"total_duration": _total_duration,
	}
