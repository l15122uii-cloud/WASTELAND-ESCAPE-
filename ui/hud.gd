class_name HUD
extends CanvasLayer
## HUD — 只读订阅 EventBus（control-manifest §B/D：不持有状态）。
## 距离/分数/连击实时显示；复活计数文案（本局已用 / 每日 0/3）。
## 头标注「需 Godot CI 执行」。

var _distance: Label
var _score: Label
var _combo: Label
var _revive: Label

func _ready():
	var panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_distance = Label.new(); _distance.position = Vector2(20, 20); panel.add_child(_distance)
	_score = Label.new(); _score.position = Vector2(20, 50); panel.add_child(_score)
	_combo = Label.new(); _combo.position = Vector2(20, 80); panel.add_child(_combo)
	_revive = Label.new(); _revive.position = Vector2(20, 110); panel.add_child(_revive)
	EventBus.distance_changed.connect(_on_distance)
	EventBus.score_changed.connect(_on_score)
	EventBus.combo_changed.connect(_on_combo)
	EventBus.revive_granted.connect(_on_revive_granted)
	EventBus.revive_declined.connect(_on_revive_declined)

func _on_distance(d): _distance.text = "%.0f m" % d
func _on_score(s): _score.text = "%.0f" % s
func _on_combo(c, m): _combo.text = "x%d (%.1f)" % [c, m]
func _on_revive_granted(): _revive.text = "复活成功"
func _on_revive_declined(): _revive.text = "今日复活已用尽"
