# 玉京美术来源

建筑、园林、树、服装、工具和场景均在 Godot 中建模和烘焙。四张玩家参考图用于观察街道比例、建筑层次和灯色。下列原创纹理通过 ImageGen 生成，图集按象限裁成运行时材质。远山保留透明天际线，枝叶图集使用透明裁切。

各栋的院坪、檐脚背光和衔接的巷道随地图离线绘进一张 1024 方图。筒瓦、瓦当和滴水使用烘焙网格，近看有弧面和阴影。街屋墙面和檐柱的顶端背光与石阶反光烘进顶点颜色，远景网格保留同一组颜色。街边树和玩家栽种的玉京树共用相机避挡，遮挡范围取实时相机到角色的线段，树影保持完整。柳、梅、银杏和香樟各有树皮颜色，基部有露根，侧枝从不同高度弯出。庭院松和街树按地形落点定位。近景石板以石缝和磨亮的表面还原浅浮雕光照，沿用已采样的纹理。河岸用同一砌石纹理沿潮线纵向铺开，搭配成段的压顶石、石雕与系船环。西南农田和城外河段保留自然土岸。烘焙时从河面沿玉带河两岸分别正射取景，六段拼合成一张带透明天际线的 1920 × 320 图集。运行时河水按视线方向、涟漪和日色采样相应岸线。[烘焙脚本](../../scripts/jade/river_reflection.gd)

## polychrome / swallows / egret / brocade

原图编号 `exec-6b2c73f9-405a-4914-840c-5307e97d04b9.png`。生成提示如下。

> Production-ready square texture atlas for a handmade storybook 3D game set in a classical Chinese imperial capital. Exactly two columns and two rows of equal sized square, edge-to-edge material tiles, no gutter or borders between tiles. Top left: a rich dark teal and cinnabar painted palace timber crossbeam, with symmetrical gold and jade lotus-and-cloud scrollwork, hand-painted mineral pigments, design spread horizontally. Top right: a hand woven indigo ramie cloth with elegant repeating cream swallow and wave embroidery, restrained small-scale design. Bottom left: cream silk painted screen panel of a long-tailed white egret amid fine reeds, blue-green water, delicate antique gongbi brushwork, branching plum blossoms. Bottom right: repeating oxblood silk brocade, subtle golden interlocking lozenges and auspicious flower medallions. Entire image is flat diffuse color, seen orthographically, evenly lit, no perspective, no cast shadows, no writing, no characters, no mockup, no diagram. Strong readable mid-distance silhouettes, fine brushwork up close.

## masonry / lime

原图编号 `exec-f76a1ef4-6e52-467c-a27e-16e1f7202949.png`。生成提示如下。

> Create a production hand-painted PBR albedo atlas for a sophisticated stylized 3D ancient Chinese city game. Square 2x2 texture atlas, EXACT equal quadrants, each quadrant a separate seamless repeatable flat material. Top left: deep red lacquered Chinese hardwood painted over close horizontal timber grain with fine wear along grain, subtle age, oxblood and cinnabar. Top right: warm ivory lime plaster with tiny ochre trowel marks and mineral variation, no large cracks. Bottom left: dark peacock teal glazed Chinese barrel roof tiles seen STRAIGHT DOWN orthographically, arranged in about eight parallel vertical channels and ten overlapping scalloped rows, individually painted teal, muted petrol blue and jade with aged umber recesses and subtle highlights, rich illustrated texture comparable to a polished console RPG. Bottom right: weathered blue-grey small rectangular chiseled granite masonry blocks, offset horizontal courses, moss in a few narrow joints, varied individual stone hues. Fills every pixel, four perfectly aligned separate quadrants. Painterly restrained fine brushwork. No perspective, lighting directions, hard cast shadows, pictures of buildings, labels, letters, borders or margins.

## mountain_range

原图编号 `exec-0f64e9b9-dbc9-469e-a185-1c882590606c.png`。生成提示如下。

