extends ControllerBase
class_name PassThroughController

## 直通控制器（开环辨识专用）
## 直接将 setpoint["excitation"] 作为控制量 u 输出，不做任何反馈计算。
## 用于系统辨识时注入激励信号到 Plant。

func compute(state: Dictionary, setpoint: Dictionary, dt: float) -> float:
	return setpoint.get("excitation", 0.0)


func get_required_inputs() -> Dictionary:
	return {"state": [], "setpoint": ["excitation"]}
