class_name SaveManager
extends Node
## SaveManager — 本地持久化（autoload "SaveManager"）。
## ADR-004 / control-manifest §E：经 JavaScriptBridge 写 window.localStorage，
## 键 "wasteland_escape_save"，JSON + schema_version；JS 层 try/catch 降级内存不阻塞。
## 仅 RESULT 态（game.gd 调用 save_best / save_revive_state）一次性写。
## 头标注「需 Godot CI 执行」。

const SAVE_KEY := "wasteland_escape_save"
const SCHEMA_VERSION := 1

var _mem := {
	"best_distance": 0.0,
	"best_score": 0.0,
	"revive_count_today": 0,
	"last_revive_date": "",
	"revive_offered_total": 0,
	"ads_enabled": false,
	"schema_version": SCHEMA_VERSION
}
var _use_memory := false

func _ready():
	_use_memory = not _js_available()

# 仅用字符串探测单例，绝不引用 JavaScriptBridge 字面类（非 web 构建才能编译通过）
func _js_available() -> bool:
	return Engine.has_singleton("JavaScriptBridge")

func _read() -> Dictionary:
	if _use_memory:
		return _mem
	var js = Engine.get_singleton("JavaScriptBridge")
	if js == null:
		_use_memory = true
		return _mem
	var code = "(function(){ try { return window.localStorage.getItem('%s'); } catch(e){ return null; } })()" % SAVE_KEY
	var raw = js.eval(code, false)
	if raw == null or raw == "":
		return _mem
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _mem
	for k in _mem.keys():
		if parsed.has(k):
			_mem[k] = parsed[k]
	return _mem

func _write():
	if _use_memory:
		return
	var js = Engine.get_singleton("JavaScriptBridge")
	if js == null:
		_use_memory = true
		return
	var json = JSON.stringify(_mem)
	var code = "(function(){ try { window.localStorage.setItem('%s', '%s'); return true; } catch(e){ return false; } })()" % [SAVE_KEY, json]
	var ok = js.eval(code)
	if ok != true:
		_use_memory = true

func save_best(distance: float, score: float):
	var d = _read()
	if distance > float(d["best_distance"]):
		d["best_distance"] = distance
	if score > float(d["best_score"]):
		d["best_score"] = score
	_write()

func get_best_distance() -> float:
	return float(_read()["best_distance"])

func get_best_score() -> float:
	return float(_read()["best_score"])

func load_data() -> Dictionary:
	return _read()

func save_revive_state(per_run_used: int, revive_count_today: int, last_revive_date: String):
	var d = _read()
	d["revive_count_today"] = revive_count_today
	d["last_revive_date"] = last_revive_date
	d["revive_offered_total"] = int(d.get("revive_offered_total", 0)) + 1
	d["ads_enabled"] = true
	_write()

func is_memory_fallback() -> bool:
	return _use_memory