> An ultra-wide continuous landscape skyline matte painting for a hand-painted 3D adventure game. Actual transparent background above the mountain silhouette, opaque land all the way to the bottom edge. Panoramic 3:1 composition. A layered mountain range of southern China with limestone cliffs, wooded rounded ridges, ancient pines, softly weathered granite faces, fern green and dark cypress forest canopy, a few golden ginkgo crowns. Strong topographic detail, terraces of rock at the crest, distinct near forested slopes and far misty blue-green ridges. A pale waterfall drops down a cliff in the right third. A few tall expressive peaks, broad low valleys in between. Charming and lush hand-painted gouache fantasy landscape matching a polished cell-shaded RPG, natural subtle lighting that can be tinted at dusk. Bottom 80 percent of image occupied by continuous woodland and mountain slopes, no blank land area. The entire skyline visible, no sky pixels above it: transparent alpha there. No town, built structures, foreground trees larger than the hills, animals, characters, text, legends, border or logos.

## leaf_sprays

原图编号 `exec-143386ee-1c9a-4636-a3bc-d352d2ea0a77.png`。生成提示如下。

> A square technical foliage texture atlas of FOUR separate lush branching botanical sprays for a high-quality stylized Chinese garden game, arranged in a precise equal 2 by 2 grid, each isolated on genuine transparent alpha with generous clear separation and no grid lines. Each spray is a naturally branching little limb, with clearly visible slim twigs and many individual leaves or blossoms, irregular perforated silhouette. All four start at lower center of their own quadrant and fan upward and outward, covering most of that quadrant but never crossing its edge. Upper left: elegant long drooping willow leaf sprays in fresh sage and rich green. Upper right: flowering plum bough with many dense clusters of shell pink five-petalled blossoms among a few dark red buds and green leaves, dark forked twig. Lower left: autumn golden ginkgo branch with distinctive overlapping fan-shaped leaves with ochre shadow and yellow tips. Lower right: rich green camphor branch, pointed oval leathery leaves with clear midribs and softer yellow-green new shoots. Hand-painted naturalistic gouache, stable diffuse illumination with softly modeled volume; realistic botanical shapes, readable silhouette. Dense full leaf groups, transparent spaces around AND between leaves. No backdrop, cast shadow, borders, labels, lettering, vignette or circles.

## casement / cloud_beam / crane_panel / stone_relief

原图编号 `exec-ee528f48-a62a-4611-ade8-b0b20c7bf8fe.png`。生成提示如下。

> Create an ORIGINAL game architectural material atlas for a small vibrant Chinese imperial city in a high-quality hand-painted stylized fantasy RPG. A square 2 by 2 equal quadrants grid, each art fully covering the quadrant edge-to-edge, all PERFECTLY FRONT-ON orthographic, architectural SURFACE TEXTURES ONLY, no perspective, no scenery, no text, no white gutters, no borders around the atlas, no people, no cast shadow. Top LEFT an authentic richly carved dark honey-toned walnut SHOPFRONT LATTICE WINDOW panel, a complex repeating open fretwork pattern with interlocking rectangles and double-happiness knots, tawny pale rice paper visible behind, delicately shaded carved bevels, sophisticated slender woodwork and interior warm/cool occlusion, visually worldly. Top RIGHT a carved teal green, muted cinnabar, ochre-gold palace decorative DOUGONG BEAM FRIEZE horizontal, multiple repeated scrolling cloud and lotus bracket motifs, precise painted undulating line-work, edges intentionally cropped horizontally for repeating. Bottom LEFT a regal deep cinnabar wooden wall PANEL embossed with two elegant stylized gold flying cranes among cloud ribbons, a classical carved/painted door leaf with intricate lacquer finish and an age-darkened gold border, luxurious yet tasteful, absolutely no writing. Bottom RIGHT ORIGINAL hand painted narrow raised relief GREY-GREEN STONE CARVED ARCHITECTURAL FRIEZE depicting Chinese rolling waves, stylized mountains and ruyi clouds cut in stone, low contrast suitable for palace stair railings and quay walls. Authentic game production asset, four separate close, ALMOST ABSTRACT orthographic surface textures with realistic wood and stone microdetail, warm shadows, restrained colors, high artistry.

