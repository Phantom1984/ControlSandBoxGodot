extends RefCounted
class_name DataAcquirer

## ============================================================
## 数据采集器（SISO）
##
## 同步采集输入 u 和输出 y 的完整时间序列，供频域/时域辨识使用。
## 由 IdentificationExperiment 每帧调用 record()，而非自动监听信号。
##
## 采集完成后通过 get_data() 导出，传给 WelchEstimator 或时域辨识器。
## ============================================================

## 输入字段名（通常是控制器输出 "control"）
var input_field: String = "control"

## 输出字段名（如 "position_x" 或 "angle"）
var output_field: String = "position_x"

## 采集到的数据
var times: PackedFloat64Array = []
var inputs: PackedFloat64Array = []
var outputs: PackedFloat64Array = []

var recording: bool = false
var _start_time: float = -1.0


func start():
	clear()
	recording = true
	_start_time = -1.0


func stop():
	recording = false


func clear():
	times.resize(0)
	inputs.resize(0)
	outputs.resize(0)
	_start_time = -1.0


## 每帧调用，记录一组数据点
func record(t: float, input_val: float, output_val: float):
	if not recording:
		return
	if _start_time < 0.0:
		_start_time = t
	times.append(t - _start_time)  # 存相对时间，从 0 开始
	inputs.append(input_val)
	outputs.append(output_val)


## 从 Plant 的 state_updated 信号回调中记录（便捷接口）
func record_from_state(t: float, state: Dictionary):
	if not recording:
		return
	record(t, state.get(input_field, 0.0), state.get(output_field, 0.0))


## 估算实际采样率 (Hz)
func estimate_sample_rate() -> float:
	var n := times.size()
	if n < 2:
		return 0.0
	var duration := times[n - 1] - times[0]
	if duration <= 0.0:
		return 0.0
	return float(n - 1) / duration


## 导出数据给分析器
func get_data() -> Dictionary:
	return {
		"times": times.duplicate(),
		"inputs": inputs.duplicate(),
		"outputs": outputs.duplicate(),
		"n": times.size(),
		"sample_rate": estimate_sample_rate(),
		"duration": times[times.size() - 1] if times.size() > 0 else 0.0,
	}


func size() -> int:
	return times.size()


func is_recording() -> bool:
	return recording
