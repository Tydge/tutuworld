# NPC作息与对话

版本：v0.1　代码基线：2026-11-01　初始状态：已核对现状，尚未登记设计修改。

记录12位NPC的身份、初始位置、服装、活动规则和45条现有聊天台词。商人打开商店，不使用普通NPC随机聊天组。

**编辑方式：直接修改正文表格的值和机制描述，并在文末登记修改。正文是目标设计；修改文件后，游戏行为需另行开发。未修改内容沿用本次基线。** 金额单位均为贝壳币；所有时长注明现实时间或游戏时间。

## 内容目录

- 24 NPC定义
- 25 NPC作息
- 26 NPC对话

## 24 NPC定义

NPC ID保留现有场景名；作息组和对话组是本次文档整理标识。初始位置是生成点，不是漫步时固定位置；商人位置引用设施挂点。

| NPC ID | 名字 | 物种 | 地图 | 初始位置 X Y Z | 基础服装 | 作息组 | 对话组或功能 | 互动半径 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Merchant_farm | 春芽 | bunny | city | (-18, 0.18, -28.719999) | head=beret_sage; body=apron_sage | merchant_always | 打开商店farm | 3.3 |
| Merchant_tools | 木木 | bunny | city | (-5, 0.18, -28.719999) | head=beret_plaid_honey; body=vest_sage | merchant_always | 打开商店tools | 3.3 |
| Merchant_clothes | 云朵 | bunny | city | (8, 0.18, -28.719999) | head=bow_rose; body=vest_rose | merchant_always | 打开商店clothes | 3.3 |
| Passerby0 | 棉棉 | bunny | city | (-16, 0.1, -16) | head=bow_sage; body=vest_sage | city_wander | dialogue_Passerby0 | 2.6 |
| Passerby1 | 小葵 | bunny | city | (-8, 0.1, 16) | head=beret_honey; body=overalls_rose | city_wander | dialogue_Passerby1 | 2.6 |
| Passerby2 | 阿圆 | bunny | city | (0, 0.1, -16) | head=beret_sage; body=vest_honey | city_wander | dialogue_Passerby2 | 2.6 |
| Passerby3 | 团子 | bunny | city | (8, 0.1, 16) | head=bow_honey; body=overalls_honey | city_wander | dialogue_Passerby3 | 2.6 |
| CatTeacher | 猫咪老师 | cat_teacher | city | (-10, 0.1, 17.7) | neck=bell_red | city_wander | dialogue_CatTeacher | 3 |
| Youmu | 又木 | panda | city | (16, 0.1, 19.5) | head=beret_plaid_sage; neck=scarf_red | city_wander | dialogue_Youmu | 3 |
| Panda | 潘达 | panda | valley | (12, 4.2, -29.5) | 头/身体/脖子各随机1件 | panda_day_night | dialogue_Panda | 2.8 |
| ValleyVisitor0 | 叶芽 | bunny | valley | (-18, 0.1, 20) | 头/身体/脖子各随机1件 | visitor_day_night | dialogue_ValleyVisitor0 | 2.8 |
| ValleyVisitor1 | 溪豆 | bunny | valley | (22, 2.1, -16) | 头/身体/脖子各随机1件 | visitor_day_night | dialogue_ValleyVisitor1 | 2.8 |

城镇三位商人和四位兔兔路人这7位中，每次生成时随机选2位，再各随机加一件现有脖子服装；猫咪老师固定bell_red。山谷3位角色每次生成时每槽随机，不能把某次截图中的穿搭当固定设计。

性格资料：

| NPC | 已有性格说明 |
| --- | --- |
| 棉棉 | 温柔慢热 |
| 小葵 | 活泼好奇 |
| 阿圆 | 认真迷糊 |
| 团子 | 悠闲吃货 |
| 又木 | 温吞爱自然 |
| 猫咪老师 | 资料未单列性格字段 |
| 潘达/叶芽/溪豆 | 资料未单列性格字段 |

### 漫步基础规则

