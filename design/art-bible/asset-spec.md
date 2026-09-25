# 资产规格文档 (Asset Spec) — 《WASTELAND ESCAPE / 废土逃生》

> 阶段：Phase 4 预制作 · 视觉资产交付物（lean）
> 作者：林绘澄（美术总监 / art-director-3）｜ 对齐文档：art-bible.md(v5) · accessibility.md(v5) · autoload/Tuning.gd · adr-001 · adr-002 · perf-budget.md · obstacle-gen.md · architecture.md §6
> 引擎：Godot 4（gl_compatibility / WebGL2）· 目标平台 Web/HTML5 + TapTap + 微信/抖音小程序
> 形态：2.5D 伪3D 三轨背后视角（伪透视投影，非 Node3D）

---

## 0. 坐标系与尺寸基准（必读 · 伪透视下视觉对齐的根）

本作**不使用真实 3D 相机 / Node3D**。世界实体（玩家、障碍、拾取）均为 **Sprite2D 广告牌（billboard）**，由 `core/projection.gd` 的纯数学 `project(worldX, z)→(screenX, screenY, scale)` 每帧投影到屏幕。纵深感由 `TrackView`（单 CanvasItem 自绘伪透视道路/车道线）+ `BackgroundRoot`（天空/远景）+ 距离雾（代码 alpha 衰减）卖出。

**LaneGeometry 真值（全部来自 `autoload/Tuning.gd`，唯一真值源）**

| 常量 | 值 | 含义 / 推导 | 在资产规格中的用途 |
|---|---|---|---|
| `PPM` | 50 px/m | 世界尺度（perf-budget §1） | 玩家高 ≈1.8m → 90px @720p |
| `laneSpacingPx` | **100 px** | 相邻轨中心距 = `laneWidthM(2.0) × PPM(50)` | 轨道视觉/碰撞横向基准 |
| `playerHalfWidthPx` | **20 px** | 玩家碰撞半宽 | 玩家壳宽 = 2×20 = **40px** |
| `obstacleHalfWidthPx` | **20 px** | 障碍碰撞半宽 | 障碍壳宽 = 2×20 = **40px** |
| `SCREEN_W / H` | 1280 × 720 | 视口基准 | 导出基准分辨率 |
| `PROJ_focal` | 300 | 焦距 px（**C7 playtest 校准**） | 投影 scale 系数 |
| `PROJ_horizonY` | 252 (0.35×H) | 灭点屏幕 y | 道路收敛点 |
| `PROJ_screenCenterX` | 640 (0.5×W) | 屏幕中心 x | 中轨投影基线 |
| `PROJ_camNear` | 1.0 | 近裁剪补偿 | 防 z→0 除零 |
| `CORNER_yaw / _duration` | 90° / 1.0s | 过弯旋转（C7 校准） | corner_lean / 过弯演出 |

**关键约定（美术必须遵循）**
1. **z=0 参考帧 = 1:1**：玩家恒在 `z=0`（`scale = focal/(0+camNear)` 经 C7 校准后，z=0 时 `scale≈1.0`，即 **1 世界 px = 1 屏幕 px**）。所有世界广告牌**按 z=0 参考尺寸绘制**，引擎运行时按 `scale(z)` 仅做**缩小**（障碍自远 z 向玩家推进时变小），**绝不放大** → 故作者只需按最大可见尺寸（=z=0 尺寸）出图，无 upscale 模糊风险。
2. **三条轨在 z=0 的横向屏幕偏移**（来自 `laneSpacingPx=100`，中轨=屏幕中线）：
   - 左轨 (lane0)：`screenCenterX − 100 = 540`
   - 中轨 (lane1)：`640`
   - 右轨 (lane2)：`screenCenterX + 100 = 740`
   - 即玩家/障碍在世界中的 `worldX = (lane−1) × laneSpacingPx`；投影 `screenX = 640 + worldX × scale`。
