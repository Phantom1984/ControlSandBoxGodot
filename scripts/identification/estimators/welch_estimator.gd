extends RefCounted
class_name WelchEstimator

## ============================================================
## Welch 频谱估计 + H1/H2 频率响应估计 + 相干函数
##
## 用法：
##   var est := WelchEstimator.new()
##   est.nfft = 1024
##   est.overlap_ratio = 0.5
##   var result := est.estimate(u_array, y_array, sample_rate)
##
## result 包含：
##   freqs  : 频率轴 (Hz)
##   H_mag  : |H1| 幅频
##   H_phase: ∠H1 相频 (rad)
##   coh    : 相干函数 γ² ∈ [0,1]
##   Gxx    : 输入自谱 PSD
##   Gyy    : 输出自谱 PSD
##   H2_mag : |H2| 幅频（对比用）
##
## 理论：
##   Gxx = (2 / (K·fs·Σw²)) · Σ|U_i|²      (单边 PSD)
##   Gxy = (2 / (K·fs·Σw²)) · Σ U_i*·Y_i    (互谱)
##   H1  = Gxy / Gxx       (抗输出噪声)
##   H2  = Gyy / conj(Gxy) (抗输入噪声)
##   γ²  = |Gxy|² / (Gxx·Gyy) ∈ [0,1]
## ============================================================

const FFT = preload("res://scripts/identification/estimators/fft.gd")

## FFT 长度（必须为 2 的幂）
var nfft: int = 1024

## 段间重叠比例 [0, 1)
var overlap_ratio: float = 0.5

## 窗函数类型：0=Hann, 1=Hamming, 2=Blackman
var window_type: int = 0


func estimate(inputs: PackedFloat64Array, outputs: PackedFloat64Array, sample_rate: float) -> Dictionary:
	var N := inputs.size()
	if outputs.size() != N or N < nfft:
		push_error("[WelchEstimator] 数据不足: N=%d, nfft=%d" % [N, nfft])
		return {}

	# 确保 nfft 为 2 的幂
	if not FFT.is_pow2(nfft):
		nfft = FFT._next_pow2(nfft)

	# 段参数
	var step := maxi(1, int(nfft * (1.0 - overlap_ratio)))
	var nseg := int((N - nfft) / step) + 1
	if nseg < 1:
		push_error("[WelchEstimator] 无法分出完整段")
		return {}

	# 窗函数
	var w := _get_window(nfft)
	var S2 := 0.0  # Σ w²
	for v in w:
		S2 += v * v
	if S2 < 1e-20:
		push_error("[WelchEstimator] 窗能量为零")
		return {}

	# 累加器（单边谱，k = 0..nfft/2）
	var nfreq := nfft / 2 + 1
	var Gxx := PackedFloat64Array()
	var Gyy := PackedFloat64Array()
	var Gxy_re := PackedFloat64Array()
	var Gxy_im := PackedFloat64Array()
	Gxx.resize(nfreq)
	Gyy.resize(nfreq)
	Gxy_re.resize(nfreq)
	Gxy_im.resize(nfreq)
	for i in nfreq:
		Gxx[i] = 0.0
		Gyy[i] = 0.0
		Gxy_re[i] = 0.0
		Gxy_im[i] = 0.0

	# 逐段 FFT
	var re_u := PackedFloat64Array()
	var im_u := PackedFloat64Array()
	var re_y := PackedFloat64Array()
	var im_y := PackedFloat64Array()
	re_u.resize(nfft)
	im_u.resize(nfft)
	re_y.resize(nfft)
	im_y.resize(nfft)

	for seg in nseg:
		var offset := seg * step
		# 加窗
		for i in nfft:
			re_u[i] = inputs[offset + i] * w[i]
			im_u[i] = 0.0
			re_y[i] = outputs[offset + i] * w[i]
			im_y[i] = 0.0
		FFT.fft(re_u, im_u)
		FFT.fft(re_y, im_y)

		# 累加功率谱（先不加单边系数和归一化，最后统一处理）
		for k in nfreq:
			var ur := re_u[k]
			var ui := im_u[k]
			var yr := re_y[k]
			var yi := im_y[k]
			Gxx[k] += ur * ur + ui * ui           # |U|²
			Gyy[k] += yr * yr + yi * yi           # |Y|²
			# U* · Y = (ur - j·ui)(yr + j·yi) = (ur·yr + ui·yi) + j·(ur·yi - ui·yr)
			Gxy_re[k] += ur * yr + ui * yi
			Gxy_im[k] += ur * yi - ui * yr

	# 归一化：单边 PSD
	# G(k) = scale / (K · fs · S2) · Σ
	# scale = 2 (k=1..nfft/2-1), 1 (DC 和 Nyquist)
	var norm_base := 1.0 / (nseg * sample_rate * S2)
	for k in nfreq:
		var scale := 2.0 if (k > 0 and k < nfreq - 1) else 1.0
		var norm := norm_base * scale
		Gxx[k] *= norm
		Gyy[k] *= norm
		Gxy_re[k] *= norm
		Gxy_im[k] *= norm

	# 频率响应 H1 = Gxy/Gxx, H2 = Gyy/conj(Gxy), 相干函数
	var freqs := PackedFloat64Array()
	var H_mag := PackedFloat64Array()
	var H_phase := PackedFloat64Array()
	var H2_mag := PackedFloat64Array()
	var coh := PackedFloat64Array()
	freqs.resize(nfreq)
	H_mag.resize(nfreq)
	H_phase.resize(nfreq)
	H2_mag.resize(nfreq)
	coh.resize(nfreq)

	var df := sample_rate / nfft
	for k in nfreq:
		freqs[k] = k * df
		var gxx := Gxx[k]
		var gyy := Gyy[k]
		var gxy_r := Gxy_re[k]
		var gxy_i := Gxy_im[k]
		var gxy_sq := gxy_r * gxy_r + gxy_i * gxy_i

		# H1 = Gxy / Gxx
		if gxx > 1e-30:
			var h1r := gxy_r / gxx
			var h1i := gxy_i / gxx
			H_mag[k] = sqrt(h1r * h1r + h1i * h1i)
			H_phase[k] = atan2(h1i, h1r)
		else:
			H_mag[k] = 0.0
			H_phase[k] = 0.0

		# H2 = Gyy / conj(Gxy) = Gyy * Gxy / |Gxy|²
		if gxy_sq > 1e-30:
			H2_mag[k] = sqrt(gyy * gyy / gxy_sq)
		else:
			H2_mag[k] = 0.0

		# 相干函数 γ² = |Gxy|² / (Gxx · Gyy)
		var denom := gxx * gyy
		if denom > 1e-30:
			coh[k] = clampf(gxy_sq / denom, 0.0, 1.0)
		else:
			coh[k] = 0.0

	return {
		"freqs": freqs,
		"H_mag": H_mag,
		"H_phase": H_phase,
		"H2_mag": H2_mag,
		"coh": coh,
		"Gxx": Gxx,
		"Gyy": Gyy,
		"Gxy_re": Gxy_re,
		"Gxy_im": Gxy_im,
		"nseg": nseg,
		"nfft": nfft,
		"df": df,
		"enbw": FFT.window_enbw(w),
	}


func _get_window(n: int) -> PackedFloat64Array:
	match window_type:
		1:  return FFT.hamming(n)
		2:  return FFT.blackman(n)
		_:  return FFT.hann(n)
