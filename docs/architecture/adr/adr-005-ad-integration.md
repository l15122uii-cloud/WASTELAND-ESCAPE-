# ADR-005 · 广告 / 激励视频集成（Web 平台约束）

- 状态：Accepted（待发行渠道细化）｜ 作者：程基岩 ｜ 阶段：Phase 3（P3-ENG-02 补充）
- 依赖：变现方式 = Web/HTML5 激励视频（rewarded video）；R3 商业目标由主理人定；D4/P1 不受影响

## 背景
用户将变现定为「激励视频」（复活 + 可选额外奖励），目标平台扩展为 **Web/HTML5 + TapTap + 微信/抖音小程序（H5 容器加载 HTML5 export）**。移动端原生 rewarded video 不适用于 Web；Web 上激励视频走 H5 广告 SDK / 发行平台（CrazyGames / Poki / GameDistribution）或 H5 中介（AppLovin / IronSource H5 / IMA）；小程序内走宿主原生 API（`wx.createRewardedVideoAd` / `tt.createRewardedVideoAd`）；TapTap 走其广告 SDK。需定三平台接入路径、对首屏包体（`.pck<5MB`）与 R4 帧预算的影响、隐私 consent 与 localStorage 关系、广告时如何暂停物理 tick 防穿隧，且不得破坏 P1 单指操作与核心循环。

## 决策
1. **外部加载，不进 `.pck`**：广告 SDK 以 HTML shell 内 `<script src=...>`（平台/中介 CDN）加载，**完全在 Godot 包体之外** → 对首屏资源 `.pck<5MB` **零影响**（perf-budget §5 口径不变）。引擎 `.wasm` 仍 CDN 缓存另计。
2. **Godot↔SDK 桥接**：Godot 经 `JavaScriptBridge.eval()` 调平台 API（`hasAd('rewarded')` / `requestAd('rewarded')`）；SDK→Godot 回调用 `JavaScriptBridge.create_callback(callable)` 注册 JS 函数（**禁止每帧 eval 轮询**）。HTML shell 负责 SDK 初始化与回调转发。
3. **优先发行平台 SDK**：推荐入驻 CrazyGames / Poki / GameDistribution——内置 consent（GDPR/CCPA）托管 + rewarded ad API，集成最省；`AdProvider` 抽象层隔离差异，换供应商仅加一个 provider。
4. **`AdManager`（可选 Autoload）+ `AdProvider`（抽象接口）+ `providers/`（具体桥接）**：高层 API `is_revive_available()` / `request_revive(cb)` / `request_double_reward(cb)`；频率上限与 consent 门控；经 `EventBus` 接 `CoreLoop` 死亡/结算，**不参与玩法输入**。
5. **暂停物理 tick**：请求广告前 pause（`get_tree().paused=true` 或停 CoreLoop 物理）；复活仅发生在 RESULT 态（世界已冻结），故无穿隧风险；广告关闭后依 `REVIVE_GRANTED` 结果恢复 RUNNING（清附近障碍 + ~1s 无敌）或维持 RESULT。
6. **频率上限**：`revive_per_run_max=1`、`revive_daily_cap=3`（可配）；计数存 `SaveManager`，仅奖励到账写。
7. **consent 与 localStorage**：平台托管则读平台标志；自接 H5 中介须 HTML shell 内 CMP，consent 串存 CMP 自有键（IAB `tcString`），`SaveManager` 仅读布尔 `ad_consent_given`，**绝不写/覆盖 CMP 键**；游戏数据键 `wasteland_escape_save` 命名空间隔离（见 ADR-004）。
8. **三平台 Provider（`AdProvider` 抽象 + 三套实现）**：同一 `has_ad('rewarded')` / `show_rewarded()` 接口，按运行平台选 Provider——**Web**：HTML shell 外部 `<script>` 加载发行平台/H5 中介 SDK（CrazyGames / Poki / GameDistribution / AppLovin 等），`JavaScriptBridge.eval()` 调 `hasAd/requestAd`、`create_callback()` 收回调；**微信/抖音小程序**：宿主 WebView 容器内原生 API `wx.createRewardedVideoAd()` / `tt.createRewardedVideoAd()`，`show()` + `onClose` 回调经 `JavaScriptBridge` 桥接；**TapTap**：TapTap 广告 SDK（外部 `<script>`，同 Web 桥接模式）。三者均**不进 Godot `.pck`**，对首屏 <5MB 零影响。
9. **复活上限（锁定）**：`revive_daily_cap = 3`（**架构侧锁定值，已与策划侧统一；可配，按平台政策**）、`revive_per_run_max = 1`；与 architecture.md §8.4、control-manifest §H 一致。策划文档曾误写 10，已修正为 3，本 ADR 以 3 为准。

### 三平台 Provider 对照（与 architecture.md §7.4 一致）
| Provider | 目标平台 | 接入方式 | 广告 API |
|---|---|---|---|
| `AdProviderWeb` | Web/HTML5（发行平台 / H5 中介） | HTML shell 外部 `<script>` + `JavaScriptBridge` | `hasAd('rewarded')` / `requestAd('rewarded')` |
| `AdProviderMiniProgram` | 微信 / 抖音小程序（H5 容器） | 容器全局 `wx` / `tt` + `JavaScriptBridge` | `wx.createRewardedVideoAd()` / `tt.createRewardedVideoAd()` |
| `AdProviderTapTap` | TapTap（Web/H5 SDK） | HTML shell 外部 `<script>` + `JavaScriptBridge` | TapTap 广告 SDK rewarded |

- 平台选择：构建/启动期由 `AdManager` 探测运行环境（UA / 全局 `wx`/`tt` / TapTap 注入标志）决定挂载哪个 Provider；小程序与 TapTap 复用同一份 Web 构建产物，仅 Provider 与 HTML shell 不同。
- 三套 Provider 失败/不可用时统一返回 `is_revive_available()=false`，Result UI 不显复活按钮，**游戏照常可玩**（优雅降级）。

## 理由
- 外部 `<script>` + CDN 是 Web H5 广告标准做法，天然零 `.pck` 影响；Godot 帧循环不包含 SDK JS，故 60fps 预算不变。
- `create_callback` 是 Godot 4 Web 推荐的 SDK→Godot 回调机制，避免轮询与帧内 eval。
- 平台 SDK 兜底 consent，省去自研 CMP 合规成本，且更稳过平台审核。
- RESULT 态触发 + 暂停 tick 从根上消除「广告播放时世界推进 / 穿隧 / 回来即死」。
- 频率上限防广告疲劳与平台政策风险；可选 Autoload + MVP 禁用保证核心循环与 P1 零耦合。

## 后果
- 依赖外部网络与平台可用性：SDK 不可用 / consent 拒绝 → `is_revive_available()` 返回 false，Result UI 不显复活按钮，**游戏照常可玩**（优雅降级）。
- 首访 HTML 多一个 `<script>`（`async`/`defer`），不阻塞 Godot 启动；SDK 初始化失败不影响游戏。
- 需主理人定发行渠道后细化具体 provider 与 CMP 方案（CONCERN C6，非阻塞）。
- 复活后短暂无敌 + 清障是设计约定，需 design-strategist 在 GDD 补「复活重置规则」（工程已留接口 `REVIVE_GRANTED`）。