3. **相邻轨掠过横向净空** = `laneSpacingPx − playerHalfWidthPx − obstacleHalfWidthPx` = 100 − 20 − 20 = **60 px**（近失 `flank` 几何基础，见 obstacle-gen §2.3 / §8）。美术出图时**障碍视觉半宽 ≤ 30px（即宽 ≤ 60px）**，否则会视觉侵入相邻轨、破坏"哪条轨有险"的读图（Blocker 建筑视觉可略宽，见 §1.2）。
4. **锚点统一**：地面实体（玩家、站立/地面障碍、地面拾取）`pivot = 底中（bottom-center）`，使其基线对齐投影地面点 `screenY = horizonY + groundDrop × scale`；悬空实体（Overhead 横杆、Moving 摆块）`pivot = 中心（center）`，由代码给定离地高度。
5. **碰撞壳 vs 视觉**：碰撞壳严格 = `2 × obstacleHalfWidthPx`（40px 宽）；视觉剪影可略大于碰撞（提升辨识），但**绝不窄于碰撞**，且横向不侵入相邻轨净空（见第 3 条）。

---

## 1. 资产总表（按类别）

> 命名前缀：`chr_`(角色) / `obs_`(障碍) / `pkp_`(拾取) / `env_`(环境) / `fx_`(粒子) / `ui_`(界面) / `sfx_`(音效，占位给音频总监)。
> 「Atlas」列指向 §3 的图集分组。`Frames` 列给**出图帧数建议**（配合代码 squash-stretch，详见美术圣经第 9 节 / perf-budget §5「用代码替代多帧」）。

### 1.1 角色 Runner（`chr_runner`）
追尾视角、圆润兜帽幸存者（珊瑚 `#FF6B5E` 辉光 + 脚下光环），固定屏幕下中。

| 状态 (state) | 触发 | 建议帧数 | 代码增强（省帧） | 视觉要点 |
|---|---|---|---|---|
| `idle` | MENU / COUNTDOWN 静置 | 2（呼吸） | 代码微 bob | 兜帽背影、背包；仅菜单用 |
| `run` | GROUND_RUN 默认循环 | **4** | 落地 squash 微动、rim 辉光烘焙 | 跑动循环；圆润肩背剪影 |
| `lane_switch` | LANE_CHANGE 横向 lerp | 0（复用 run）+ **1** 倾斜叠加帧 | 横向 x lerp（LaneSystem）、地面箭头闪 | 切轨轻微侧倾；**不新增独立帧集** |
| `jump` | JUMP 起跳/滞空/落地 | **2**（蹬地收腿、滞空） | 起跳前 anticipate 前倾（代码）、抛物线轨迹代码驱动 | 二段跳前可衔接 |
| `double_jump` | DOUBLE_JUMP（核心档） | **1**（空中剪腿） | **残影拖尾**（2–3 个淡化副本，代码；Reduce Motion 下关闭） | 紫调拖尾可选 |
| `slide` | SLIDE（`tSlide=0.45s`） | **2**（入铲、保持） | 碰撞壳高度收缩（代码） | 矮身 silhouette，下沿贴地 |
| `corner_lean` | CORNER 过弯（核心档） | **1–2**（倾身入弯） | yaw 耦合倾斜（代码）；Reduce Motion 降级为瞬时对齐 | 仅过弯子态 |

- **帧预算合计**：去重后 ≈ **14 帧**（run4 + idle2 + jump2 + dbl1 + slide2 + corner2 + lean-overlay1），全部纳入 `atlas_gameplay` 单张角色子区。
- **参考尺寸（z=0）**：剪影宽 **44px**（≈ `2×playerHalfWidthPx` + 4px rim 容差）、高 **88px**（≈1.76m @PPM=50）；`pivot=bottom-center`。碰撞壳宽 40px 居中（不可见）。
- **色板**：主体珊瑚 `#FF6B5E` 辉光 + 兜帽/护目镜/背包顶点色深暮蓝 `#2B3A55` 系；脚下光环薄荷青 `#36E2C2` 在 `chr_blob_shadow` 表现（见 §1.5 注）。

### 1.2 障碍（`obs_*`）— 语义固定：危险=锐角+脉动红 `#FF3B5C`
来自 obstacle-gen §2.2，三轨分别布置；**CORNER 段仅中轨、仅 JUMP/SLIDE 可解类型**（见 §2.5 约束，美术需保证中轨 Overhead/Spike 在过弯视角下仍清晰）。

