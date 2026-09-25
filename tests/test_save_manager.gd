extends GutTest
## test_save_manager — PER-1/2/5 存档 + 降级（S12）。
## 非 web 环境无 JavaScriptBridge → 内存降级，游戏照常可玩不阻塞。

func test_best_persists_in_memory_fallback():
	var sm = SaveManager.new(); add_child(sm)
	sm.save_best(123.0, 456.0)
	assert_almost_eq(sm.get_best_distance(), 123.0, 0.001, "最佳距离留存")
	assert_almost_eq(sm.get_best_score(), 456.0, 0.001, "最佳分数留存")
	sm.save_best(50.0, 999.0)   # 更差距离不应覆盖
	assert_almost_eq(sm.get_best_distance(), 123.0, 0.001, "更差距离不覆盖")
	assert_almost_eq(sm.get_best_score(), 999.0, 0.001, "更高分数覆盖")

func test_memory_fallback_flag_consistent():
	var sm = SaveManager.new(); add_child(sm)
	# 非 web 运行时 _use_memory 应为 true（无 JS bridge）
	assert_true(sm.is_memory_fallback(), "无 JS 环境降级内存不阻塞")
