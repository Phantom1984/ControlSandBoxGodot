extends Node
class_name ExcitationSignal

## ============================================================
## 激励信号基类
##
## 所有激励信号（Chirp / SteppedSine / PRBS ...）继承此类。
## Plant 通过 @export var excitation 持有引用，每帧调用 get_value(t) 注入。
##
## 子类必须重写：
##   - get_value(t)          返回 t 时刻的激励值
##   - get_duration()         返回信号总时长（秒），INF 表示无限
##   - get_frequency_range()  返回 (fmin, fmax)
##
## 可选重写：
##   - reset()                重置内部状态
##   - get_config()           返回配置字典（UI 显示用）
## ============================================================

signal finished()

## 激励幅值（峰值）
@export var amplitude: float = 1.0

## 是否在信号结束后自动停止（由 IdentificationExperiment 读取）
@export var auto_stop: bool = true

## 实验开始的全局时间戳（由 start() 设置，-1 表示未启动）
var _t0: float = -1.0


## 标记实验开始，记录全局时间基准
func start(t: float) -> void:
	_t0 = t
	reset()


## 返回 t 时刻的激励值。t 为全局时间，内部转为相对时间。
func get_value(t: float) -> float:
	return 0.0


## 将全局时间转为相对时间（从实验开始算起）
func _to_relative(t: float) -> float:
	if _t0 < 0.0:
		return -1.0  # 未启动
	return t - _t0


## 信号总时长（秒）。INF 表示持续到手动停止
func get_duration() -> float:
	return INF


## 返回频率范围 (fmin, fmax)
func get_frequency_range() -> Vector2:
	return Vector2.ZERO


## 重置内部状态（相位累积器、LFSR 等）
func reset():
	pass


## 返回配置字典，供 UI 显示
func get_config() -> Dictionary:
	return {"amplitude": amplitude, "auto_stop": auto_stop}
