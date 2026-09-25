# Tuning.gd — 全局数值常量单一真值源（WASTELAND ESCAPE / 废土逃生）
#
# 所有 GDD / 架构数值集中此处；模块只读，不在三处各写。
# 挂载为 Godot Autoload（project.godot 注册名 = Tuning）。
# 对应文档：architecture.md §6.5（LaneGeometry）、perf-budget.md §1/§4.1、adr-001。

extends Node

# ─────────────────────────────────────────────
# 世界尺度（perf-budget §1 设计常量）
# ─────────────────────────────────────────────
const PPM               : int   = 50    # pixels per meter（统一世界尺度）
const SCREEN_W          : int   = 1280  # 视口基准宽（base 1280×720）
const SCREEN_H          : int   = 720

# ─────────────────────────────────────────────
# 速度 / 节奏（CoreLoop / SpeedModel 真值）
# ─────────────────────────────────────────────
const Vmax              : float = 13.0  # m/s（R4 回签可达）
const intervalBase      : float = 18.0  # m（障碍基准间距）
const intervalMin       : float = 8.0   # m（最大密度最小间距）

# ─────────────────────────────────────────────
# 近失带（ObstacleGen 真值）
# ─────────────────────────────────────────────
const nearMissBand      : float = 24.0  # px ≈ 0.48m（同轨贴脸近失带宽）

# ─────────────────────────────────────────────
# LaneGeometry 车道几何（LaneSystem / 近失横向净空）★本次补全★
#   相邻轨掠过横向净空 = laneSpacingPx − playerHalfWidthPx − obstacleHalfWidthPx
#   = 100 − 20 − 20 = 60 px
#   → 该净空与 nearMissBand(24px) 的"触发阈值 / 间距"关系属 PLAYTEST 校准项
#     （呼应 design-side CONCERN）：常量先落地使公式可验证，阈值/间距调参见 playtest。
# ─────────────────────────────────────────────
const laneWidthM        : float = 2.0   # 相邻轨中心距（米）
const laneSpacingPx     : int   = 100   # 相邻轨中心距 px = laneWidthM(2.0) × PPM(50)；LaneSystem.lane_x 用
const laneWidthPx       : int   = 100   # [alias] 旧名，等价 laneSpacingPx；投影/车道宽统一用 laneSpacingPx
const playerHalfWidthPx : int   = 20    # 玩家碰撞半宽（初值，playtest 校准）
const obstacleHalfWidthPx : int = 20    # 障碍碰撞半宽（初值，playtest 校准）

# ─────────────────────────────────────────────
# 伪透视投影（core/projection.gd）★playtest 校准★
# ─────────────────────────────────────────────
const PROJ_focal        : float = 300.0 # 焦距 px
const PROJ_horizonY     : float = 252.0 # 灭点屏幕 y（=0.35×SCREEN_H）
const PROJ_screenCenterX: float = 640.0 # 屏幕中心 x（=0.5×SCREEN_W）
const PROJ_camNear      : float = 1.0   # 近裁剪补偿（防 z→0 除零）

# ─────────────────────────────────────────────
# 过弯（CornerController）★playtest 校准★
# ─────────────────────────────────────────────
const CORNER_yaw        : float = 90.0  # 过弯视角旋转目标角（度）
const CORNER_duration   : float = 1.0   # 过弯时长 s

# ─────────────────────────────────────────────
# 对象池（R4 回签）
# ─────────────────────────────────────────────
const poolSize          : int   = 24    # 障碍池（=2×maxLiveObstacles）
const pickupPoolSize    : int   = 32    # 拾取池（独立）
const maxLiveObstacles  : int   = 12

# ─────────────────────────────────────────────
# 复活 / 变现（AdManager，可配，按平台政策）
# ─────────────────────────────────────────────
const revive_per_run_max: int   = 1     # 每局最多复活 1 次
const revive_daily_cap  : int   = 3     # 每日复活上限（已与策划侧对齐，锁定为 3）
const REVIVE_invuln     : float = 1.0   # 复活后短暂无敌 s

# ─────────────────────────────────────────────
# 玩家运动学（Player 跳/滑/碰撞）★playtest 校准★
# ─────────────────────────────────────────────
const JUMP_V          : float = 9.0   # 起跳初速 m/s（矮跳≈此值）
const DOUBLE_JUMP_V   : float = 7.0   # 二段跳初速 m/s（低于首跳，防失控 S3）
const GRAVITY         : float = 28.0  # 重力加速度 m/s^2
const SLIDE_DURATION  : float = 0.45  # 滑铲时长 s（对 Overhead 无敌）
const PLAYER_H        : float = 1.6   # 玩家高 m（碰撞/绘制）
const PLAYER_W        : float = 0.8   # 玩家宽 m
