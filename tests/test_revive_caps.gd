extends GutTest
## test_revive_caps — RAD-3/6 复活上限【硬门禁 S9】。CI 红即拒。
## 锁定值：revive_daily_cap=3（每日）/ revive_per_run_max=1（每局）。

func test_daily_cap_is_3():
	var st = {"per_run_used": 0, "revive_count_today": 3, "last_revive_date": "2026-09-24"}
	assert_false(ReviveCaps.is_revive_available(st, Tuning.revive_daily_cap, Tuning.revive_per_run_max),
		"每日第 4 次请求必须被拒（daily_cap=3）")

func test_per_run_cap_is_1():
	var st = {"per_run_used": 1, "revive_count_today": 0, "last_revive_date": "2026-09-24"}
	assert_false(ReviveCaps.is_revive_available(st, Tuning.revive_daily_cap, Tuning.revive_per_run_max),
		"本局已复活 1 次后再死亡不再提供（per_run_max=1）")

func test_available_when_under_caps():
	var st = {"per_run_used": 0, "revive_count_today": 0, "last_revive_date": ReviveCaps._today()}
	assert_true(ReviveCaps.is_revive_available(st, Tuning.revive_daily_cap, Tuning.revive_per_run_max),
		"首次请求可用")

func test_cross_date_resets_count():
	# 注入式日期解耦系统时钟（B4）：last_revive_date=2026-09-23，today_override=2026-09-24 → 跨日重置
	var st = {"per_run_used": 0, "revive_count_today": 3, "last_revive_date": "2026-09-23"}
	assert_true(ReviveCaps.is_revive_available(st, Tuning.revive_daily_cap, Tuning.revive_per_run_max, "2026-09-24"),
		"跨日(注入 today=2026-09-24)计数重置，第 1 次可用")
