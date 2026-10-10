# 方块消除 / Block Clear

独立 Godot 4.6.1 项目，原创程序绘制界面。8×8 无尽填盘、三组选块、横竖同时消除、连续消除奖励、一步撤销、中途存档与最高分保存。出块采用简单随机规则，没有声称还原任何原作的内部算法。

## 手动运行

用已编译的 Godot 导入本目录的 `project.godot`，按 F5。支持鼠标拖放和手机触摸；也可先点选下方方块，再点击棋盘放下。放置前显示预览，绿色可放、红色不可放。方块不旋转，三组用完后重新发牌，无处可放时结算。

## 微信测试

在微信开发者工具中新建或导入独立项目，目录选本目录下的 `wechat`，类型选小游戏。AppID 默认使用现有测试 AppID `wxc19585dea4453b6b`。不要覆盖或上传替换另一个游戏的工程；此目录只是独立的本地测试包。

重新导出：`powershell -ExecutionPolicy Bypass -File export.ps1`。导出依赖本工作区已编译的 Godot；迁移后需要调整脚本中的引擎路径。

## 验证与范围

`tests/verify.gd` 覆盖逻辑与 Viewport 触摸事件，包括交叉行列消除、计分、非法落点、撤销、存档恢复、死局、20 组固定种子模拟游戏、点选放置、拖放及三种屏幕尺寸布局。

本轮没有操作桌面，也没有完成微信模拟器或手机实测。请重点检查拖动落点预览、切换设备比例、退出后续局、无空间结算与新游戏确认。

界面已中文化，内置 Noto Serif SC 中文字体子集（SIL OFL，许可证见 assets/fonts/OFL.txt）。落子、消除、连消和无效落点使用本地合成音效；当前游戏配音采用用户确认的 B3 本地参考合成声线。20 句当前台词见 assets/audio/voices.json。单线、多线、连消和游戏结束分别使用台词池，随机轮换、不连续重复；语音播放中不打断，普通反馈至少间隔 2.8 秒，结算反馈优先。右上角声音开关会保存偏好。

消除时有方块闪光、光带、彩色粒子、得分浮字和连消提示。所有动效仅改变表现，不影响计分或落子规则。此版本没有广告、支付和联网排行榜；沿用已有 Godot 微信导出插件，游戏、插件和引擎许可证分别保留。

## 隔离

本项目仅写入 `outputs/block-clear` 与 `work/block-clear-runtime`。未修改箭头出逃、共享 GitHub 仓库、Godot 引擎源码、MCP 配置或其他游戏工程。

## 本地生成配音

生成脚本：`tools/generate_approved_b3.py`；本地模型与依赖位于 `work/block-clear-runtime/local-tts`。使用 Qwen3-TTS-12Hz-0.6B-Base，随机种子 808，参考采样率系数 1.035，温度 0.6。生成后的声音不做升调、混响或叠音处理。用户已确认 B3 并授权批量替换；local-mature、B1、B2 均不采用。模型离线推理，模型权重和试听文件不会打包到微信。

模型与工具来源：https://github.com/QwenLM/Qwen3-TTS ，许可证 Apache-2.0 保留在 `assets/audio/QWEN_LICENSE.txt`。公开平台试听样本仅用于选型，不作为游戏发布音频。


## Repository export

From the repository root, run `powershell -ExecutionPolicy Bypass -File scripts/export-wechat.ps1 -GodotPath C:\path\to\godot.exe -AppId YOUR_APP_ID -Game block-clear`. Import `exports/wechat-block-clear` in WeChat DevTools. Original workspace paths above describe the development environment; use this command after cloning.

Voice inference weights, reference recordings and audition files are excluded. Approved final game audio and its license are included. The optional voice generation script requires the original local model/reference setup.
