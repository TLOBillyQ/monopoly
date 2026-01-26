# 08 构建与发布（Web）：GitHub Pages 工作流

本工程支持在浏览器中运行（见 README 的在线体验链接），发布链路由 GitHub Actions 负责：构建 `soluna` 的 wasm 运行时，并把游戏资源打包成 zip 上传到 Pages。

## 关键文件

- `.github/workflows/deploy.yml`：Nightly Deploy 工作流
- `.github/assets/index.html`：Web 入口页面（引擎/资源加载由 soluna wasm/js 驱动）
- `main.game` / `main.lua`：运行时入口与配置

## 工作流做了什么

在 `master` push 或手动触发时：

1. `actions/checkout`（含 submodules）
2. 使用 `./soluna/.github/actions/soluna` 构建 soluna（产出 wasm/js）
3. 把游戏内容目录打包为 `main.zip`：
   - `asset core gameplay localization service visual main.game main.lua`
4. 把 wasm/js + `index.html` + 字体 + service worker 拷到 `build/`
5. `actions/upload-pages-artifact` 上传静态站点产物
6. `actions/deploy-pages` 部署到 GitHub Pages

参考：`.github/workflows/deploy.yml`

## 可复用模式

- **引擎产物与游戏内容分离**：运行时（wasm/js）独立构建，游戏内容 zip 化便于缓存与更新。
- **保持同一份 Lua 代码跨平台**：桌面与 Web 共用 `main.lua` / `main.game`（通过 `soluna.platform` 做少量分支，如隐藏 Exit）。

