# ADR-001 · 引擎与渲染路径（2.5D 伪3D 三轨 / WebGL2）

- 状态：Accepted ｜ 作者：程基岩 ｜ 阶段：Phase 3

## 背景
项目为 Web/HTML5 即点即玩跑酷，形态 D2=2.5D 伪3D 三轨身后视角（类《神庙逃亡》）。美术红线要求：单屏 draw call ≤50、贴图 ≤256px 走 atlas、禁用实时阴影、首屏 <5MB。需在 Godot 4 中选一条 Web 可行的渲染路径，并实现 2.5D 纵深。

## 决策
- 渲染方法采用 **`gl_compatibility`（WebGL2）**——Web 导出的唯一稳定后端；**不使用** Forward+ / Mobile 渲染器（Web 平台不可用）。
- 2.5D 纵深用 **伪透视投影（`core/projection.gd` 纯数学 `project(x,z)→(sx,sy,scale)`）+ `TrackView` 单 `CanvasItem` 自绘道路/车道线（收敛到灭点）+ `BackgroundRoot` 天空/远景 + fog/haze 渐变** 实现，零额外几何/3D 节点成本，draw call 不新增（详见 architecture.md §6）。
- 阴影：**禁用实时阴影**，仅玩家脚下 `BlobShadow`（椭圆 Sprite2D）；后处理仅 cheap 暗角/轻微 bloom（可关）。

## 理由
- Compatibility 后端在 WebGL2 上稳定，且 Godot 4 的 2D 画布**自动合批（batching）**，配合 atlas 可把 draw call 压到 ≤50（perf-budget §4 估算 15–30）。
- 伪透视投影 + fog 以极低 GPU 成本卖出速度与纵深，契合"轻量优先"；`TrackView` 单 `CanvasItem` 自绘道路，障碍/拾取 Sprite 共享 atlas 合批，draw call 仍 ≤50。
- 禁实时阴影直接满足美术红线，blob shadow 足够表达落地关系。

## 后果
- 不能使用 Vulkan/WebGPU 专属特性；不可依赖 Forward+ 的进阶光照/后处理。
- 后处理只能 cheap（暗角/bloom 可关）；粒子须池化（硬上限 120）。
- 任何"Web 不支持"的渲染特性（如某些后处理、compute）一律不可用，需在设计期规避。
