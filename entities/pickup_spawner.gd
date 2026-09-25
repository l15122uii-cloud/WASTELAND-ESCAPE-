class_name PickupSpawner
extends Node
## PickupSpawner — 补给/急救包池（pickupPoolSize=32，free-list，零 queue_free）。
## ADR-002 / control-manifest §C。当前轨掠过 → combo.on_pickup(kind)（内部 emit EventBus.pickup）。
## 分数增量由 game.gd 监听 EventBus.pickup 累加 combo.event_bonus(kind)。
## 头标注「需 Godot CI 执行」。

const Z_SPAWN := 40.0
const Z_RECYCLE := -4.0
const REACH := 0.4
const SPAWN_EVERY := 14.0   # m

var _pool := []
var _live := 0
var _countdown := 10.0

var lane_system: LaneSystem
var player   # 故意不标注类型：运行期赋 Player / 测试中赋 FakePlayer，经动态分发调用 current_lane()
var combo    # 故意不标注类型：运行期赋 ComboScoring / 测试 FakeCombo，经动态分发调用 on_pickup()

func _ready():
	for i in Tuning.pickupPoolSize:
		_pool.append({"active": false, "lane": 1, "z": 0.0, "kind": "supply", "judged": false})

func reset(_d := 0.0):
	for o in _pool:
		o.active = false
		o.judged = false
	_live = 0
	_countdown = 10.0

func _acquire() -> Dictionary:
	for o in _pool:
		if not o.active:
			o.active = true
			_live += 1
			return o
	return {}

func _release(o: Dictionary):
	if o.active:
		o.active = false
		_live -= 1

func update(dt: float, _distance: float, speed: float, _corner_active: bool):
	_countdown -= speed * dt
	if _countdown <= 0.0 and _live < Tuning.pickupPoolSize:
		_spawn_one()
		_countdown += SPAWN_EVERY
	for o in _pool:
		if not o.active:
			continue
		o.z -= speed * dt
		if o.z <= Z_RECYCLE:
			_release(o)
			continue
		if not o.judged and o.z <= REACH and o.z >= -REACH:
			o.judged = true
			if o.lane == player.current_lane():
				combo.on_pickup(o.kind)   # 内部 emit EventBus.pickup
				_release(o)

func _spawn_one():
	var o := _acquire()
	if o.is_empty():
		return
	o.z = Z_SPAWN
	o.judged = false
	o.lane = randi_range(0, 2)
	o.kind = "medkit" if (randi() % 4 == 0) else "supply"
