extends Node
class_name LQRController

## ============================================================
## LQR（线性二次调节器）控制器框架
##
## 倒立摆的状态向量 x = [θ, θ̇, x, ẋ]
##   θ  = 摆杆偏角（竖直向上为0）
##   θ̇ = 摆杆角速度
##   x  = 小车位置
##   ẋ = 小车速度
##
## 控制律：u = -K * x
##   K 是通过求解 Riccati 方程得到的反馈增益矩阵
##
## 你需要完成的步骤：
##   1. 根据物理参数计算 A、B 矩阵（线性化状态方程）
##   2. 设计 Q、R 权重矩阵
##   3. 求解 Riccati 方程得到 K
##   4. 在 compute() 中实现 u = -K*x
## ============================================================

## --- 物理参数 ---
@export var M: float = 1.0       # 小车质量 (kg)
@export var m: float = 0.1      # 摆杆质量 (kg)
@export var l: float = 1.0      # 摆杆半长 (m)
@export var g: float = 9.8      # 重力加速度 (m/s²)

## --- LQR 权重矩阵（对角线元素）---
## Q 权重越大 → 对应状态越希望趋近0
## R 权重越大 → 越不希望用大力
@export var Q_theta: float = 100.0     # θ 的权重
@export var Q_theta_dot: float = 10.0  # θ̇ 的权重
@export var Q_x: float = 1.0           # x 的权重
@export var Q_x_dot: float = 1.0       # ẋ 的权重
@export var R: float = 1.0             # 控制力 u 的权重

## --- 输出限幅 ---
@export var output_max: float = 3000.0

## 反馈增益矩阵 K = [K1, K2, K3, K4]
var K: Array = [0.0, 0.0, 0.0, 0.0]

## 是否已计算过 K
var _initialized: bool = false


func _ready():
	compute_gain()


## ============================================================
## 第1步：构建线性化状态方程 ẋ = A*x + B*u
##
## 倒立摆在 θ≈0 处线性化后的连续时间状态方程：
##
##     ⎡ 0    1        0           0      ⎤       ⎡     0      ⎤
## A = ⎢ (M+m)g   0        0           0      ⎥   B = ⎢   -1/M     ⎥
##     ⎢ 0    0        0           1      ⎥       ⎢     0      ⎥
##     ⎢ -mg   0        0           0      ⎥       ⎢    1/M     ⎥
##     ⎣  Ml       Ml                   ⎦       ⎣            ⎦
##
## 提示：上面的 A、B 是简化版，严格推导需要考虑 m、l 的完整形式
##       你可以查阅倒立摆的线性化推导，填入正确的矩阵元素
## ============================================================
func build_system_matrices() -> Dictionary:
	# TODO: 根据物理参数 M, m, l, g 计算 A 和 B 矩阵
	# A 是 4x4 矩阵，B 是 4x1 矩阵
	# 这里给出简化框架，你需要填入正确的值

	var A: Array = [
		[0.0, 1.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0],  # TODO: A[1][0] = (M+m)*g / (M*l)
		[0.0, 0.0, 0.0, 1.0],
		[0.0, 0.0, 0.0, 0.0],  # TODO: A[3][0] = -m*g / M
	]

	var B: Array = [
		[0.0],
		[0.0],  # TODO: B[1][0] = -1 / (M*l)
		[0.0],
		[0.0],  # TODO: B[3][0] = 1 / M
	]

	return {"A": A, "B": B}


## ============================================================
## 第2步：求解 Riccati 方程 AᵀP + PA - PBR⁻¹BᵀP + Q = 0
##
## 求出 P 后，K = R⁻¹BᵀP
##
## 求解方法：
##   方法1：迭代法（简单但收敛慢）
##     P_{k+1} = AᵀP_kA - AᵀP_kB(R + BᵀP_kB)⁻¹BᵀP_kA + Q
##     从 P₀ = Q 开始迭代，直到 ‖P_{k+1} - P_k‖ < ε
##
##   方法2：Schur 分解 / 特征值分解（更稳定）
##     构造 Hamilton 矩阵 H = [A, -BR⁻¹Bᵀ; -Q, -Aᵀ]
##     求其稳定特征空间，提取 P
##
##   方法3：直接用 Python/Julia 算好 K，硬编码到这里
##     对于固定参数的系统，这是最实用的做法
## ============================================================
func solve_riccati(A: Array, B: Array, Q_mat: Array, R_val: float) -> Array:
	# TODO: 实现 Riccati 方程求解
	#
	# 下面给出迭代法的框架，你需要补充矩阵运算
	#
	# var P = Q_mat.duplicate(true)  # P₀ = Q
	# var R_inv = 1.0 / R_val
	#
	# for iteration in range(1000):
	#     # 计算 P_new = AᵀPA - AᵀPB(R + BᵀPB)⁻¹BᵀPA + Q
	#     var P_new = ...
	#
	#     # 检查收敛
	#     if max_diff(P_new, P) < 1e-6:
	#         P = P_new
	#         break
	#     P = P_new
	#
	# # K = R⁻¹BᵀP
	# var K_mat = ...
	# return K_mat

	# 占位：返回零增益
	return [0.0, 0.0, 0.0, 0.0]


## 计算反馈增益 K
func compute_gain():
	var sys = build_system_matrices()
	var A = sys["A"]
	var B = sys["B"]

	# 构建 Q 矩阵（对角阵）
	var Q_mat: Array = [
		[Q_theta, 0.0, 0.0, 0.0],
		[0.0, Q_theta_dot, 0.0, 0.0],
		[0.0, 0.0, Q_x, 0.0],
		[0.0, 0.0, 0.0, Q_x_dot],
	]

	# 求解 Riccati 得到 K
	var K_mat = solve_riccati(A, B, Q_mat, R)
	K = K_mat
	_initialized = true

	print("LQR K = ", K)


## ============================================================
## 第3步（已完成）：控制律 u = -K * x
##
## 参数：
##   state = [θ, θ̇, x, ẋ]  当前状态
## 返回：
##   控制力 u
## ============================================================
func compute(state: Array, _delta: float) -> float:
	if not _initialized:
		compute_gain()

	# u = -K * x
	var u: float = 0.0
	for i in range(4):
		u -= K[i] * state[i]

	u = clamp(u, -output_max, output_max)
	return u


func reset():
	_initialized = false