| 类型 | GDD 名称 | 所需动作 | 所在轨 | 碰撞壳 (引用常量) | 视觉尺寸 (z=0) | pivot | 帧/动画 | 美术方向 |
|---|---|---|---|---|---|---|---|---|
| `obs_spike` | 钢筋尖刺/丧尸爪 | JUMP 或 SWITCH | 单轨 L/C/R | 宽 `2×obstacleHalfWidthPx`=**40px** | 40w × 36h（低三角） | bottom-center | 0（静态）+ 脉动描边（代码） | 锐角红三角，去写实；脉动限频防光敏 |
| `obs_overhead` | 断梁/横杆 | SLIDE 或 SWITCH | 单轨 L/C/R | 横杆 rect（宽 40，高 24，离地 ~45px） | 40w × 90h（上 1/2 为横杆，下 1/2 透明=滑过净空） | center（代码定离地高） | 0 + 脉动 | 红横杆悬空；下方透明区=滑铲通道；**切勿画成落地柱** |
| `obs_blocker` | 裂墙/残破建筑（满高） | **SWITCH only** | 单轨 L/C/R | 宽 40（碰撞） | 视觉宽 ≤ **60px**（半宽≤30，不侵邻轨）、高 **160px**（满高） | bottom-center | 0 + 轻微脉动/裂纹摇 | 暮蓝 `#2B3A55` 残破立面 + 红裂痕提示；**满高不可跳/滑**，靠切轨规避 |
| `obs_gap` | 坍塌缺口 | JUMP（时机） | 单轨 L/C/R | GDD 按 z 长度判定（非 x 半宽） | **x 视觉填轨 ≈ `laneSpacingPx`=100w**（车道断裂带）× 矮 wedge；pivot bottom-center | bottom-center | 0 | **特例**：视觉 x 填轨（读图"此轨断口"），碰撞走 GDD z-长度；深色裂口 + 边缘碎渣 |
| `obs_moving` | 游荡丧尸/翻倒车（核心档） | 时机/切轨 | 跨轨摆动 | 宽 40 | 40w × 48h（悬空摆块） | center（代码横向摆） | 0 + 摆动（代码位置） | 红横移块；摆动范围/频率由 core-loop 确认（CONCERN，跨 GDD） |
| `obs_sequence` | 丧尸潮/连环坍塌（核心档） | 连续切轨 | 三轨错落 | — | **无独立美术**：复用 spike/overhead/gap 三轨错落排布 | — | — | 仅为生成模式，不新增资产 |

- **脉动规范**：危险"脉动"= 慢速柔和描边亮度振荡（非频闪）；`accessibility.md` 照片敏感安全模式下转**静态描边**。所有障碍共享同一 `obs_pulse_stroke` 描边风格，保证"同危险语言"。
- **形状冗余**（不靠颜色）：Spike=三角、Overhead=横杆、Blocker=满高立面、Gap=地面断口 —— 玩家凭形状即可判"哪条轨有险、需何种动作"，呼应美术圣经第 4/7 节。

### 1.3 拾取物（`pkp_*`）
尺寸贴合 `playerHalfWidthPx=20`（壳径 40），旋转/浮动由代码驱动省帧。

| 类型 | 语义 | 尺寸 (z=0) | pivot | 动画（代码） | 色 |
|---|---|---|---|---|---|
| `pkp_coin` | 补给/分数（gold） | **40×40** 盘（≤2×playerHalfWidthPx） | center，离地 ~胸高 | `scale.x` 振荡模拟旋转（0 帧）；浮起 bob | 金 `#FFD23F`，高饱和 |
| `pkp_medkit` | 急救包/连击星（核心档，置于风险轨夹击位） | **40×40** 星/盒 | center | 轻旋 + 紫辉光 | 紫 `#B66BFF` |

- 拾取物独立池 `pickupPoolSize=32`（adr-002）；视觉需与危险红明确区分（金/紫 ≠ 警示红）。

### 1.4 环境（`env_*`）— 多为代码绘制，非位图
| 资产 | 形态 | 是否位图 | 说明 |
|---|---|---|---|
| `env_track` | 伪透视道路 + 三轨线收敛灭点 | **否（CanvasItem 自绘，1 draw call）** | `TrackView` 代码绘制；轨道边界薄荷青 `#36E2C2` 发光描边 + 地面雪佛龙箭头（方向/切轨提示）；过弯前转向箭头预告。无贴图负担 |
| `env_chevron` | 地面方向箭头/雪佛龙 | 可选 ≤128px 小 glyph（或纯代码绘制） | 三轨可读性冗余提示（位置+图标，色盲友好） |
| `env_bg_sky` | 天空渐变（脏橙 `#E08A4A`→灰蓝硝烟 `#4A5360`） | 否（代码渐变） | 废土黄昏/夜调；`BackgroundRoot` 渐变 + 可选轻度颗粒/暗角 |
| `env_bg_ruins` | 远景废墟天际线（低多边形剪影，1–2 层视差） | **是，≤256px atlas**（`atlas_bg`） | 2–3 draw call；过弯可随 yaw 旋转；不写实、低饱和做旧 |
| `env_fog` | 纵深雾 / 尘霾 | 否（代码：sprite 按 z 距离 alpha 衰减 + 灭点附近 haze 渐变带） | 零几何成本卖纵深；雾距须保证**最远可反应距离内障碍清晰**（GDD 反应窗口，不可过浓牺牲可读性） |
| `env_vignette` | 暗角 / 轻微 bloom（可关） | 否（cheap 后处理） | 过弯/受击过渡用；Reduce Motion/照片敏感下弱化 |

