class_name LaneSystem
extends Node
## LaneSystem — 三轨状态 + 平滑插值 + 边界夹取 + 过弯锁中轨（architecture.md §6.2 / ADR-003）。
## lane∈{0,1,2}；x = laneSpacingPx·(lane-1)；切轨用指数平滑（不瞬移、不跨轨）。
## 不读 InputEvent（输入由 InputManager 抽象，见 core/input_manager.gd）。
## 头标注「需 Godot CI 执行」。

const LANE_LERP := 18.0   # 切轨插值速率 1/s（≈0.1–0.15s 到位，playtest 校准 C7）

var current_lane := 1
var target_lane := 1
var x := 0.0
var _locked := false

func _ready():
	x = lane_x(current_lane)

func lane_x(lane: int) -> float:
	return (lane - 1) * Tuning.laneSpacingPx

func switch_lane(dir: int):
	if _locked:
		return
	target_lane = clampi(target_lane + dir, 0, 2)
	current_lane = target_lane   # 逻辑轨即时更新；视觉 x 由 update 插值
	EventBus.lane_changed.emit(current_lane)

func force_center():
	target_lane = 1
	current_lane = 1
	x = lane_x(1)

func set_input_locked(b: bool):
	_locked = b

func is_input_locked() -> bool:
	return _locked

func update(dt: float):
	var tx := lane_x(target_lane)
	x = lerpf(x, tx, 1.0 - exp(-LANE_LERP * dt))

func reset():
	current_lane = 1
	target_lane = 1
	x = lane_x(1)
	_locked = false
