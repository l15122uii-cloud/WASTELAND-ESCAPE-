# Sprint 1 测试套件 · GUT（需 Godot CI 执行）

> 环境约束：本工作区无 Godot 运行时，下列 `.gd` 仅可评审，须在有 Godot 的环境跑通。
> 引擎版本未钉（见 `docs/architecture/test-plan.md §1.1` 知识缺口），以「Godot 4.x + GUT 9.x」假设。

## 运行方式
1. 安装 GUT 9.x addon 到 `res://addons/gut/`（不进首屏 `.pck`，导出剔除）。
2. 4 个游戏 autoload（`Tuning` / `EventBus` / `SaveManager` / `AdManager`）**已在 `project.godot` 注册**，无需重复添加。
3. GUI 跑：编辑器内打开 `res://test_runner.tscn`（已生成，挂 `Gut` 节点），GUT 面板加载 `res://tests/`。
4. headless 跑（CI）：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs`

## 用例 ↔ 烟雾映射（test-plan §3）
| 测试文件 | 覆盖烟雾 | 关键断言 |
|---|---|---|
| `test_projection.gd` | S1 | 远处更小 / 中轨居中 / 三轨屏偏移 |
| `test_lane_system.gd` | S1 / S5 | 切轨夹取 / lane_x / 过弯锁中轨 |
| `test_revive_caps.gd` | **S9（硬）** | 每日≤3 / 每局≤1 / 跨日重置（注入式日期，已解耦系统时钟 B4） |
| `test_save_manager.gd` | S12 | 最佳留存 / 内存降级不阻塞 |
| `test_combo_scoring.gd` | S8 / S11 | flank+1 / 衰减 / 计分 V·dt·m |
| `test_solvable.gd` | **S10（硬）** | 任意帧至少一轨可通行 / 过弯不堵中轨 |
| `test_revive_integration.gd` | S9（端到端） | game↔AdManager↔SaveManager 复活链路：计数+1 / 持久化 / 回到 RUNNING / 无敌帧；禁用广告不消耗额度（B5 补全） |

## 硬门禁（CI 红即拒）
- **S9** 复活上限：`test_revive_caps` 全绿（含跨日重置，已用注入式日期消除系统时钟依赖）。
- **S10** 可解性：`test_solvable` 全绿。
- **F4** 一致性红线：`grep` 校验模块间仅经 EventBus、Player 不读 `InputEvent`（control-manifest §B/D）。

## 待补（非阻塞，CONCERN）
- 引擎小版本 + GUT 钉版后补 CI job（test-plan §4）；`test_runner.tscn` 已生成，须先安装 GUT addon。
- 跳/滑手感（S2/S3/S4）、碰撞致死（S6）、过弯 yaw（S5 视觉）需在实机 playtest 复核。
