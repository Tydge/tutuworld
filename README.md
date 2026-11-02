# 兔兔的世界

Godot 4.6.3 的3D生活模拟游戏：海岛城与眠风山谷，三种角色，种植、采集、烹饪、制造、换装和昼夜NPC。当前正式版 **0.3.3** 支持单人及长期运行的多人公共世界。

[Windows x64下载](https://47.119.37.251/tutuworld/releases/0.3.3/TutuWorld-Windows.zip) · [Mac通用版下载](https://47.119.37.251/tutuworld/releases/0.3.3/TutuWorld-macOS.zip)。解压后运行，新安装默认全屏、60 FPS上限、均衡画质；Mac包为临时签名，尚未公证。

0.3.3新增耳根立体蝴蝶结、菜园水井和有限水量、厨房东侧铜叶工坊及制造技能。安装版可自动更新；覆盖与限制见[验证基线](docs/验证基线.md)。

## 开发入口

| 资料 | 用途 |
| --- | --- |
| [开发接手指南](docs/开发接手指南.md) | 架构、存档、改动边界、验证方法与已知限制 |
| [策划数值与机制](docs/策划数值与机制/README.md) | 8份可直接编辑的MD；修改后交开发核对实现 |
| [服务器运维](docs/服务器运维.md) | 服务、数据、备份与分阶段发布 |
| [验证基线](docs/验证基线.md) | 当前覆盖、历史证据与未验证范围 |
| [整理清单](docs/整理清单.md) | 文件清理与恢复方式 |

用Godot打开`project.godot`，完成首次导入后F5；无需额外建模插件。Python 3.9+仅用于开发工具，在项目根目录运行：

```sh
python3 tools/dev.py doctor
python3 tools/dev.py test --suite smoke
python3 tools/dev.py run
```

引擎可通过`GODOT_BIN`环境变量或`python3 tools/dev.py --godot /path/to/Godot doctor`指定。测试产物写`.qa-artifacts/`，玩家存档、密钥和构建产物不提交Git。

## 操作

- WASD／方向键移动，Shift切换走跑，空格跳跃；右键拖动视角，滚轮缩放。
- E互动，F快捷照料选中的作物；多人回车打开聊天，再回车发送文字/emoji气泡，Esc取消。
- C角色，I／B背包，Tab换装，M地图，Esc返回/取消/设置；R发呆，F2取景，F12拍照。

源码与备份仓库：[Tydge/tutuworld](https://github.com/Tydge/tutuworld)。美术素材来源见[草坪记录](assets/terrain/ASSET_NOTES.md)。