| 参数 | 当前目标 | 解释 |
| --- | --- | --- |
| 初始默认速度 | 1.45 | 场景单位/现实秒；选择目的地后重新赋值 |
| 正常选点后的速度范围 | 1.10～1.65 × 物种walk_speed_scale | 兔1、猫0.85、熊猫0.93；影响NPC漫步 |
| 四位兔兔初始化速度范围 | 1.15～1.70 | 初始化用固定随机种子23093；首次选点后按上行规则 |
| 猫咪老师初始化速度 | 0.9 | 首次选点后也会按共用规则重设 |
| 到达目的地停留概率 | 50% | 停留0.5～3.5现实秒，否则立即选点 |
| 目的地最小距离 | 3 | 场景单位 |
| 近期目的地区域避重 | 4 | 保留最近4个区域/索引 |
| 目标路径点判定距离 | 0.32 | 场景单位 |
| 聊天移动 | 停止并转向玩家 | 玩家离开4.0三维距离结束聊天 |
| 潘达夜间回床速度 | 1.6 | 场景单位/现实秒 |
| 潘达到床退出点入睡距离 | 1 | 场景单位 |

卡墙退让、无进展重规划和导航障碍处理沿用共用程序；不能为NPC分别复制一套运动实现。当前无好感、任务、赠礼、职业生产或商人离店规则。

来源：[city_world.gd](/Users/wangtaizhi/兔兔的世界/scripts/city/city_world.gd)、[valley_world.gd](/Users/wangtaizhi/兔兔的世界/scripts/valley/valley_world.gd)、[npc_driver.gd](/Users/wangtaizhi/兔兔的世界/scripts/city/npc_driver.gd)、[npc_profiles.gd](/Users/wangtaizhi/兔兔的世界/scripts/city/npc_profiles.gd)、[cat_teacher.tres](/Users/wangtaizhi/兔兔的世界/config/animals/cat_teacher.tres)、[panda.tres](/Users/wangtaizhi/兔兔的世界/config/animals/panda.tres)。

## 25 NPC作息

所有时分均是世界时钟。时间段左闭右开；跨日段单独注明。渐变时间是现实秒。

| 作息组 | 开始 | 结束 | 跨日 | 目标状态 | 互动 | 渐变现实秒 |
| --- | --- | --- | --- | --- | --- | --- |
| merchant_always | 00:00 | 次日00:00 | 是 | 固定店内，不执行漫步 | 打开商店 | 0 |
| city_wander | 00:00 | 次日00:00 | 是 | 正常漫步 | 可聊天 | 0 |
| panda_day_night | 06:00 | 20:00 | 否 | 醒来漫步 | 可聊天 | 0 |
| panda_day_night | 20:00 | 次日06:00 | 是 | 回床并睡觉 | 回床途中按普通状态；熟睡不唤醒 | 0 |
| visitor_day_night | 06:00 | 22:00 | 否 | 渐现后漫步 | 完全显示才可聊天 | 1 |
| visitor_day_night | 22:00 | 次日06:00 | 是 | 渐隐后隐藏 | 转出时立即禁止聊天 | 1 |

潘达使用`ValleyHome/Furnishing/bed`及其`SleepExit`。到夜间先走回床，靠近退出点才入睡；若地图首次初始化就在夜间则直接安排入睡。熟睡点击仅提示睡得正香，不会唤醒。06:00起床到退出点，稍等0.5现实秒后恢复选点；不能和访客一样在夜间隐藏。

访客22:00开始退出时立即终止聊天、停止移动、取消目标与碰撞，然后1现实秒渐隐；完全隐藏后不运行角色动作。06:00渐现完成后恢复碰撞、动作与互动。距离玩家65场景单位外还有显示剔除，这是表现规则，不改变06:00～22:00作息。

来源：[panda_routine.gd](/Users/wangtaizhi/兔兔的世界/scripts/valley/panda_routine.gd)、[visitor_routine.gd](/Users/wangtaizhi/兔兔的世界/scripts/valley/visitor_routine.gd)、[npc_driver.gd](/Users/wangtaizhi/兔兔的世界/scripts/city/npc_driver.gd)。

## 26 NPC对话

每条台词ID为本次整理标识，现有程序按profile索引选台词。默认从该角色5句中随机选择，排除刚说过的一句；对话文字中的`<br>`表示换行。改台词无需编写任务条件。

### 棉棉

