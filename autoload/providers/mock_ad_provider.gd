class_name MockAdProvider
extends RefCounted
## 切片 mock 广告 Provider（ADR-005 §8 简化）：不接真实 JS SDK，模拟"看完即奖励"。
## 真接入时替换为 AdProviderWeb / MiniProgram / TapTap（按运行平台探测，ADR-005 §8）。
## 头标注「需 Godot CI 执行」。

var simulated_reward := true   # 测试可置 false 模拟用户中途退出/无网

func has_ad(_kind: String) -> bool:
	return true

func show_rewarded(on_closed: Callable):
	# 模拟广告播放完成回调（真环境为 SDK 异步回调）
	on_closed.call(simulated_reward)
