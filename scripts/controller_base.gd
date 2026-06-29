extends Node
class_name ControllerBase

## ============================================================
## 控制器基类
##
## 所有控制器（PID/LQR/MPC/SMC/用户自定义）统一继承此类。
## 被控对象（Plant）每物理帧调用 compute() 获取控制量 u。
##
## 统一接口：
##   compute(state, setpoint, dt) -> float
##     state:    被控对象当前状态（由 Plant.get_state() 提供）
##     setpoint: 参考值字典（由 UI 或辨识激励源设置）
##     dt:       物理步长
##     返回:     控制量 u（如力、力矩）
##
## 字段约定：
##   - state / setpoint 均为 Dictionary，由控制器自己声明需要哪些字段
##   - 通过 get_required_inputs() 暴露字段需求，供 UI 自动生成与辨识器约束
## ============================================================

## 参数变化信号（UI 同步用）
signal param_changed(param_name: String, value)


## 主接口：根据状态与设定值计算控制量
func compute(state: Dictionary, setpoint: Dictionary, dt: float) -> float:
	push_warning("ControllerBase.compute 未被子类实现: " + name)
	return 0.0


## 重置控制器内部状态（积分项、微分历史等）
func reset():
	pass


## 读取所有可调参数（UI 面板自动生成、辨识参数同步用）
func get_params() -> Dictionary:
	return {}


## 批量设置参数
func set_params(p: Dictionary):
	pass


## 声明该控制器需要从 state / setpoint 中读取哪些字段
## 返回 {"state": [字段名...], "setpoint": [字段名...]}
func get_required_inputs() -> Dictionary:
	return {"state": [], "setpoint": []}
