extends Node2D
## Game — 核心循环编排（Phase 5 / vertical-slice）。
## 状态：COUNTDOWN → RUNNING → RESULT（→ REVIVE → RUNNING）。
## 仅经 EventBus 通信；输入经 InputManager 抽象动作转发（ADR-003 / 红线）。
## 头标注「需 Godot CI 执行」（本环境无 Godot 运行时，仅可评审）。

enum Phase { COUNTDOWN, RUNNING, RESULT }

const COUNTDOWN_TIME := 2.0

var lane_system: LaneSystem
var corner: CornerController
var combo: ComboScoring
var obstacle_spawner: ObstacleSpawner
var pickup_spawner: PickupSpawner
var player: Player
var hud: HUD

var phase := Phase.COUNTDOWN
var _countdown := COUNTDOWN_TIME
var distance := 0.0
var score := 0.0
var _paused := false
var _per_run_used := 0

func _ready():
	lane_system = LaneSystem.new(); add_child(lane_system)
	corner = CornerController.new(); add_child(corner)
	combo = ComboScoring.new(); add_child(combo)
	obstacle_spawner = ObstacleSpawner.new(); add_child(obstacle_spawner)
	pickup_spawner = PickupSpawner.new(); add_child(pickup_spawner)
	player = Player.new(); add_child(player)
	hud = HUD.new(); add_child(hud)

	# 引用装配
	player.lane_system = lane_system
	obstacle_spawner.lane_system = lane_system
	obstacle_spawner.player = player
	obstacle_spawner.combo = combo
	pickup_spawner.lane_system = lane_system
	pickup_spawner.player = player
	pickup_spawner.combo = combo

	# 输入转发（抽象动作 → 系统）
	EventBus.lane_left.connect(_on_lane_left)
	EventBus.lane_right.connect(_on_lane_right)
	EventBus.jump.connect(_on_jump)
	EventBus.slide.connect(_on_slide)
	EventBus.pickup.connect(_on_pickup)
	EventBus.hit.connect(_on_hit)

	# Web 切后台暂停物理 tick（ADR-004 §F / perf-budget §6）
	get_window().visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	var vis = get_window().visible
	if not vis:
		_paused = true
	elif phase == Phase.RUNNING:
		_paused = false

func _process(delta):
	match phase:
		Phase.COUNTDOWN:
			_countdown -= delta
			if _countdown <= 0.0:
				phase = Phase.RUNNING
		Phase.RUNNING:
			if _paused:
				return
			_tick_running(delta)
		Phase.RESULT:
			pass

func _tick_running(dt: float):
	var speed = SpeedModel.V(distance, combo.combo)
	distance += speed * dt

	# 过弯触发（每 CORNER_INTERVAL m）
	if corner.maybe_trigger(distance):
		corner.enter()
		lane_system.force_center()
		lane_system.set_input_locked(true)
		obstacle_spawner.clear_lane(1)   # 清中轨既有 Blocker，防过弯锁中轨期间被既有障碍误杀（S10 过弯可解性）
		EventBus.corner_enter.emit()
	if corner.is_active():
		corner.update(dt)
		if corner.is_done():
			corner.exit()
			lane_system.set_input_locked(false)
			EventBus.corner_exit.emit()

	# 系统推进
	player.update_kinematics(dt)
	lane_system.update(dt)
	combo.tick(dt)
	obstacle_spawner.update(dt, distance, speed, corner.is_active())
	if phase != Phase.RUNNING:
		return
	pickup_spawner.update(dt, distance, speed, corner.is_active())
	if phase != Phase.RUNNING:
		return

	# 计分
	score += combo.distance_score(speed, dt)
	EventBus.distance_changed.emit(distance)
	EventBus.score_changed.emit(score)
	EventBus.combo_changed.emit(combo.combo, combo.m)

# ── 输入处理 ──
func _on_lane_left(): lane_system.switch_lane(-1)
func _on_lane_right(): lane_system.switch_lane(+1)
func _on_jump(): player.jump()
func _on_slide(): player.slide()
func _on_pickup(_kind): score += combo.event_bonus(_kind); EventBus.score_changed.emit(score)

func _on_hit():
	if phase == Phase.RUNNING and not player.is_invulnerable():
		_game_over()

func _game_over():
	phase = Phase.RESULT
	EventBus.game_over.emit()
	SaveManager.save_best(distance, score)
	_try_revive()

# ── 复活链路（仅 RESULT 态，ADR-005 §5）──
func _try_revive() -> bool:
	if not AdManager.enabled:
		return false
	var d = SaveManager.load_data()
	var rct = int(d["revive_count_today"])
	var lrd = str(d["last_revive_date"])
	if not AdManager.is_revive_available(_per_run_used, rct, lrd):
		return false
	_paused = true
	AdManager.request_revive(_per_run_used, rct, lrd, _on_revive_resolved)
	return true

func _on_revive_resolved(granted: bool):
	if not granted:
		_paused = false
		return
	obstacle_spawner.clear_near_player()
	player.invuln = Tuning.REVIVE_invuln
	_per_run_used += 1
	var d = SaveManager.load_data()
	var today = ReviveCaps._today()
	var today_count = int(d["revive_count_today"])
	if str(d["last_revive_date"]) != today:
		today_count = 0
	today_count += 1
	SaveManager.save_revive_state(_per_run_used, today_count, today)
	phase = Phase.RUNNING
	_paused = false

# ── 一键重开（RESULT → COUNTDOWN，<2s，对象池复用，ADR-004）──
func restart():
	distance = 0.0
	score = 0.0
	_per_run_used = 0
	_paused = false
	combo.reset()
	lane_system.reset()
	corner.reset()
	obstacle_spawner.reset(distance)
	pickup_spawner.reset(distance)
	player.reset()
	_countdown = COUNTDOWN_TIME
	phase = Phase.COUNTDOWN
