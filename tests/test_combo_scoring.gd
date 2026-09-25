extends GutTest
## test_combo_scoring — COM-1/2/3 连击 + 衰减 + flank + 计分（S8/S11）。

func test_combo_increments_on_near_miss():
	var c = ComboScoring.new(); add_child(c)
	c.on_near_miss("flank")
	assert_eq(c.combo, 1, "flank +1")
	c.on_near_miss("flank")
	assert_eq(c.combo, 2)
	assert_almost_eq(c.m, 1.0 + 0.10 * 2, 0.001, "倍率随连击增")

func test_combo_decay_after_window():
	var c = ComboScoring.new(); add_child(c)
	c.on_near_miss("flank")
	c.tick(3.0)   # > T(2.5s)
	assert_eq(c.combo, 0, "超窗口清零")
	assert_almost_eq(c.m, 1.0, 0.001)

func test_pickup_event_bonus():
	var c = ComboScoring.new(); add_child(c)
	assert_almost_eq(c.event_bonus("medkit"), 25.0, 0.001)
	assert_almost_eq(c.event_bonus("supply"), 10.0, 0.001)
	assert_almost_eq(c.event_bonus("graze"), 15.0, 0.001)

func test_distance_score_scales_with_multiplier():
	var c = ComboScoring.new(); add_child(c)
	c.on_near_miss("flank")   # combo=1 → m=1.1
	var s = c.distance_score(10.0, 1.0)
	assert_almost_eq(s, 11.0, 0.001, "score += V·dt·m")
