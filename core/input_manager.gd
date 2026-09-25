extends Node
## InputManager — 唯一输入入口（autoload）。触屏滑动 + 键盘 → 抽象动作经 EventBus。
## Player / HUD 绝不读 InputEvent 原始设备（ADR-003 / control-manifest §D）；仅识别主指、去抖。
## 切片用最简四向映射；小程序横滑返回冲突见 CONCERN C-D（容器层处理）。
## 头标注「需 Godot CI 执行」。

const MIN_SWIPE_PX := 40.0
const MIN_SWIPE_MS := 30.0

var _touching := false
var _start := Vector2.ZERO
var _start_ms := 0

func _unhandled_input(e: InputEvent):
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_A, KEY_LEFT:  EventBus.lane_left.emit()
			KEY_D, KEY_RIGHT: EventBus.lane_right.emit()
			KEY_W, KEY_UP:    EventBus.jump.emit()
			KEY_S, KEY_DOWN:  EventBus.slide.emit()
	elif e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			_touching = true
			_start = st.position
			_start_ms = Time.get_ticks_msec()
		else:
			_touching = false   # 仅主指；忽略第二触点（ADR-003）
	elif e is InputEventScreenDrag and _touching:
		var dr := (e as InputEventScreenDrag).position - _start
		if dr.length() >= MIN_SWIPE_PX:
			if abs(dr.x) > abs(dr.y):
				if dr.x < 0: EventBus.lane_left.emit()
				else:        EventBus.lane_right.emit()
			else:
				if dr.y < 0: EventBus.jump.emit()
				else:        EventBus.slide.emit()
			_touching = false
