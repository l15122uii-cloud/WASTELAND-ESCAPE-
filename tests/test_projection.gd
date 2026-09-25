extends GutTest
## test_projection — LCS-1 伪透视投影纯数学（需 Godot CI 执行）。
## 覆盖：远处更小、中轨居中、三轨屏偏移。

func test_project_farther_is_smaller():
	var near = ProjectionMath.project(0.0, 5.0)
	var far = ProjectionMath.project(0.0, 50.0)
	assert_true(far.scale < near.scale, "z 越大 scale 越小")
	assert_almost_eq(near.sx, Tuning.PROJ_screenCenterX, 0.001, "中轨 worldX=0 屏幕居中")

func test_center_lane_screen_x():
	var p = ProjectionMath.project(0.0, 0.0)
	assert_almost_eq(p.sx, Tuning.PROJ_screenCenterX, 0.001, "中轨(lane1) 屏幕 x=640")

func test_lane_offsets_match_tuning():
	# lane0→-100, lane1→0, lane2→+100（lanes 540/640/740）
	assert_almost_eq(ProjectionMath.project(-Tuning.laneSpacingPx, 0.0).sx, Tuning.PROJ_screenCenterX - Tuning.laneSpacingPx, 0.001)
	assert_almost_eq(ProjectionMath.project(Tuning.laneSpacingPx, 0.0).sx, Tuning.PROJ_screenCenterX + Tuning.laneSpacingPx, 0.001)
