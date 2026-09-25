class_name ObstacleSpawner
extends Node
## ObstacleSpawner — Blocker 单类障碍池（poolSize=24，free-list，零 queue_free）。
## ADR-002 / control-manifest §C。切片仅 Blocker（满高 SWITCH-only）。
## 同轨且玩家未无敌 → EventBus.hit；相邻轨掠过 → combo.on_near_miss("flank")。
## 过弯(corner_active)期间中轨(lane1)不生成 Blocker，防锁中轨堵死致死（C-C 简化）。
## 头标注「需 Godot CI 执行」。

const Z_SPAWN := 40.0
const Z_RECYCLE := -4.0
const REACH := 0.4
const SPAWN_INTERVAL := 18.0   # m（=intervalBase；playtest 校准项）

var _pool := []
var _live := 0
var _spawn_countdown := 12.0

var lane_system: LaneSystem
var player   # 故意不标注类型：运行期赋 Player / 测试中赋 FakePlayer，经动态分发调用 current_lane()/is_invulnerable()
var combo    # 故意不标注类型：运行期赋 ComboScoring / 测试 FakeCombo，经动态分发调用 on_near_miss()/on_pickup()

func _ready():
	for i in Tuning.poolSize:
		_pool.append({"active": false, "lane": 1, "z": 0.0, "judged": false})

func reset(_d := 0.0):
	for o in _pool:
		o.active = false
		o.judged = false
	_live = 0
	_spawn_countdown = 12.0

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

func update(dt: float, _distance: float, speed: float, corner_active: bool):
	_spawn_countdown -= speed * dt
	if _spawn_countdown <= 0.0 and _live < Tuning.maxLiveObstacles:
		_spawn_one(corner_active)
		_spawn_countdown += SPAWN_INTERVAL
	for o in _pool:
		if not o.active:
			continue
		o.z -= speed * dt
		if o.z <= Z_RECYCLE:
			_release(o)
			continue
		if not o.judged and o.z <= REACH and o.z >= -REACH:
			_judge(o)

func _spawn_one(corner_active: bool):
	var o := _acquire()
	if o.is_empty():
		return
	o.z = Z_SPAWN
	o.judged = false
	var lane := randi_range(0, 2)
	if corner_active and lane == 1:
		lane = 0 if (randi() % 2 == 0) else 2
	o.lane = lane

func _judge(o: Dictionary):
	o.judged = true
	var pl := player.current_lane()
	if o.lane == pl:
		if not player.is_invulnerable():
			EventBus.hit.emit()
	else:
		if abs(o.lane - pl) == 1:
			combo.on_near_miss("flank")

func lanes_blocked_at_player_plane() -> Array:
	var arr := []
	for o in _pool:
		if o.active and abs(o.z) <= REACH:
			if not arr.has(o.lane):
				arr.append(o.lane)
	return arr

func clear_near_player(clear_z := 6.0):
	for o in _pool:
		if o.active and o.z < clear_z:
			_release(o)

# 过弯锁中轨时，清掉该轨既有 Blocker，防止 force_center 后玩家被"已在飞行中"的中轨障碍误杀
# （spawner 仅保证过弯期间"不新生成"中轨 Blocker，无法清除进入过弯前已在途的中轨障碍 —— S10 过弯可解性补强）。
func clear_lane(lane: int):
	for o in _pool:
		if o.active and o.lane == lane:
			_release(o)
