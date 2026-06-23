extends Control

func _ready():
	$VBoxContainer/Button.pressed.connect(_on_slider_pressed)
	$VBoxContainer/Button2.pressed.connect(_on_pendulum_pressed)

func _on_slider_pressed():
	get_tree().change_scene_to_file("res://scenes/cart.tscn")

func _on_pendulum_pressed():
	get_tree().change_scene_to_file("res://scenes/inverted_pendulum.tscn")
