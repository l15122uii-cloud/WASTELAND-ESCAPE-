class_name Player
extends Node2D
## Player — 三轨身后视角跑者 FSM（architecture §6 / ADR-003）。
## 状态：GROUND_RUN / JUMP / DOUBLE_JUMP / SLIDE。
## 仅订阅 InputManager 抽象动作（game.gd 转发）：jump()/slide()；绝不读 InputEvent（红线）。
## 横向位置由 LaneSystem.x 经伪透视投影得到；纵向跳/滑为运动学（Tuning 跳参，playtest 校准）。
## 头标注「需 Godot CI 执行」。

enum State { GROUND_RUN, JUMP, DOUBLE_JUMP, SLIDE }

var state := State.GROUND_RUN
var y_m := 0.0          # 离地高度 m（跳为正）
var vy := 0.0           # 垂直速度 m/s
var slide_timer := 0.0
var invuln := 0.0       # 复活后无敌计时 s

var lane_system: LaneSystem

func _ready():
	pass

func jump():
	match state:
		State.GROUND_RUN:
			state = State.JUMP
			vy = Tuning.JUMP_V
		State.JUMP:
			state = State.DOUBLE_JUMP
			vy = Tuning.DOUBLE_JUMP_V
		_:
			pass   # SLIDE / 已二段跳：忽略

func slide():
	if state == State.GROUND_RUN:
		state = State.SLIDE
		slide_timer = Tuning.SLIDE_DURATION

func is_invulnerable() -> bool:
	return invuln > 0.0

func current_lane() -> int:
	return lane_system.current_lane

func update_kinematics(dt: float):
	if invuln > 0.0:
		invuln = max(0.0, invuln - dt)
	match state:
		State.JUMP, State.DOUBLE_JUMP:
			vy -= Tuning.GRAVITY * dt
			y_m += vy * dt
			if y_m <= 0.0:
				y_m = 0.0
				vy = 0.0
				state = State.GROUND_RUN
		State.SLIDE:
			slide_timer -= dt
			if slide_timer <= 0.0:
				state = State.GROUND_RUN
		_:
			pass

func reset():
	state = State.GROUND_RUN
	y_m = 0.0
	vy = 0.0
	slide_timer = 0.0
	invuln = 0.0

# 投影位置（绘制用）：玩家平面 z=0，scale=1
func screen_pos() -> Vector2:
	var p = ProjectionMath.project(lane_system.x, 0.0)
	var jump_px = y_m * Tuning.PPM
	return Vector2(p.sx, p.sy - jump_px)

func get_height_px() -> float:
	var h = Tuning.PLAYER_H * Tuning.PPM
	if state == State.SLIDE:
		h *= 0.5
	return h

func _draw():
	var pos = screen_pos()
	var w = Tuning.PLAYER_W * Tuning.PPM
	var h = get_height_px()
	var col = Color(0.2, 0.9, 0.9) if is_invulnerable() else Color(1.0, 0.45, 0.25)
	draw_rect(Rect2(pos.x - w / 2.0, pos.y - h, w, h), col)