### 1.5 VFX（`fx_*`）— `ParticlePool` 硬上限 120（落地/速度线/拾取共享）
| 资产 | 触发 | 尺寸 (z=0) | pivot | 色 | 备注 |
|---|---|---|---|---|---|
| `fx_graze` | 擦身近失火花（NEAR_MISS graze/flank） | glyph ≤64 | center | 金白 `#FFD23F`/`#FFF` | 横向掠过/贴脸时迸发；短促 |
| `fx_dust_land` | 落地尘（非血） | glyph ≤64 | bottom-center | 尘色（暖灰） | 落地 squash 同步；**避开写实血液**（accessibility 基线） |
| `fx_revive` | 复活光效 | glyph ≤128（或代码径向） | center | 薄荷青 `#36E2C2` 径向辉光 + 环 | REVIVE_GRANTED 后 ~1s 无敌表现 |
| `fx_speedline` | 速度尘霾线 | glyph ≤64 | center | 半透白/尘 | 随 V 增强；**Reduce Motion 下关闭** |
| `fx_pickup_sparkle` | 收集闪光 | glyph ≤64 | center | 金 `#FFD23F` | 弹跳放大 + sparkle |
| `chr_blob_shadow` | 玩家脚下廉价阴影（**无实时阴影**） | 48×16 椭圆 | center | 半透黑 | 仅玩家；障碍用自身底部 1px 暗基（省 draw call），不单独投影 |

- 全部 VFX 合入 `atlas_fx`（≤256×256）。粒子池化、同屏 ≤120（perf-budget §4）。

### 1.6 UI 精灵（`ui_*`）— HUD/菜单/按钮（2D 覆盖层，CanvasLayer）
| 资产 | 用途 | 形态 | 色/风格 |
|---|---|---|---|
| `ui_hud_distance` | 顶部距离 | 代码文本 + 细面板 | 薄荷青强调、圆角块面 |
| `ui_hud_score_combo` | 角部分数/连击数 | 文本 + 紫辉光（连击增长） | 紫 `#B66BFF` |
| `ui_hud_energy` | 能量条 | 代码条 + 描边 | 薄荷青 |
| `ui_lane_dots` | 三轨指示（3 圆点/高亮） | 图标 + 代码高亮（位置+图标冗余，非纯色） | 当前轨薄荷青脉冲 |
| `ui_icon_*`（coin/medkit/lane-arrow/pause/sound/settings） | 图标集 | atlas glyph（圆润几何+末世符号，统一描边权重） | 语义色 |
| `ui_btn_*` | 胶囊按钮（开始/重开/复活/翻倍） | 代码圆角 + 珊瑚主/暮蓝次/薄荷 hover | 珊瑚 `#FF6B5E` / 暮蓝 `#2B3A55` / 薄荷 `#36E2C2` |
| `ui_panel_menu` / `ui_panel_result` | 菜单/结算玻璃拟态面板 | 暗底 + 做旧描边（代码渐变 + `atlas_bg` 复用） | 废土黄昏渐变背景 |
| `ui_font` | 圆角几何无衬线（Nunito 类，粗体） | `.ttf` 子集（拉丁+必要字形） | 小屏可读、粗体 |

- UI 合入 `atlas_ui`（≤1024×1024）。三轨可读性/过弯防眩晕的 HUD 提示在 **Basic 即生效**（美术基线，不随档位关）。

### 1.7 音效占位（标注给音频总监 阮和鸣 · 本文件仅占位，不产出音频）
> 格式建议：短 `ogg`（Web 友好）；首访 `AudioServer` 须首次输入 resume（自动播放策略，perf-budget §6）。体积计入首屏预算（见 §3.4）。

