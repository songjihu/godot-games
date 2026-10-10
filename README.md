# Godot 小游戏合集

使用 Godot 4.6.1 开发、支持导出微信小游戏的源码项目集合。

## Tap Sprint

30 秒内点击移动目标得分，支持最高分保存及重新开始。已加入微信高 DPI 画布、屏幕比例扩展、底部按钮布局和直接触摸处理。用户已确认修复版可运行。示例尚未接入广告、支付或服务端登录。

用 Godot 4.6.1 打开 `games/tap-sprint/project.godot`，按 F5 运行。

## 新增游戏

- [方块消除](games/block-clear/README.md)：8×8 填盘、横竖同时消除、连消奖励、撤销、存档续局，包含中文字体、正式配音和消除动效。
- [箭头出逃 · 画中有灵](games/arrow-escape/README.md)：20 关原创解谜、两章国风漫画、信物收藏、提示与撤销，包含每关递增的通关进度和存档修复。广告默认关闭。

分别打开对应目录的 `project.godot` 即可开发。微信导出命令增加 `-Game block-clear` 或 `-Game arrow-escape`，输出在 `exports/wechat-block-clear` 或 `exports/wechat-arrow-escape`。每款游戏的运行测试及素材许可证见其 README。

首次克隆后，打开《箭头出逃》前执行 `powershell -ExecutionPolicy Bypass -File scripts/restore-assets.ps1`。两张正式漫画以无损分片保存，此脚本合并并校验原图；微信导出会自动执行。分片不是压缩预览图，还原后与开发时原图逐字节一致。

## 导出微信小游戏

在仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/export-wechat.ps1 -GodotPath 'C:\path\to\godot.exe' -AppId '你的小游戏AppID'
```

将 `exports/wechat-tap-game` 导入微信开发者工具，编译后手机预览。导出脚本会先在独立暂存目录构建，再更新输出，保留开发者工具生成的本地配置。

首次导出会从固定上游提交下载 WASM 模板并检查 SHA256；需要网络连接。若通过编辑器内的导出插件操作，请先执行 `powershell -ExecutionPolicy Bypass -File scripts/restore-engine.ps1`。

## 验证

```powershell
node tests/adapter_layout.test.mjs
& 'C:\path\to\godot.exe' --headless --path games/tap-sprint --script ../../tests/verify_touch.gd
```

测试覆盖触摸坐标、设备像素比、一次触摸只计分一次、开始、超时、重开及多种窗口尺寸布局。微信模拟器和目标手机仍需手动检查。

## 引擎与上游

- Godot：`4.6.1-stable`，提交 `14d19694e0c88a3f9e82d899a0400f27a24c176e`，来源：https://github.com/godotengine/godot 。桌面编辑器已在本地从源码构建，仓库不包含其可执行文件或工具链。
- 微信导出插件：[AnranS/godot_for_minigame](https://github.com/AnranS/godot_for_minigame)，基线提交 `89672fa0d6acf726eb4cd1b8a4610f8633ac93dc`，插件源码保存在游戏的 `addons` 目录；配套 WASM 模板由脚本下载到同一目录。
- 微信 WASM 是插件提供的匹配 Godot 4.6.1 的预编译模板，并非本次本地重新编译。
- 本地修改与测试说明见 [docs/wechat-fixes.md](docs/wechat-fixes.md)。

Godot 引擎完整源码可按上述固定版本从上游获取；引擎源码、编译器、编辑器缓存和临时导出包不放入游戏源码仓库。

游戏、插件和引擎分别保留各自许可证；相关文件位于项目根目录及 `games/tap-sprint`。