| 整理台词ID | 对话组 | 文本目标 |
| --- | --- | --- |
| Passerby0_01 | dialogue_Passerby0 | 早呀……或者，该说下午好？<br>能在这里碰见你，真好。 |
| Passerby0_02 | dialogue_Passerby0 | 我刚刚给小苗浇过水了。<br>它没说谢谢，不过叶子精神了一点。 |
| Passerby0_03 | dialogue_Passerby0 | 如果今天有点累，就坐一会儿吧。<br>我可以陪你听风，不用说话也没关系。 |
| Passerby0_04 | dialogue_Passerby0 | 海边的贝壳，我总会留一半在原地。<br>也许下一只兔兔看见了，会很开心。 |
| Passerby0_05 | dialogue_Passerby0 | 我不太会挑礼物……<br>但如果你喜欢，我可以送你一场日落。 |

### 小葵

| 整理台词ID | 对话组 | 文本目标 |
| --- | --- | --- |
| Passerby1_01 | dialogue_Passerby1 | 你来得正好！我发现了一个秘密——<br>沿着海边走一圈，居然会回到原地！ |
| Passerby1_02 | dialogue_Passerby1 | 今天想种哪一种菜呀？<br>我想种南瓜！长大以后能不能当小椅子？ |
| Passerby1_03 | dialogue_Passerby1 | 快看我的新帽子！<br>戴上以后，感觉连散步都有新路线了！ |
| Passerby1_04 | dialogue_Passerby1 | 你说，云会不会也有自己的背包？<br>不然它们把雨藏在哪里呀？ |
| Passerby1_05 | dialogue_Passerby1 | 我决定了，今天要认识一位新朋友！<br>咦，我们已经认识了？那就再认识一次！ |

### 阿圆

| 整理台词ID | 对话组 | 文本目标 |
| --- | --- | --- |
| Passerby2_01 | dialogue_Passerby2 | 我正在调查这条路为什么这么长。<br>目前的结论是：我还没有走到头。 |
| Passerby2_02 | dialogue_Passerby2 | 按照计划，我应该向北走。<br>等一下……哪边是我刚才说的北？ |
| Passerby2_03 | dialogue_Passerby2 | 石灰石和铜矿要用不同的工具。<br>这个我记得很清楚。工具放哪了就…… |
| Passerby2_04 | dialogue_Passerby2 | 我给每一朵云都起了编号。<br>可惜刚编到第三朵，它们就换了位置。 |
| Passerby2_05 | dialogue_Passerby2 | 今天的待办事项已经写好了。<br>第一项：找到写着待办事项的那张纸。 |

### 团子

| 整理台词ID | 对话组 | 文本目标 |
| --- | --- | --- |
| Passerby3_01 | dialogue_Passerby3 | 唔……海风里有面包的味道。<br>我本来想散步，现在想顺路吃一点。 |
| Passerby3_02 | dialogue_Passerby3 | 番茄、胡萝卜、生菜、南瓜……<br>这不是种植计划，是我的晚餐计划。 |
| Passerby3_03 | dialogue_Passerby3 | 别着急，太阳还没下山呢。<br>就算下山了，我们也可以慢慢吃。 |
| Passerby3_04 | dialogue_Passerby3 | 我刚才在长椅上认真想了一件事。<br>午睡之前吃点心，还是醒来再吃？ |
| Passerby3_05 | dialogue_Passerby3 | 有人说，走路能让肚子饿得快一点。<br>所以你看，我一直都很努力。 |

### 猫咪老师

| 整理台词ID | 对话组 | 文本目标 |
| --- | --- | --- |
| CatTeacher_01 | dialogue_CatTeacher | 哼，吾辈只是在巡视小岛。<br>才不是闻着点心的味道过来的。 |
| CatTeacher_02 | dialogue_CatTeacher | 那边的阳光不错。<br>等我睡醒，再告诉你散步的诀窍。 |
| CatTeacher_03 | dialogue_CatTeacher | 种菜记得浇水。等收成好了……<br>给吾辈留一份，也不是不可以。 |
| CatTeacher_04 | dialogue_CatTeacher | 别被吾辈这副样子骗了。<br>遇到麻烦就来找我，知道了吗？ |
| CatTeacher_05 | dialogue_CatTeacher | 海风、长椅，还有慢吞吞的小兔子。<br>嗯，这里倒是个适合久住的地方。 |

### 又木