| 占位 ID | 触发 | 建议时长 | 备注 |
|---|---|---|---|
| `sfx_jump` / `sfx_double_jump` | JUMP / DOUBLE_JUMP | 0.15–0.3s | 轻跃动 |
| `sfx_slide` | SLIDE | 0.3–0.5s | 摩擦尘声（非血） |
| `sfx_lane_switch` | LANE_CHANGE | 0.1s | 脚步/位移 |
| `sfx_land` | 落地 | 0.15s | 配 dust |
| `sfx_graze` | NEAR_MISS | 0.1–0.2s | 擦身"嗖"；配 sparks |
| `sfx_pickup_coin` / `sfx_pickup_medkit` | PICKUP | 0.1–0.2s | 金/紫音高区分 |
| `sfx_combo_tick` | 连击增长 | 0.05s | 高频 tick（可随 combo 升调） |
| `sfx_hit`（fatal） | FATAL_HIT | 0.3–0.5s | 柔和（非刺耳）；配尘土非血 |
| `sfx_revive` | REVIVE_GRANTED | 0.5–1s | 薄荷青光效配乐 |
| `sfx_corner` | CORNER_ENTER/EXIT | 0.4s | whoosh（Reduce Motion 下可弱化） |
| `sfx_ui_click` / `sfx_ui_back` | 菜单交互 | 0.05–0.1s | — |
| `bgm_ambient`（loop） | RUNNING 环境垫底 | 循环 ≤ 1.5MB | 废土黄昏 drone，低动态 |
| `bgm_menu` | MENU | 循环 ≤ 1MB | 轻量 |

---

## 2. 逐资产尺寸 / 锚点 / 导出规格（明确引用 LaneGeometry 真值）

> 通用导出：源文件 Aseprite/矢量；**单 sprite ≤ 256px**；atlas 合并；压缩 `.webp`（Web/小程序）/ Godot `.ctex`；无 normal map、无 PBR、优先顶点色/纯色块。幂透明（premultiplied alpha）。

| 资产 | 宽×高 (z=0, px) | pivot | 引用常量 | 导出格式 / 备注 |
|---|---|---|---|---|
| `chr_runner`（全帧） | 单帧 44×88；整 sheet ≤ 256×256 | bottom-center | `playerHalfWidthPx=20`→壳宽40；`PPM=50`→高≈1.76m | atlas_gameplay；RGBA `.webp` |
| `obs_spike` | 40×36 | bottom-center | `obstacleHalfWidthPx=20`→壳宽40 | 静态+代码脉动 |
| `obs_overhead` | 40×90（上1/2横杆） | center（代码定离地~45px） | 壳=横杆 rect 40×24 | 下1/2 透明=滑过净空 |
| `obs_blocker` | 视觉 ≤60×160（碰撞40×160） | bottom-center | 视觉半宽≤30（**不侵邻轨净空60**）；`obstacleHalfWidthPx=20` | 满高立面 |
| `obs_gap` | x≈`laneSpacingPx=100` 填轨 × 矮 wedge | bottom-center | **特例**：x 视觉填轨=100；碰撞走 GDD z-长度 | 深色裂口 |
| `obs_moving` | 40×48 | center（代码横摆） | `obstacleHalfWidthPx=20` | 核心档 |
| `pkp_coin` / `pkp_medkit` | 40×40（≤`2×playerHalfWidthPx`） | center，离地胸高 | `playerHalfWidthPx=20` | 代码旋/浮 |
| `env_bg_ruins` | ≤256×256（每层） | — | — | atlas_bg；2 层视差 |
| `env_chevron` | ≤128×128 | center | `laneSpacingPx=100` 间距铺设 | 可选 glyph |
| `fx_*` | glyph ≤64（revive ≤128） | 见 §1.5 | — | atlas_fx |
| `chr_blob_shadow` | 48×16 | center | 跟随玩家 x、贴地 | 半透黑 |
| `ui_icon_*` | ≤64×64 each | center | — | atlas_ui |
| `ui_font` | `.ttf` 子集 | — | — | ≤0.3MB |

