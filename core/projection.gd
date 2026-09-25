class_name ProjectionMath
extends RefCounted
## 伪透视投影（纯数学，无 Node3D / 无 3D 相机）—— architecture.md §6.1 / ADR-001。
## project(worldX, z) → {sx, sy, scale}，参数全取 Tuning.PROJ_*（单一真值源，C-A 已落地）。
## 设计：归一化缩放 scale = camNear/(z+camNear)，使 z=0 时 scale≈1（玩家平面），远处趋近 0；
##   屏幕横向 = screenCenterX + worldX·scale（worldX 已含车道偏移，单位 px），满足「三轨在玩家平面 ±laneSpacingPx」。
##   focal 用于推导玩家平面投影尺度（focal/camNear）作归一化参考；C7 校准项先按 300/252/640/1.0。
## 头标注「需 Godot CI 执行」：本环境无运行时。

const GROUND_DROP_PX := 348.0   # 玩家平面地面相对灭点的屏幕下沉（C7 校准项，投影内部常量，未入 Tuning）

static func project(world_x: float, z: float) -> Dictionary:
	var scale := Tuning.PROJ_camNear / (z + Tuning.PROJ_camNear)   # z=0→1.0，远处→小
	var sx := Tuning.PROJ_screenCenterX + world_x * scale
	var sy := Tuning.PROJ_horizonY + GROUND_DROP_PX * scale
	return {"sx": sx, "sy": sy, "scale": scale}
