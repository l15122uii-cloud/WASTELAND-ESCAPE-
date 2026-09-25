class_name SpeedModel
extends RefCounted
## 速度模型 V(d,combo) 单一真值源（architecture.md §0 红线 / core-loop.md §2.4）。
## 速度参数（V0/k_d/k_c/comboFlowCap）未入 Tuning，故集中此处定义（禁止别处重定义）。
## 头标注「需 Godot CI 执行」。

const V0 := 7.0                 # 起始速度 m/s
const K_D := 0.0015             # 距离增速 /m（+0.15 m/s 每 100m）
const K_C := 0.001              # 连击流速加成系数（满 combo 时 +10%）
const COMBO_FLOW_CAP := 100.0   # 流速加成封顶 combo

static func V(d: float, combo: int) -> float:
	var base := min(Tuning.Vmax, V0 + K_D * d)
	var flow := 1.0 + K_C * min(float(combo), COMBO_FLOW_CAP)
	return base * flow