**横向对齐校验（伪透视下）**：在 z=0 平面，左/中/右轨中心间距 = `laneSpacingPx=100`；玩家壳宽 40、障碍壳宽 40 → 同轨内玩家与障碍中心重合即碰撞；相邻轨中心距 100 − 40 = 60px 净空（= `laneSpacingPx − playerHalfWidthPx − obstacleHalfWidthPx`）即为 `flank` 近失几何基础。美术出图须保证：**任何障碍视觉半宽 ≤ 30px**，否则视觉上会"压线"误导切轨判断（Blocker 上限 30px 半宽 / 60px 全宽已含此约束）。

---

## 3. 图集与导出规范

### 3.1 图集分组（atlas packing）
| 图集 | 内容 | 单 sheet 上限 | 压缩后目标 |
|---|---|---|---|
| `atlas_gameplay` | chr_runner 全帧 + obs_* + pkp_* + env_chevron | 1024×1024 | ≤ 1.0MB |
| `atlas_ui` | ui_icon_* + ui_btn 九宫 + ui_panel 元素 | 1024×1024 | ≤ 0.8MB |
| `atlas_bg` | env_bg_ruins（2 层） | 512×512 | ≤ 0.3MB |
| `atlas_fx` | fx_* + chr_blob_shadow | 256×256 | ≤ 0.2MB |
| `ui_font` | 圆角无衬线子集 | — | ≤ 0.3MB |

- **全部走 atlas 合批**（adr-001：障碍/拾取 Sprite 共享 atlas 材质 → draw call 仍 ≤50；架构 §6.4 估算全屏 15–30 call）。
- **单图 ≤256px**；单 asset 文件（atlas）≤ ~1.0MB。
- 压缩：Web/小程序用 `.webp`（quality≈85），Godot 导入为 `.ctex`（压缩纹理）；prefer **单通道/索引** 对小 glyph。

### 3.2 无实时阴影（美术红线）
- **禁用一切实时阴影 / 阴影贴图**。唯一阴影 = `chr_blob_shadow`（玩家脚下椭圆 Sprite2D，半透黑，48×16）。
- 障碍**不单独投影**（省 draw call）：在其自身底部画 1px 暗基即可；地面接触感由 `env_track` 代码绘制承担。

### 3.3 Reduce Motion / 照片敏感 降级清单（accessibility.md v5）
> 默认出厂 = **Standard**；Basic 含三轨可读性+过弯防眩晕基线；Comprehensive 含 Reduce Motion + 照片敏感安全模式。下表列出须提供降级变体的资产/动效。

| 资产 / 动效 | 默认 | Reduce Motion（Comprehensive） | 照片敏感安全模式 |
|---|---|---|---|
| 过弯旋转 yaw（CORNER） | 缓入缓出旋转 + 运动模糊/暗角 | **降级为瞬时对齐 / 弱化旋转** | 同 RM（无强闪） |
| 速度尘霾线 `fx_speedline` | 随 V 增强 | **关闭** | 关闭 |
| 相机 kick（受击屏震） | 小幅屏震 + 红暗角闪 | **关闭/大幅减弱**（屏震可关，Basic 设置项） | 红闪→**柔和淡入**（非频闪） |
| 危险脉动 `obs_*_pulse` | 慢速柔和描边振荡 | 保留（非运动型，可留） | **转静态描边**（禁用振荡） |
| 玩家二段跳残影拖尾 | 2–3 淡化副本 | **关闭** | 关闭 |
| 落地 squash & stretch | 明显 | **减弱**（保留极轻） | 保留减弱 |
| 视差加速（BackgroundRoot） | 随 V | **减弱** | 减弱 |
| 暗角 / bloom（可关） | 轻量 | 可关 | 可关 |
| 三轨可读性（边界发光+箭头+位置） | 常驻 | **常驻（基线，不关）** | 常驻 |
| 过弯防眩晕（角速度限频/缓动） | 常驻 | 常驻（基线） | 常驻 |

- **验收**：Basic 单指可玩 + 危险无颜色也可辨 + 三轨可凭边界/箭头/位置分辨 + 过弯无频闪；Comprehensive 重映射/照片敏感无频闪/RM 降级生效（accessibility §4）。

### 3.4 体积控制（首屏 <5MB 口径）
> 口径（perf-budget §5 / core-loop §4 已采纳）：**游戏资源 `.pck` <5MB**；引擎 `.wasm`(~30–40MB) 经 CDN + brotli/gzip 缓存，**不计入**首屏可玩资源。

