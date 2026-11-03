# 画面成本调研证据

这是2026-11-02在0.3.3源码上的隔离实验，不属于发布回归，也没有修改运行时画质。分析正文见[调研报告](../../画面技术调研_2026-11-02.md)。

- `summary.json`：环境、方法、汇总、限制及没有采用的数据。
- `results.json`、`run.log`：48组、7,359帧的原始分组记录。
- `render_ab.gd`：一次性实验脚本，按正序/逆序运行单变量对比。
- `sdfgi-incomplete.log`：被中止的预实验，不用于量化结论。
- `screenshots/`：保留菜园baseline/AgX和工坊夜景baseline/体积雾四张代表图；其余临时预览已清理。

在`v0.3.3`源码快照下复现当时实验，替换Godot路径；当前工作树运行同一脚本只能得到当前画面的新数据。一次只运行一个图形测试进程：

```sh
TUTU_GRAPHICS_RESEARCH_OUTPUT="$PWD/.qa-artifacts/graphics-research-repeat" \
  /path/to/Godot --path . \
  --script res://docs/evidence/graphics-research-20261102/render_ab.gd \
  -- --test --benchmark
```

脚本冻结地图节点，Session计时与着色器TIME仍运行；工坊夜景是外立面，不是室内GI测量。它会打开窗口、临时改变渲染参数并将截图写入指定目录，不重存地图或读取真实单人进度。后续引擎/系统、温度、窗口状态或资产变化都可能改变数值。正式采用前还需更长的移动镜头和真实玩法采样。
