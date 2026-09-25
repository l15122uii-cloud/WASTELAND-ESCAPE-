class_name ComboScoring
extends Node
## ComboScoring — 连击状态机 + 倍率 + 衰减窗口（combo-scoring.md §2.1/§2.3/§4）。
## 纯被动消费事件（P1 无独立输入）。nearMissBand/Tier 引用 Tuning（单一真值源）。
## 切片 MVP：任何近失 +1（同轨贴脸 +2 / 急救包 延迟至 CORE，见 COM-6 门控）。
## 头标注「需 Godot CI 执行」。

const STEP := 0.10        # 每连击倍率增量
const M_MAX := 5.0        # 倍率软封顶
const COMBO_CAP := 40     # 线性段封顶 combo（达 40 封顶 m_max）
const T := 2.5            # 衰减窗口 s
const SUPPLY_BONUS := 10.0
const MEDKIT_BONUS := 25.0
const NEAR_MISS_BONUS := 15.0

var combo := 0
var m := 1.0
var _window := 0.0   # 距上次事件秒数

func reset():
	combo = 0
	m = 1.0
	_window = 0.0

func _recalc():
	m = min(M_MAX, 1.0 + STEP * combo)

func on_event(gain: int):
	combo += gain
	_window = 0.0
	_recalc()
	EventBus.combo_changed.emit(combo, m)

func on_near_miss(kind: String):   # graze/flank；MVP 均 +1，CORE 再分层 +2
	on_event(1)
	EventBus.near_miss.emit(kind)

func on_pickup(kind: String):
	var gain := 1
	if kind == "medkit":
		gain = 2
	on_event(gain)
	EventBus.pickup.emit(kind)

func on_double_jump():
	on_event(1)
	EventBus.double_jump.emit()

func event_bonus(kind: String) -> float:
	if kind == "medkit":
		return MEDKIT_BONUS
	if kind == "supply":
		return SUPPLY_BONUS
	if kind == "graze" or kind == "flank":
		return NEAR_MISS_BONUS
	return 0.0

func tick(dt: float):
	if combo > 0:
		_window += dt
		if _window >= T:
			combo = 0
			m = 1.0
			_window = 0.0
			EventBus.combo_changed.emit(combo, m)

func distance_score(V: float, dt: float) -> float:   # S7 计分：score += V·dt·m
	return V * dt * m
