# Godot 引擎版本（钉版）

> 解决 C-B（原 sprint1-self-check B7）：引擎 / GUT 版本未钉。

## 锁定的版本

| 组件 | 版本 | 来源 / 说明 |
|---|---|---|
| Godot 引擎 | **4.3.x** | `project.godot` → `config/features="4.3"`；Web 后端 `gl_compatibility`（WebGL2） |
| GUT（Godot Unit Test） | **9.4.0** | `bitwes/Gut` 标签 `v9.4.0`，MIT 许可；官方兼容性表：9.4.0 对应 Godot 4.3–4.4 |

## 版本选型依据

- GUT 官方版本矩阵（README）：
  - 9.6.1 → Godot 4.6.x（**超出版本，不采用**）
  - 9.5.0 → Godot 4.5.x
  - **9.4.0 → Godot 4.3.x – 4.4.x（本项目 4.3，采用）**
  - 9.3.0 → Godot 4.2.x
- 选型结论：钉 **Godot 4.3 + GUT 9.4.0**，避免 headless 测试因版本错配而解析失败。

## 安装位置

- GUT addon 落在 `res://addons/gut/`（即工作区 `addons/gut/`）。
- **不进首屏 `.pck`**：`project.godot` 的 Web preset 用 `export_filter="all_resources"`，但 GUT 仅在编辑器 / 测试时启用，发布导出建议用 `export_filter` 或 `.export` 剔除 `addons/gut`（避免把测试框架打进生产包）。
- GUT 为 MIT 许可，可随仓库 vendored 或 git submodule 引入；本切片采用「下载 release 解压 `addons/gut`」方式（见 `tests/README.md`）。

## 升级策略

- 升级 Godot 大版本时，同步按官方矩阵上移 GUT（如升 4.6 才可用 9.6.1）。
- 钉版提交哈希入 `.github/workflows/ci.yml`，保证 CI 可复现。
