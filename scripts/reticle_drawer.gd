extends Control

const PlayerHUD = preload("res://scripts/hud.gd")

@onready var hud: PlayerHUD = get_parent() as PlayerHUD

func _draw() -> void:
	var center := size * 0.5
	var color := Color(1.0, 1.0, 1.0, 0.9)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.6)
	
	var spread: float = hud.crosshair_spread if hud else 10.0
	var line_len: float = 7.0
	var width: float = 2.0
	
	# Center dot
	draw_circle(center, 1.5, color)
	
	# Top line
	draw_line(center + Vector2(0, -spread), center + Vector2(0, -spread - line_len), shadow_color, width + 1.0)
	draw_line(center + Vector2(0, -spread), center + Vector2(0, -spread - line_len), color, width)
	
	# Bottom line
	draw_line(center + Vector2(0, spread), center + Vector2(0, spread + line_len), shadow_color, width + 1.0)
	draw_line(center + Vector2(0, spread), center + Vector2(0, spread + line_len), color, width)
	
	# Left line
	draw_line(center + Vector2(-spread, 0), center + Vector2(-spread - line_len, 0), shadow_color, width + 1.0)
	draw_line(center + Vector2(-spread, 0), center + Vector2(-spread - line_len, 0), color, width)
	
	# Right line
	draw_line(center + Vector2(spread, 0), center + Vector2(spread + line_len, 0), shadow_color, width + 1.0)
	draw_line(center + Vector2(spread, 0), center + Vector2(spread + line_len, 0), color, width)
