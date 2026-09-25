# Sprint 1 测试套件 · GUT（需 Godot 4.3 + GUT 9.4.0）

> 引擎/GUT 已钉版（解决 C-B）：**Godot 4.3.x** + **GUT 9.4.0**（bitwes/Gut，MIT）。
> 选型依据：GUT 9.4.0 官方兼容 Godot 4.3–4.4；最新 9.6.1 需 Godot 4.6，超出版本不采用。
> 详见 `docs/engine-reference/godot/VERSION.md`。

## 1. 安装 GUT 9.4.0 → `res://addons/gut/`

**方式 A（推荐，本地一键）：下载 release 解压**
```powershell
# 在本仓库根目录执行（PowerShell）
curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v9.4.0.tar.gz -o gut.tgz
tar -xzf gut.tgz
mkdir -p addons
xcopy /E /I Gut-9.4.0\addons\gut addons\gut
Remove-Item gut.tgz, Gut-9.4.0 -Recurse -Force
```
验证：`addons/gut/gut.gd` 存在。

**方式 B（git submodule，可复现）**
```bash
git submodule add -b v9.4.0 https://github.com/bitwes/Gut.git addons/gut-src
mkdir -p addons
cp -r addons/gut-src/addons/gut addons/gut   # 取仓库内 addons/gut 子目录
```
> 注：GUT 仓库根即含 `addons/gut`，submodule 直接指向仓库根会嵌套，故取内部 `addons/gut` 复制出来（或 CI 用方式 A）。

## 2. autoload 已注册
4 个游戏 autoload（`Tuning` / `EventBus` / `SaveManager` / `AdManager`）**已在 `project.godot` 注册**，无需重复添加。

## 3. 运行方式
- **编辑器 GUI**：打开 `res://test_runner.tscn`（已生成，挂 `Gut` 节点），GUT 面板加载 `res://tests/`。
- **headless（CI / 本地）**：
  ```bash
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
  ```
  `-gexit` 使失败返回非 0，便于 CI 红即拒。

## 4. 用例 ↔ 烟雾映射（test-plan §3）
| 测试文件 | 覆盖烟雾 | 关键断言 |
|---|---|---|
| `test_projection.gd` | S1 | 远处更小 / 中轨居中 / 三轨屏偏移 |
| `test_lane_system.gd` | S1 / S5 | 切轨夹取 / lane_x / 过弯锁中轨 |
| `test_revive_caps.gd` | **S9（硬）** | 每日≤3 / 每局≤1 / 跨日重置（注入式日期，已解耦系统时钟 B4） |
| `test_save_manager.gd` | S12 | 最佳留存 / 内存降级不阻塞 |
| `test_combo_scoring.gd` | S8 / S11 | flank+1 / 衰减 / 计分 V·dt·m |
| `test_solvable.gd` | **S10（硬）** | 任意帧至少一轨可通行 / 过弯不堵中轨 |
| `test_revive_integration.gd` | S9（端到端） | game↔AdManager↔SaveManager 复活链路：计数+1 / 持久化 / 回到 RUNNING / 无敌帧；禁用广告不消耗额度（B5 补全） |

## 5. 硬门禁（CI 红即拒）
- **S9** 复活上限：`test_revive_caps` 全绿（含跨日重置，已用注入式日期消除系统时钟依赖）。
- **S10** 可解性：`test_solvable` 全绿。
- **F4** 一致性红线：`grep` 校验模块间仅经 EventBus、Player 不读 `InputEvent`（control-manifest §B/D）。

## 6. CI 闸门（C-A）
`.github/workflows/ci.yml` 已就绪：容器 `abarichello/godot-ci:4.3` + 安装 GUT 9.4.0 + headless 跑全部用例，失败即标红。
push 到 `main` / `fix/sprint1-vertical-slice` 或发 PR 时自动触发。

## 7. 待补（非阻塞 CONCERN）
- 跳/滑手感（S2/S3/S4）、碰撞致死（S6）、过弯 yaw（S5 视觉）须在实机 playtest 复核（C-C）。
- 性能预算（draw call≤50 / GC<0.5ms）须 `perf` job 采样（C-F）。
