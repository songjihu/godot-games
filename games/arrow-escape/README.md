# 箭头出逃 · 画中有灵

从 GitHub 克隆后，先在仓库根目录执行 `powershell -ExecutionPolicy Bypass -File scripts/restore-assets.ps1` 还原并校验两张正式漫画，再打开项目。微信导出脚本会自动还原。

基于 Godot 4.6.1 的原创解谜小游戏。当前可玩 20 关，长期规划 100 关、每十关一章。第一章只展开雨画、青龙、半片铜铃与姐姐的线索。

## 当前试玩

微信开发者工具导入工作区 `outputs/wechat-arrow-escape`，AppID 为 `wxc19585dea4453b6b`，编译后预览扫码。后续更新同一目录，无需重复解压。桌面开发可用自编译 Godot 打开本目录 `project.godot`，F5 运行。

点击前方没有阻挡的龙，使它沿路径游出；每关三次机会，支持免费提示、撤销与重开。触摸坐标使用继承本工作区修复的微信适配插件。

## 剧情与收藏

普通关通关后显示一段新线索；第一关开场与第 1、3、6、10 关结尾展示单幅正式国风漫画。漫画由内置 image_gen 生成，不再采用几何拼接人物。素材与提示说明见 `art/comics/PROMPTS.md`。

当前只打包两张四格漫画，逐章读取纹理并按分镜区域显示，保持比例。后续章节原图保存在工作区 `outputs/arrow-story-art-library`，不加入当前微信测试包。100 关章节、悬念和信物节点规划见 `design/season_100.json`。

每两关收集一件章节信物，目前共十件。点击信物条查看全局收藏和下一件目标；按实际完成关卡记录，重复通关不会重复累计，退出后本地保存。升级剧情版本会回到第一关以便看新序章，但保留解锁与收藏进度。

## 广告

广告默认关闭，没有内置真实广告位 ID。预留额外寻路与失败续关两处激励视频入口，前十关无广告，重开免费，主线不靠广告解锁。配置见 `config/ads.json`，详细申请、填写与真机验收步骤见 `design/广告接入步骤.md`。仅在取得资格、有效广告位并启用后才展示真实广告入口；目前可继续免费试玩。

## 验证与打包

使用隔离 APPDATA/LOCALAPPDATA 的测试目录，避免测试覆盖自己的进度。

```powershell
& 'C:\path\to\godot.exe' --headless --path . --script res://tests/verify_game.gd --quit-after 300
```

测试覆盖二十关可解性、349 次移除、触摸分发、提示、撤销、重试、单幅剧情切换、信物保存、100关大纲结构与续关奖励幂等性。工作区运行 `node outputs/arrow-escape/tests/verify_rewarded.cjs` 验证 JS 激励视频完成、中断、报错、重试与回调去重；不替代真实广告验收。

工作区运行 `outputs/export-arrow-wechat.ps1` 重新生成同一微信目录与压缩包。微信使用插件附带的 Godot 4.6.1 WASM 模板，桌面编辑器为本地源码编译版本；本次未重编 WASM。

## 许可与来源

游戏代码见 `LICENSE`。Godot 源码基线 `14d19694e0c88a3f9e82d899a0400f27a24c176e`；导出插件上游 https://github.com/AnranS/godot_for_minigame ，基线 `89672fa0d6acf726eb4cd1b8a4610f8633ac93dc`。插件许可见 `PLUGIN_LICENSE` 及插件目录第三方声明。

中文字体基于 Noto Serif SC，按界面用字裁剪并改名 Arrow Escape Serif，许可 `fonts/OFL.txt`。新增文字后使用 `tools/subset_font.py` 重建字体。音效为本项目自行合成，无外部录音。

第二章无声渡口（11—20关）已开放，新增十段渐进线索与五件信物。收藏册可左右翻章。顶部收藏条、玩法提示、计数各自独立成行；底部状态提示独立面板，与棋盘、按钮保持间距。广告继续关闭，等待用户达到其后台显示的流量主资格后再申请。


## Repository export

From the repository root, run `powershell -ExecutionPolicy Bypass -File scripts/export-wechat.ps1 -GodotPath C:\path\to\godot.exe -AppId YOUR_APP_ID -Game arrow-escape`. Import `exports/wechat-arrow-escape` in WeChat DevTools. Original workspace paths above describe the development environment; use this command after cloning.