## tiles / lacquer / amber_tiles / lotus_marble

新釉瓦与漆木取代早期模型上的高反差木纹和通用屋面。模型分别使用青釉、黄釉，以及莲花云纹柱础和石栏。在运行时使用各级 mipmap，釉瓦法线、石雕法线取自其原始灰度的平滑高度差。原图编号 `exec-86ac6722-72ed-4e99-a16a-4e0d24ac2df1.png`。

> Square seamless 2 by 2 material texture atlas with exactly four equal quadrants edge to edge for a beautifully art directed hand-painted Chinese architectural video game. Orthographic flat diffuse materials only, no perspective, neutral studio light. Upper left: quiet restrained warm cinnabar vermilion lacquer on old Chinese columns, very fine vertical wood fibers barely visible, expensive satin pigment rich muted red-orange, few tiny fine cracks, no prominent dark wood knots or red-black stripes. Upper right: dark teal grey glazed roof of tightly packed traditional Chinese concave and convex cylindrical ceramic tiles in 12 vertical channels, four staggered courses, modest specular accents and dark occlusion in the rounded wave channels, seen perfectly head on. Lower left: same orthographic ceramic roof tiles in twelve vertical parallel golden ochre convex channels with lapped rounded tile ends in four staggered courses; mustard amber, burnt sienna shadows and buttery ochre tops. Lower right: fine pale warm grey carved Chinese white marble balustrade relief frieze, elegant repeating sculpted cloud curls and lotus blossom, lightly weathered recesses, delicate chisel marks; no text, shadows subtle. Generous clean color areas with deliberate highlights and valleys, avoid excessive speckle or visual noise. Seamless left to right within each square, no separations or padding, no text or border.

## coffer / wood_relief / courtyard_flags / plaster

原图编号 `exec-fbcf4c87-e267-44fc-b020-445a6160944e.png`。四个分区用于廊下藻井、木雕、南市青石与店铺粉墙。

> Create a high-end ORIGINAL square material atlas for a stylized classical Chinese 3D town game. Exactly 2 by 2 equal edge-to-edge orthographic material tiles; omit borders, labels, text, glyphs, objects, lighting gradients or perspective. Top-left: a Chinese painted timber coffered ceiling, exactly four large restrained muted blue-green square recessed panels within fine sienna framing, each with one simple softly gilded lotus blossom and a few warm vermilion lines, high-end small-scale architectural paintwork, low saturation, plenty of quiet painted surface; truly a ceiling texture. Top-right: one wide continuous late-medieval Chinese timber fasciaboard with a flowing cloud scroll cut into warm walnut, traces of faded teal paint, wood surface satin, orderly artistic lines, rich dark occluded valleys against softly lit brown edges, no busy patterns. Bottom-left: a working Chinese courtyard flagstone pavement, art-directed warm grey and subtly lavender large irregular hand-cut rectangular stone slabs tightly laid in a staggered bond, six rows, rubbed pale centers, slightly darker dusty joints and a few tiny weeds; overhead neutral diffuse, significant variation, quite light and clean. Bottom-right: an outdoor wall panel of whitewash with faint warm grey at top, weathered light cream mineral plaster, faintly mottled earth-pigment stains and lightly eroded lime revealing a little hand-laid dark brick close to the bottom 15 percent; visually simple, subtle, restrained weathering on mostly calm pale warm grey stucco. No art from existing games. Organized original painterly game production material atlas, tileable, convincing restrained local roughness, large shapes, smooth medium-frequency gradients and micro marks.

民坊、铁铺、客栈与书院的柱身分别使用蜜色、烟色、茶色和青灰色木染。复用海岛原有橡木纹，纹理方向沿柱，远景使用相同木色。夜市灯笼的暖芯向朱色丝面渐变，箍边留下较冷的阴影。

