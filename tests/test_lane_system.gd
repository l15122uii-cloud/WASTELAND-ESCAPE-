extends GutTest
## test_lane_system — LCS-2/3 切轨 + 边界夹取 + 过弯锁轨（S1/S5）。

func test_switch_lane_clamps():
	var lane = LaneSystem.new(); add_child(lane)
	lane.current_lane = 2
	lane.switch_lane(+1); assert_eq(lane.current_lane, 2, "右边界夹取")
	lane.switch_lane(-1); assert_eq(lane.current_lane, 1)
	lane.switch_lane(-1); assert_eq(lane.current_lane, 0)
	lane.switch_lane(-1); assert_eq(lane.current_lane, 0, "左边界夹取")

func test_lane_x_offsets():
	var lane = LaneSystem.new()
	assert_almost_eq(lane.lane_x(0), -Tuning.laneSpacingPx, 0.001)
	assert_almost_eq(lane.lane_x(1), 0.0, 0.001)
	assert_almost_eq(lane.lane_x(2), Tuning.laneSpacingPx, 0.001)

func test_corner_locks_lateral_input():
	var lane = LaneSystem.new(); add_child(lane)
	lane.current_lane = 2
	lane.force_center(); lane.set_input_locked(true)
	lane.update(0.1)
	lane.switch_lane(-1)   # 锁期间忽略
	assert_eq(lane.current_lane, 1, "锁中轨后切左无效，仍为 lane1")
	assert_true(lane.is_input_locked(), "横向输入锁生效")
	lane.set_input_locked(false)
	lane.switch_lane(-1)
	assert_eq(lane.current_lane, 0, "解锁后可切轨")
