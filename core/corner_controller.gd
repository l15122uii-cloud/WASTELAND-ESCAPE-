class_name CornerController
extends Node
## CornerController — 过弯调度 + yaw 插值 + 锁中轨触发（architecture.md §6.3 / core-loop.md §2.6）。
## 由 CoreLoop 里程触发；enter() 经 LaneSystem 锁中轨+锁横向（在 game.gd 调用）；exit() 解锁。
## 过弯期间世界继续推进（z 递减），仅车道锁定；伪3D 不跟踪绝对朝向，yaw 期满归零。
## 头标注「需 Godot CI 执行」。

const CORNER_INTERVAL := 300.0   # 每 300m 触发一次弯（里程碑，切片简化）

var _active := false
var _t := 0.0
var _next := CORNER_INTERVAL
var yaw := 0.0

func maybe_trigger(d: float) -> bool:
	if _active:
		return false
	if d >= _next:
		_next += CORNER_INTERVAL
		return true
	return false

func enter():
	_active = true
	_t = 0.0

func exit():
	_active = false
	yaw = 0.0

func is_active() -> bool:
	return _active

func is_done() -> bool:
	return _active and _t >= Tuning.CORNER_duration

func update(dt: float):
	if _active:
		_t += dt
		yaw = lerpf(0.0, Tuning.CORNER_yaw, clampf(_t / Tuning.CORNER_duration, 0.0, 1.0))

func reset():
	_active = false
	_t = 0.0
	_next = CORNER_INTERVAL
	yaw = 0.0