城内的二十四盏局部光由十三处路灯、七处铺殿檐灯和四处跨街廊灯分用。路灯与铺灯直接使用建模时的灯芯坐标。纸窗按窗格和街面位置计算室内灯晕，近处的木窗与远处合并渲染的街屋由同一段着色代码控制。夜间，远山亮部保留偏蓝的月色，前景深岭仍能分辨。

近景每束末梢分两簇贴图枝，沿真实的小枝分开。垂柳的枝条下坠，银杏叶有扇缘缺口，梅花花瓣围绕短梗成簇。远景单枝使用一簇贴图。四种树复用原枝叶图集。

街坊悬挂的青釉壶有壶嘴、弧把与铜盖，百炼铺在双面八角匾上钉锤钳，云锦庄用穿过梭眼的布幅。三种幌子都能在建造目录里选取。固定街景在离线烘焙时把相同粗糙度的哑光纯色小件以顶点色合并。建造目录继续使用带独立染色部位的原型。生成器将合并数写进日志，便于随场景变动复核。[静态模型烘焙](../../scripts/jade/static_colours.gd)

屋檐另用 `eave_occlusion.png`，它以檐底、柱侧和墙脚的距离生成遮蔽权重，配合实时太阳阴影。其他原生几何包括宣时鼓阁、白鹤礼馆、承檩斗拱、铜鹤雕像、虬枝迎客松和乌篷摇橹船。

## 物品缩略图

`tools/render_jade_icons.gd` 从真实服装、作物、工具和家具模型拍摄 34 个图标。图集内的编号顺序保存在 `item_portraits.json`。两种纺织作物的五个生长期模型由 `tools/harvest_art/fibres.py` 生成。

宫北近山沿两个山肩抬高，留出宫殿后的鞍部。山脚从岛岸外起坡，东南岬保留水道和远峰视线。东南水岸对面的两道山脊使用世界坐标采样草皮与苔岩，随坡向混合，远处的天际线沿用原画。远景天空用 64 像素立方体记录日夜渐变，云层和星月由天空着色器按正常游戏分辨率绘制。


## 玉京坊间与宫城织绣

盘龙宝座靠背、鹤纹补子、牡丹裙门和蓝印鱼纹由 ImageGen 生成一张 2 × 2 色彩图，再按四个等分区域裁切为各 512 × 512 的 PNG。游戏复用这四份带 mipmap 的材质。人物各部位分别合并相同材质的几何，袖口保留手臂骨架的动作。远处的街屋使用离线生成的简化层级。冠瓣、襟线、袖缘、褶摆和宝座木雕的外轮廓由模型形成。物品栏取自游戏实物，重拍脚本为 `tools/render_jade_icons.gd`。

生成提示词如下。

> Square technical UV diffuse atlas, exactly FOUR edge-to-edge equal square quadrants in a 2x2 grid, each an orthographic swatch of original classical Chinese decorative art for a charming 3D game. Top left: single majestic sinuous Chinese gold dragon with whiskers, antlers, coiling among restrained ruyi clouds in shallow carved relief on deep cinnabar lacquer, for an imperial throne back. Top right: one large elegant white red-crowned crane in flight, wings extended diagonally, sparse cloud curls, woven on midnight teal silk, bordered with a narrow gold key fret, square Ming-style embroidered rank badge. Bottom left: large single pale-gold flowering peony sprig with leaves on vermilion silk, narrow wave border at bottom for a pleated horse-face skirt apron. Bottom right: restrained ivory-and-indigo resist-dyed cotton, repeat of large stylized fish among rolling waves, rendered as distinctive hand-cut Chinese stencils. Clearly legible at small scale, hand-painted illustrated game texture, broad quiet color fields mixed with intricate thread or carved detail; exactly equal quadrants with no gutters, flat even light, no scene or objects, no text.
