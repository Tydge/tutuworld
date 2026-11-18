# 冰原岛素材

2026-11-18。仅本地源码新增，未发布。

- `snow_fir_boughs_v1.png`：透明冷杉积雪枝条图集，四个象限；原图像素保留。针叶使用 alpha scissor、mipmap 和空间实例，不以整片透明锥体代替。
- `powder_snow_v1.png`：粉雪扫描质感地表；原图像素保留。地表通过不同尺度采样与轻微法线变化使用。
- `distant_alpine_v1.png`：远方雪山透明图带，与离线三维山麓、海岸雾色配合；随昼夜统一着色并进入冰面反射。
- `campfire_flames_v1.png`：4×4火焰连续图集；保留原图，着色器按暖色色度与透明度抠除残留浅底，不用一团发光球替代火焰。
- 四张原创图片由内置 `image_gen` 生成，前两张精确提示词、后两张生成要点（非逐字提示词）和 SHA-256 在 [source.json](source.json)。导入单独压缩并生成 mipmap，不修改 PNG 像素。
- `alpine_relief.r16`：512×512 小端 uint16 米制高程。离线生成远山，运行游戏不联网读取地形。地形旋转、缩放并过渡到虚构岛屿，不能用于地理或导航。九张原始瓦片 URL、下载日期、来源和校验见 [alpine_relief.json](alpine_relief.json)。
- 地形来源：[Mapzen Terrain Tiles / AWS Open Data](https://registry.opendata.aws/terrain-tiles/)；署名要求按 [Tilezen 数据来源说明](https://github.com/tilezen/joerd/blob/master/docs/attribution.md)保留。Copernicus EU-DEM 和 USGS 高程致谢见 [CREDITS.txt](CREDITS.txt)，游戏冰原岛设置中同时展示。
- 3D 模块由工程自行建模，注册表在 `data/winter_objects.json`，可独立加载的场景在 `scenes/winter/`。不引用用户参考图像素，不包含参考图水印。