| 分组 | 预算上限 | 说明 |
|---|---|---|
| 美术图集合计（4 atlas + font） | **≤ 2.6MB** | atlas_gameplay1.0 + ui0.8 + bg0.3 + fx0.2 + font0.3 |
| 音频（占位，音频总监产出） | **≤ 1.8MB** | 短 ogg SFX(~0.6–1.2) + ambient/menu loop(~0.6–1.0) |
| 场景/脚本/其他 | **≤ 0.6MB** | `.tscn`/`.gd` 极小 |
| **合计目标** | **≤ 5.0MB（留 ≤0.5MB 余量 → 控 ≤4.5MB）** | 单资产 ≤1.0MB |

- 省体积手段：全量 atlas、≤256px、`.webp/.ctex`、代码 squash-stretch 替代多帧（perf-budget §5）、音频短 `ogg`、字体子集。
- 移动端 480p 仅降渲染分辨率，不改资源（PPM 固定保可读）。

---

## 4. 分平台适配注意（Web / TapTap / 微信·抖音小程序）

三平台共用**同一份 Godot HTML5 构建产物**（H5 容器加载），差异在**资源加载时序 / 容器约束 / 广告 SDK 接入**（architecture §7）。

| 维度 | Web/HTML5 | TapTap | 微信/抖音小程序（H5 容器） |
|---|---|---|---|
| 引擎加载 | `.wasm` CDN + brotli/gzip 缓存 | 同 Web（SDK 外部 `<script>`） | 容器 WebView 加载同构建；冷启受容器限制 |
| 资源包 | `.pck` <5MB 首屏；可流式 | 同 | **容器对包体/网络更敏感**：建议**核心 atlas 优先 BOOT 加载**（`atlas_gameplay`+`atlas_ui`），`atlas_bg`/`atlas_fx`/音频**延迟到 COUNTDOWN/首 RUNNING** 前懒加载 |
| 持久化 | `window.localStorage`（JSBridge） | 同 | 容器内 localStorage 同 Web；不可用时降级内存（同 §7.1） |
| 广告 SDK | 外部 `<script>`（发行平台/中介），不进 `.pck` | TapTap 广告 SDK 外部 `<script>` | **容器原生 API**：`wx.createRewardedVideoAd()` / `tt.createRewardedVideoAd()`，由 `AdProviderMiniProgram` 桥接；不进 `.pck` |
| 音频策略 | 首次输入 `AudioServer` resume | 同 | 同（容器内自动播放策略） |
| 适配建议 | 视口 1280×720，`stretch=viewport/aspect=expand`；移动端 480p 兜底 | 同 | 同；注意容器安全区/手势冲突（滑动切轨 vs 容器返回手势，需在容器中屏蔽/映射） |
| 切后台 | `visibility_changed` 暂停物理 tick | 同 | 同（容器 onHide/onShow 映射） |

- **美术侧动作**：所有平台资源**统一 atlas 命名与尺寸**（不分支）；仅加载时序可在 BOOT/COUNTDOWN 拆分（见上表懒加载）。**绝不**因平台分支而出多套美术（保一致性 + 控体积）。
- 小程序**手势冲突**是真实风险：左右滑切轨可能被容器当作"返回/退出"。需与工程（AdProviderMiniProgram / InputManager）协同，在容器层屏蔽横滑返回或改映射——美术无需改，但出图时**切轨方向箭头/三轨指示须足够清晰**以补偿任何输入延迟。

---

## 5. 开放风险 & 灰模优先清单（垂直切片可先用占位）

### 5.1 可先出「灰模/占位」即可做垂直切片的资产（**建议 Phase 4 垂直切片先用 primitive 占位**）
> 原则：用**纯色块/圆/三角 + 语义色**（不依赖精细美术）即可验证投影、近失、可解性、过弯；真实美术 = 后续 polish pass。

| 资产 | 占位方案 | 验证目标 |
|---|---|---|
| `chr_runner` | 珊瑚色圆角胶囊（44×88）+ 代码 squash | 投影锚点、切轨 lerp、跳/滑壳高 |
| `obs_spike` | 红三角 40×36 | 跳/SWITCH 判定、形状冗余 |
| `obs_overhead` | 红横杆 40×24 悬空 | 滑铲净空、碰撞 sub-rect |
| `obs_blocker` | 暮蓝满高矩形 40×160 | SWITCH-only、满高不可跳 |
| `obs_gap` | 黑/暗色车道断带（x=100 填轨） | JUMP 时机、z-长度碰撞 |
| `pkp_coin/medkit` | 金/紫圆 40 | 拾取池、近失/收集事件 |
| `env_track` | 代码绘制三色带 + 灭点（已实现） | 伪透视道路、车道线 |
| `env_bg_ruins` / `env_fog` | 纯色渐变占位 | 纵深/可读性 |
| `fx_*` | 单像素/小方块粒子 | 粒子池上限 120 |
| `ui_*` | 文本 + 代码圆角 | HUD 只读订阅链路 |

