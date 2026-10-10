# Tap Sprint

Godot 4.6.1 源码项目：30 秒限时点击得分，支持重新开始和本地最高分保存。

用 Godot 打开 `project.godot` 后按 F5 运行。项目使用 OpenGL Compatibility 渲染。

微信导出插件已放入 `addons/godot_mini_game/`。使用配套 Godot 编辑器执行：

```text
godot --headless --path <本项目目录> --editor --import --quit
godot --headless --path <本项目目录> --script res://export_wechat.gd -- <工程输出绝对路径> wxc19585dea4453b6b
```

微信小游戏适配代码来自 AnranS/godot_for_minigame，保留原许可证。
引擎模板要求编辑器与 Godot 4.6.1 对应的上游提交匹配。模板源码构建入口见 `upstream-tools/build_wasm_template.sh`，原始说明见 `upstream-tools/USAGE_zh.md`。

没有接入真实广告、支付或登录；不需要 AppSecret。导出后仍需在微信开发者工具及真机验证。
