extends GutTest
## test_solvable — OBG-5 可解性【硬门禁 S10】。
## 切片每次仅生成单类 Blocker 于单一车道，且间隔(≥intervalMin)远大于判定窗口，
## 故任意时刻玩家平面至多占用一轨 → 至少两轨可通行（结构保证，随机 1000+ 段验证）。

class FakePlayer extends Node:
	var lane = 1
	func current_lane(): return lane
	func is_invulnerable(): return false

class FakeCombo extends Node:
	func on_near_miss(_k): pass
	func on_pickup(_k): pass

func test_any_z_has_passable_lane():
	seed(12345)
	var spawner = ObstacleSpawner.new(); add_child(spawner)
	var fp = FakePlayer.new(); add_child(fp); spawner.player = fp
	var fc = FakeCombo.new(); add_child(fc); spawner.combo = fc
	var lane_sys = LaneSystem.new(); add_child(lane_sys); spawner.lane_system = lane_sys

	var dist := 0.0
	var speed := 10.0
	for i in 2000:
		var corner = (i % 137 == 0)   # 周期性模拟过弯锁中轨
		spawner.update(0.016, dist, speed, corner)
		dist += speed * 0.016
		var blocked = spawner.lanes_blocked_at_player_plane()
		assert_true(blocked.size() < 3, "帧 %d 至少一轨可通行（被占 %d 轨）" % [i, blocked.size()])

func test_corner_never_blocks_center_lane():
	seed(999)
	var spawner = ObstacleSpawner.new(); add_child(spawner)
	var fp = FakePlayer.new(); add_child(fp); spawner.player = fp
	var fc = FakeCombo.new(); add_child(fc); spawner.combo = fc
	var lane_sys = LaneSystem.new(); add_child(lane_sys); spawner.lane_system = lane_sys

	var dist := 0.0
	var speed := 10.0
	for i in 500:
		spawner.update(0.016, dist, speed, true)   # 强制 corner_active
		dist += speed * 0.016
		var blocked = spawner.lanes_blocked_at_player_plane()
		assert_false(blocked.has(1), "过弯期间中轨(lane1)不应有 Blocker")