### 5.2 必须先出真实美术（不可长期占位）的资产
- `obs_blocker` 残破建筑立面（满高辨识 + 暮蓝/红裂痕语义，影响 SWITCH 决策可读性）。
- `chr_runner` 圆润兜帽 silhouette（玩家珊瑚辉光 vs 危险红的形状/亮度差，R5 夜调分辨关键）。
- `env_bg_ruins` 远景天际线（氛围卖点，但可最后做）。
- 危险**脉动描边风格统一**（所有 obs 共享，防歧义）。

### 5.3 开放风险（标注 CONCERN，非阻塞）
| 风险 | 影响 | 建议 |
|---|---|---|
| **C7 投影参数未校准**（focal/horizonY/laneSpacingPx/camNear/yaw） | 资产 z=0 参考尺寸假设依赖投影；参数若大幅调整，广告牌绝对屏幕位置/大小会变 | **资产按 z=0 参考 + 常量参数化出图**；投影定标后仅调 `Tuning` 不改美术；垂直切片即用占位验证 |
| **R5 夜调可读性**（玩家珊瑚 `#FF6B5E` vs 危险红 `#FF3B5C` 同红系） | 暗调下玩家/危险易混 | 靠形状差（圆润 vs 锐角）+ 玩家常亮 rim/光环 + 危险脉动；**夜调下实景复核**（playtest） |
| **相邻轨净空 60px 与 nearMissBand 24px 关系**（obstacle-gen §8 CONCERN） | flank 近失触发阈值待 playtest | 常量已落地使公式可验；美术保证障碍视觉半宽≤30 不侵净空 |
| **Moving 跨轨摆动语义**（core-loop 待确认） | obs_moving 摆动范围/频率未定 | 核心档资产先按静态 40×48 出，摆动由代码位置驱动，不依赖美术帧 |
| **Gap 视觉 x 填轨 vs 碰撞 z-长度**（特例） | 易误当成 x-半宽障碍 | 美术明确：Gap 视觉 x=车道宽(100)、碰撞走 GDD z-长度；出图用深色裂口+边缘碎渣区分 |
| **首屏 5MB 口径**（perf-budget §5，主理人已采纳资源口径） | 音频若膨胀可能破线 | 音频短 ogg + 字体子集；控合计 ≤4.5MB，预留余量 |
| **小程序手势冲突** | 切轨输入可能被容器吞 | 与工程协同屏蔽横滑返回；美术强化三轨指示/方向箭头补偿 |

---

## 附录 A · 命名约定（与 entity-inventory / 资产清单对齐）
- 前缀：`chr_` `obs_` `pkp_` `env_` `fx_` `ui_` `sfx_`（见 §1）。
- 图集：`atlas_gameplay` / `atlas_ui` / `atlas_bg` / `atlas_fx`。
- 帧命名：`chr_runner.run.00`..`chr_runner.run.03`、`chr_runner.jump.00`.. 等；动画状态名与 Player.gd 子状态机（GROUND_RUN/LANE_CHANGE/JUMP/DOUBLE_JUMP/SLIDE/CORNER）一致。
- 所有数值（尺寸/间距/半宽）**仅引用 `autoload/Tuning.gd` 真值**，美术文档不另写常量（一致性红线）。

## 附录 B · 资产清单状态
- 本文件为 **Phase 4 规格（spec）**，非成品资产；实体文件（`.png`/`.ase`/`.import`）待美术生产。
- 垂直切片阶段按 §5.1 灰模占位即可推进引擎/玩法联调；§5.2 真实美术按优先级补产。
- 主资产清单（`design/assets/entity-inventory.md` / `asset-manifest.md`）由美术在生产期据本规格回填（本文件不替写，防漂移）。

---
*落盘：design/art-bible/asset-spec.md · 作者 art-director-3（林绘澄）· Phase 4 预制作 · 对齐 art-bible(v5)/accessibility(v5)/Tuning.gd/adr-001/adr-002/perf-budget/obstacle-gen/architecture §6*
