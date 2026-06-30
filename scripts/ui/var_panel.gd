extends VBoxContainer
class_name VarPanel

@export var data_bridge: Node
@export var plotter: Plotter

var checkboxes: Dictionary = {}


func _ready():
	# 等待 bridge 就绪
	await get_tree().process_frame
	_build_checkboxes()


func _build_checkboxes():
	# 清空旧的
	for child in get_children():
		child.queue_free()
	checkboxes.clear()
	
	# 标题
	var title = Label.new()
	title.text = "监控变量"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)
	
	var vars = data_bridge.get_available_vars()
	for var_name in vars:
		var info = vars[var_name]
		
		var hbox = HBoxContainer.new()
		
		var cb = CheckBox.new()
		cb.text = var_name
		cb.button_pressed = info["enabled"]
		cb.pressed.connect(_on_checkbox_toggled.bind(var_name))
		
		# 颜色指示器
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = info["color"]
		
		hbox.add_child(color_rect)
		hbox.add_child(cb)
		add_child(hbox)
		
		checkboxes[var_name] = cb


func _on_checkbox_toggled(var_name: String):
	var cb = checkboxes[var_name]
	var enabled = cb.button_pressed
	data_bridge.toggle_variable(var_name, enabled)
	if not enabled:
		plotter.clear_curve(var_name)  # 取消勾选时清除该曲线
