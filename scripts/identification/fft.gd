extends RefCounted
class_name FFT

## ============================================================
## 快速傅里叶变换工具（radix-2 Cooley-Tukey 迭代实现）
##
## 要求输入长度 N 为 2 的幂。若不满足，compute_real 会自动补零到最近的 2 的幂。
##
## 用法：
##   var re := PackedFloat64Array([1, 2, 3, 4])
##   var im := PackedFloat64Array([0, 0, 0, 0])
##   FFT.fft(re, im)        # 原地变换，re/im 变为频域
##   FFT.ifft(re, im)       # 逆变换
##
## 实数信号便捷接口：
##   var spec := FFT.compute_real(signal_array)
##   # spec = {"re": PackedFloat64Array, "im": PackedFloat64Array, "n": int}
## ============================================================


## 原地正变换。re/im 长度必须相等且为 2 的幂。
static func fft(re: PackedFloat64Array, im: PackedFloat64Array) -> void:
	var n := re.size()
	if n <= 1:
		return
	# 位反转重排
	_bit_reverse(re, im, n)

	# 蝶形运算：size 从 2 到 N
	var size := 2
	while size <= n:
		var half := size / 2
		var angle := -TAU / size  # 正向 FFT 取负角
		var w_step_re := cos(angle)
		var w_step_im := sin(angle)

		var group_start := 0
		while group_start < n:
			var w_re := 1.0
			var w_im := 0.0
			for j in half:
				var idx1 := group_start + j
				var idx2 := idx1 + half
				var t_re := w_re * re[idx2] - w_im * im[idx2]
				var t_im := w_re * im[idx2] + w_im * re[idx2]
				re[idx2] = re[idx1] - t_re
				im[idx2] = im[idx1] - t_im
				re[idx1] += t_re
				im[idx1] += t_im
				# 旋转因子
				var nw_re := w_re * w_step_re - w_im * w_step_im
				w_im = w_re * w_step_im + w_im * w_step_re
				w_re = nw_re
			group_start += size
		size *= 2


## 原地逆变换。re/im 长度必须相等且为 2 的幂。
static func ifft(re: PackedFloat64Array, im: PackedFloat64Array) -> void:
	var n := re.size()
	if n <= 1:
		return
	# 共轭
	for i in n:
		im[i] = -im[i]
	fft(re, im)
	# 共轭并除以 N
	var inv_n := 1.0 / n
	for i in n:
		re[i] *= inv_n
		im[i] = -im[i] * inv_n


## 实数信号 FFT 便捷接口。
## 自动补零到最近的 2 的幂。返回 {"re": ..., "im": ..., "n": 补零后长度, "n_orig": 原始长度}
static func compute_real(samples: PackedFloat64Array) -> Dictionary:
	var n_orig := samples.size()
	var n := _next_pow2(n_orig)
	var re := PackedFloat64Array()
	re.resize(n)
	var im := PackedFloat64Array()
	im.resize(n)
	for i in n_orig:
		re[i] = samples[i]
	fft(re, im)
	return {"re": re, "im": im, "n": n, "n_orig": n_orig}


## 单边幅频谱（只返回 0 ~ N/2 的幅度），未归一化
static func magnitude_spectrum(samples: PackedFloat64Array) -> PackedFloat64Array:
	var spec := compute_real(samples)
	var n: int = spec["n"]
	var half: int = n / 2 + 1
	var re: PackedFloat64Array = spec["re"]
	var im: PackedFloat64Array = spec["im"]
	var mag := PackedFloat64Array()
	mag.resize(half)
	for k in half:
		mag[k] = sqrt(re[k] * re[k] + im[k] * im[k])
	return mag


# ───────── 窗函数（周期性形式，分母用 N，适用于 FFT/Welch 法） ─────────

static func hann(n: int) -> PackedFloat64Array:
	var w := PackedFloat64Array()
	w.resize(n)
	if n == 1:
		w[0] = 1.0
		return w
	for i in n:
		w[i] = 0.5 * (1.0 - cos(TAU * i / n))
	return w


static func hamming(n: int) -> PackedFloat64Array:
	var w := PackedFloat64Array()
	w.resize(n)
	if n == 1:
		w[0] = 1.0
		return w
	for i in n:
		w[i] = 0.54 - 0.46 * cos(TAU * i / n)
	return w


static func blackman(n: int) -> PackedFloat64Array:
	var w := PackedFloat64Array()
	w.resize(n)
	if n == 1:
		w[0] = 1.0
		return w
	for i in n:
		var phi := TAU * i / n
		w[i] = 0.42 - 0.5 * cos(phi) + 0.08 * cos(2.0 * phi)
	return w


## 窗函数修正系数，用于功率谱密度归一化
## ENBW (Equivalent Noise BandWidth) / N，对周期图法做幅度修正
static func window_enbw(w: PackedFloat64Array) -> float:
	var n := w.size()
	var s_sq := 0.0
	var s := 0.0
	for i in n:
		s_sq += w[i] * w[i]
		s += w[i]
	if s == 0.0:
		return 1.0
	return (n * s_sq) / (s * s)


# ───────── 内部辅助 ─────────

static func _bit_reverse(re: PackedFloat64Array, im: PackedFloat64Array, n: int) -> void:
	var bits := 0
	var tmp := n
	while tmp > 1:
		bits += 1
		tmp >>= 1
	for i in n:
		var j := _reverse_bits(i, bits)
		if j > i:
			var tr := re[i]
			re[i] = re[j]
			re[j] = tr
			var ti := im[i]
			im[i] = im[j]
			im[j] = ti


static func _reverse_bits(x: int, bits: int) -> int:
	var result := 0
	for i in bits:
		result = (result << 1) | (x & 1)
		x >>= 1
	return result


static func _next_pow2(n: int) -> int:
	var p := 1
	while p < n:
		p <<= 1
	return p


## 判断 n 是否为 2 的幂
static func is_pow2(n: int) -> bool:
	return n > 0 and (n & (n - 1)) == 0
