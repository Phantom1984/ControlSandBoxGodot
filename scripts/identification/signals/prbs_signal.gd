extends ExcitationSignal
class_name PRBSSignal

## ============================================================
## 伪随机二进制序列 PRBS
##
## 基于 LFSR（线性反馈移位寄存器）生成 ±A 的二进制信号。
## 自相关近似 δ 函数，频谱在时钟频率内近似平谱。
##
## n 阶 LFSR 周期 N = 2ⁿ - 1
## 时钟周期 Δt 决定最高辨识频率 fmax ≈ 1/(3·Δt)
##
## 适合时域辨识（ARX 等）。
## ============================================================

## LFSR 阶数（7/10/15/31 常用）
@export var lfsr_order: int = 15

## 时钟周期 (s)，即每个码元持续时间
@export var clock_period: float = 0.01

## 序列重复次数（0=无限循环）
@export var repeat_count: int = 1

## LFSR 初始种子（非零）
@export var seed: int = 1

# 反馈多项式抽头表（最大长度 LFSR，本原多项式）
# key = 阶数, value = [抽头位置...]（从 1 开始计数，多项式系数）
const _TAP_TABLE = {
	7: [7, 3],       # x^7 + x^3 + 1
	9: [9, 4],       # x^9 + x^4 + 1
	10: [10, 3],     # x^10 + x^3 + 1
	11: [11, 2],     # x^11 + x^2 + 1
	15: [15, 14],    # x^15 + x^14 + 1
	20: [20, 3],     # x^20 + x^3 + 1
	23: [23, 18],    # x^23 + x^18 + 1
	31: [31, 3],     # x^31 + x^3 + 1
}

var _state: int = 1
var _taps: Array = []
var _sequence_length: int = 0       # 一个周期 N = 2^n - 1
var _total_duration: float = 0.0   # 总时长 = N * Δt * repeat
var _ended: bool = false


func _ready():
	_build()


func _build():
	# 选抽头
	if _TAP_TABLE.has(lfsr_order):
		_taps = _TAP_TABLE[lfsr_order]
	else:
		# 默认用最高位和次高位
		_taps = [lfsr_order, lfsr_order - 1]

	_sequence_length = (1 << lfsr_order) - 1
	if repeat_count > 0:
		_total_duration = _sequence_length * clock_period * repeat_count
	else:
		_total_duration = INF

	_state = seed if seed != 0 else 1
	_ended = false


## 生成一个 LFSR 输出位（Fibonacci LFSR，左移方式）
## 输出最高位，反馈进最低位。任何非零 seed 均可产生最大长度序列。
func _lfsr_next_bit() -> int:
	# 输出即将移出的最高位
	var output: int = (_state >> (lfsr_order - 1)) & 1
	# 计算反馈位 = 指定抽点位置的异或
	var feedback: int = 0
	for tap in _taps:
		feedback ^= (_state >> (tap - 1)) & 1
	# 左移，反馈位进最低位，限制 n 位
	_state = ((_state << 1) | feedback) & ((1 << lfsr_order) - 1)
	return output


func get_value(t: float) -> float:
	t = _to_relative(t)
	if t < 0.0:
		return 0.0

	if _total_duration != INF and t >= _total_duration:
		if auto_stop and not _ended:
			_ended = true
			finished.emit()
		return 0.0

	# 计算当前码元索引
	var code_idx := int(t / clock_period)

	# 如果无限循环，取模
	if _total_duration == INF or repeat_count == 0:
		code_idx = code_idx % _sequence_length
	else:
		# 有限重复：取模到单个周期内
		code_idx = code_idx % _sequence_length

	# 从当前 LFSR 状态生成第 code_idx 个码元
	# 为了 O(1) 查询，预先生成完整周期序列
	# （序列长度可达 32767，预生成可接受）
	return _get_code(code_idx)


var _cached_sequence: PackedByteArray = []
var _cache_built: bool = false


func _build_cache():
	_cached_sequence.resize(_sequence_length)
	_state = seed if seed != 0 else 1
	# 先生成完整周期
	for i in _sequence_length:
		_cached_sequence[i] = _lfsr_next_bit()
	_cache_built = true


func _get_code(idx: int) -> float:
	if not _cache_built:
		_build_cache()
	var bit: int = _cached_sequence[idx % _sequence_length]
	return amplitude if bit == 1 else -amplitude


func get_duration() -> float:
	return _total_duration


func get_frequency_range() -> Vector2:
	# PRBS 频谱在 [1/(N·Δt), 1/(3·Δt)] 内近似平谱
	var f_low := 1.0 / (_sequence_length * clock_period)
	var f_high := 1.0 / (3.0 * clock_period)
	return Vector2(f_low, f_high)


func reset():
	_state = seed if seed != 0 else 1
	_ended = false
	_cache_built = false
	_cached_sequence.resize(0)
	_build()


func get_config() -> Dictionary:
	return {
		"type": "PRBS",
		"amplitude": amplitude,
		"lfsr_order": lfsr_order,
		"clock_period": clock_period,
		"sequence_length": _sequence_length,
		"repeat_count": repeat_count,
		"total_duration": _total_duration,
	}
