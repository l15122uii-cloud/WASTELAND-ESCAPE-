class_name AdManager
extends Node
## AdManager — 激励视频复活（autoload "AdManager"）。
## ADR-005 / control-manifest §H。MVP 默认 enabled=false（核心循环零耦合）；
## 切片测试经 mock Provider 显式 configure(true) 启用，上限由 ReviveCaps 判定(3天/1局)。
## 仅 RESULT 态触发（game.gd）；奖励到账后 emit revive_granted + 写 SaveManager。
## 头标注「需 Godot CI 执行」。

signal revive_resolved(granted: bool)

const MockAdProvider = preload("res://autoload/providers/mock_ad_provider.gd")

var enabled := false
var _provider = null
var _pending_cb: Callable = Callable()

func _ready():
	if enabled:
		_provider = MockAdProvider.new()

func configure(enabled_flag: bool):
	enabled = enabled_flag
	if enabled and _provider == null:
		_provider = MockAdProvider.new()

func is_revive_available(per_run_used: int, revive_count_today: int, last_revive_date: String) -> bool:
	if not enabled:
		return false
	var st := {"per_run_used": per_run_used, "revive_count_today": revive_count_today, "last_revive_date": last_revive_date}
	return ReviveCaps.is_revive_available(st, Tuning.revive_daily_cap, Tuning.revive_per_run_max)

func request_revive(per_run_used: int, revive_count_today: int, last_revive_date: String, on_resolved: Callable):
	if not is_revive_available(per_run_used, revive_count_today, last_revive_date):
		on_resolved.call(false)
		revive_resolved.emit(false)
		return
	_pending_cb = on_resolved
	if _provider == null:
		_provider = MockAdProvider.new()
	_provider.show_rewarded(_on_ad_closed)

func _on_ad_closed(rewarded: bool):
	if rewarded:
		EventBus.revive_granted.emit()
	else:
		EventBus.revive_declined.emit()
	if _pending_cb.is_valid():
		_pending_cb.call(rewarded)
	revive_resolved.emit(rewarded)
	_pending_cb = Callable()
