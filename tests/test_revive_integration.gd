extends GutTest
## test_revive_integration — game ↔ AdManager ↔ SaveManager 端到端复活链路（B5 补全）。
## 静态可评审；须 Godot CI 真机跑（GUT headless）。
## 依赖 autoload：AdManager / SaveManager / EventBus / Tuning（已在 project.godot 注册）。
## MockAdProvider.show_rewarded 同步回调 rewarded=true，故整条链路在 _on_hit() 内同步完成。

const Game = preload("res://game.gd")

func before_each():
	# 隔离 SaveManager 内存态（headless 走 _use_memory 分支），确保每日复活计数从 0 起
	SaveManager._mem["revive_count_today"] = 0
	SaveManager._mem["last_revive_date"] = ""

func test_end_to_end_revive_increments_and_persists():
	# 启用激励视频复活（MVP 默认 false，切片测试显式开启）
	AdManager.enabled = true

	# 实例化 Game，触发 _ready 装配所有系统并接线 EventBus
	var game = Game.new()
	add_child(game)

	# 强制进入 RUNNING 且玩家非无敌，模拟一次真实碰撞
	game.phase = Game.Phase.RUNNING
	game.player.invuln = 0.0

	# hit → game_over → _try_revive → AdManager.request_revive
	# → MockAdProvider 同步回调 rewarded=true → _on_revive_resolved(true)
	game._on_hit()

	assert_eq(game._per_run_used, 1, "复活后本局复活次数应为 1")
	assert_eq(SaveManager.load_data()["revive_count_today"], 1, "每日复活计数应持久化为 1")
	assert_eq(game.phase, Game.Phase.RUNNING, "复活后状态应回到 RUNNING")
	assert_true(game.player.is_invulnerable(), "复活后应获得无敌帧")

	game.queue_free()

func test_revive_declined_does_not_consume_slot():
	# 覆盖 AdManager 不可用分支：enabled=false 时 _try_revive 直接返回，不消耗任何计数
	AdManager.enabled = false
	var game = Game.new()
	add_child(game)
	game.phase = Game.Phase.RUNNING
	game.player.invuln = 0.0

	game._on_hit()

	assert_eq(game._per_run_used, 0, "未启用广告时不应发生复活")
	assert_eq(game.phase, Game.Phase.RESULT, "未启用广告时应停留 RESULT")
	assert_eq(SaveManager.load_data()["revive_count_today"], 0, "未复活则不消耗每日额度")

	game.queue_free()