| 整理台词ID | 对话组 | 文本目标 |
| --- | --- | --- |
| Youmu_01 | dialogue_Youmu | 刚才路过菜园，看见一片新叶子。<br>它长得不着急，我也就慢慢走。 |
| Youmu_02 | dialogue_Youmu | 你觉得这顶帽子像不像一片叶子？<br>我试过戴真的叶子……海风把它借走了。 |
| Youmu_03 | dialogue_Youmu | 想去海边坐一小会儿。<br>如果捡到漂亮的贝壳，分你一颗。 |
| Youmu_04 | dialogue_Youmu | 围巾暖暖的，路也还很长。<br>今天换条没走过的小路吧。 |
| Youmu_05 | dialogue_Youmu | 我叫又木。又见面的又，树木的木。<br>下次见面，希望刚好有阳光。 |

### 潘达

| 整理台词ID | 对话组 | 文本目标 |
| --- | --- | --- |
| Panda_01 | dialogue_Panda | 欢迎来到眠风山谷。<br>桥那边的风，会带一点橘子的香气。 |
| Panda_02 | dialogue_Panda | 桦树倒下来以后，还能陪我们很久。<br>记得带铜斧，慢慢砍，不要着急。 |
| Panda_03 | dialogue_Panda | 我最喜欢踩着石阶去散步。<br>上坡的时候，云好像也近了一点。 |
| Panda_04 | dialogue_Panda | 睡前听溪水流过，我就不数羊啦。<br>数到第三块石头，眼睛就睁不开了。 |
| Panda_05 | dialogue_Panda | 今天摘的橘子，有一颗特别甜。<br>也许明天轮到你找到它。 |

### 叶芽

| 整理台词ID | 对话组 | 文本目标 |
| --- | --- | --- |
| ValleyVisitor0_01 | dialogue_ValleyVisitor0 | 嘘，你听。溪水在石头旁边拐了一个弯。<br>我想在这里多听一小会儿。 |
| ValleyVisitor0_02 | dialogue_ValleyVisitor0 | 早上顺着石阶走，叶子上还有露水。<br>你也想去高处看看吗？ |
| ValleyVisitor0_03 | dialogue_ValleyVisitor0 | 我给这片树林起了好多名字。<br>可是每次风来，它们又有点不一样了。 |
| ValleyVisitor0_04 | dialogue_ValleyVisitor0 | 这顶帽子装不下整片森林。<br>不过能装下一片小叶子。 |
| ValleyVisitor0_05 | dialogue_ValleyVisitor0 | 天黑以后，我就回去休息啦。<br>明天太阳出来，再一起散步吧。 |

### 溪豆

| 整理台词ID | 对话组 | 文本目标 |
| --- | --- | --- |
| ValleyVisitor1_01 | dialogue_ValleyVisitor1 | 桥那边的橘子好像更甜！<br>也可能是我走过去的时候饿了。 |
| ValleyVisitor1_02 | dialogue_ValleyVisitor1 | 今天要走哪条小路？<br>我抛了片叶子……它还没落下来。 |
| ValleyVisitor1_03 | dialogue_ValleyVisitor1 | 我发现了五根树枝。<br>数完以后，忘了第一根在哪里。 |
| ValleyVisitor1_04 | dialogue_ValleyVisitor1 | 如果石阶变成饼干，<br>上山这件事可能会慢一点。 |
| ValleyVisitor1_05 | dialogue_ValleyVisitor1 | 到晚上十点，我就要回去啦。<br>溪水还在，我们明天再见。 |

共9个聊天组、45句现有台词。商人使用商店面板，当前无独立商人聊天组。若在台词中调整开放时间、工具需求或奖励承诺，应同时改相应机制文档，避免文字与游戏规则冲突。

来源：[npc_profiles.gd](/Users/wangtaizhi/兔兔的世界/scripts/city/npc_profiles.gd)、[city_world.gd](/Users/wangtaizhi/兔兔的世界/scripts/city/city_world.gd)。

## 设计修改记录

当前没有新增修改。修改正文后可在下表增加一行；机制改动请说明触发条件、过程、完成和取消结果。

| 修改日期 | 条目或ID | 原规则或原值 | 目标规则或目标值 | 原因与验收预期 | 实现状态 |
| --- | --- | --- | --- | --- | --- |
| 待填写 | 待填写 | 待填写 | 待填写 | 待填写 | 待核对 |

状态可写：待核对、待补充、待开发、开发中、已实现待验证、已验证。是否已实现以代码和验证结果为准。
