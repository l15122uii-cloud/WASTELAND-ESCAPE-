class_name ReviveCaps
extends RefCounted
## 复活上限纯判定（test-plan §5.3）——供 AdManager 调用，可 headless 单测，无需场景树。
## 锁定值：revive_daily_cap=3（每日）/ revive_per_run_max=1（每局），取 Tuning（ADR-005 §9）。
## 状态 dict：{ per_run_used:int, revive_count_today:int, last_revive_date:String }。
## 头标注「需 Godot CI 执行」。

static func is_revive_available(state: Dictionary, daily_cap: int, per_run_max: int, today_override := "") -> bool:
	if state.get("per_run_used", 0) >= per_run_max:
		return false
	var today := today_override if today_override != "" else _today()   # 注入式日期，解耦系统时钟（B4）
	if state.get("last_revive_date", "") != today:   # 跨日：计数重置
		state["revive_count_today"] = 0
		state["last_revive_date"] = today
	if state.get("revive_count_today", 0) >= daily_cap:
		return false
	return true

static func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]
