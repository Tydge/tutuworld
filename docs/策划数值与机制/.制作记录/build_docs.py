"""一次性生成可编辑策划文档。文档已有编辑时禁止覆盖。"""
import hashlib
import json
import re
import shutil
from pathlib import Path

ROOT = Path('/Users/wangtaizhi/兔兔的世界')
OUT = Path(__file__).resolve().parents[1]
DATA = json.loads((OUT / '.核对基线/代码数据快照.json').read_text())
CAT = DATA['catalog']
ITEMS = CAT['items']
DATE = '2026-11-01'
if list(OUT.glob('*.md')):
    raise SystemExit('已有策划文档，停止以避免覆盖手工修改。请根据基线逐项修订，不要重新生成。')

def cell(v):
    if v is None: return '无'
    if isinstance(v, bool): return '是' if v else '否'
    if isinstance(v, float): return f'{v:.6f}'.rstrip('0').rstrip('.')
    return str(v).replace('|', '\\|').replace('\n', '<br>')

def table(headers, rows):
    return '\n'.join(['| ' + ' | '.join(map(cell, headers)) + ' |', '| ' + ' | '.join(['---'] * len(headers)) + ' |'] + ['| ' + ' | '.join(map(cell, row)) + ' |' for row in rows]) + '\n'

def pos(v): return '(' + ', '.join(cell(x) for x in v) + ')'
def name(i): return ITEMS.get(i, {}).get('name', i)
def link(path): return f'[{Path(path).name}]({ROOT / path})'
def src(*paths): return '\n来源：' + '、'.join(link(p) for p in paths) + '。\n'

def start(title, overview, sections):
    return f'''# {title}

版本：v0.1　代码基线：{DATE}　初始状态：已核对现状，尚未登记设计修改。

{overview}

**编辑方式：直接修改正文表格的值和机制描述，并在文末登记修改。正文是目标设计；修改文件后，游戏行为需另行开发。未修改内容沿用本次基线。** 金额单位均为贝壳币；所有时长注明现实时间或游戏时间。

## 内容目录

''' + '\n'.join(f'- {i:02d} {title_}' for i, title_ in sections) + '\n\n'

def end():
    return '''
## 设计修改记录

当前没有新增修改。修改正文后可在下表增加一行；机制改动请说明触发条件、过程、完成和取消结果。

| 修改日期 | 条目或ID | 原规则或原值 | 目标规则或目标值 | 原因与验收预期 | 实现状态 |
| --- | --- | --- | --- | --- | --- |
| 待填写 | 待填写 | 待填写 | 待填写 | 待填写 | 待核对 |

状态可写：待核对、待补充、待开发、开发中、已实现待验证、已验证。是否已实现以代码和验证结果为准。
'''

def write(filename, text):
    (OUT / filename).write_text(text.rstrip() + '\n', encoding='utf-8')

# 01 全局与成长
s = start('全局规则与角色成长', '记录时间、耐力、初始角色、属性和技能。等级经验与角色总经验分别维护，技能目前只有成长记录，没有等级属性效果。', [(1,'全局规则'),(2,'角色初始'),(3,'初始发放'),(4,'属性定义'),(5,'技能定义'),(6,'等级曲线')])
s += '## 01 全局规则\n\n### 时间与耐力\n\n'
s += table(['整理标识','规则','目标值','单位或触发','当前机制说明'], [
('world_day','世界一天',3600,'现实秒','等于24游戏小时；1游戏小时=150现实秒'),
('world_start','新世界初始时间','08:00','世界时分','累计世界秒1200；创建后续角色沿用共享世界时间'),
('offline_world_cap','世界离线推进上限',7,'现实天','最多604800现实秒；照料门槛仍阻断成长；不等于耐力离线恢复上限'),
('stamina_base','基础耐力上限',100,'点','实际容量=max(1,floor(100×容量倍率))'),
('work_stamina','成功生产耐力',1,'点/次','开始预留；成功不再重复扣；取消或失败退回'),
('run_cost_interval','奔跑扣耐力周期',3,'现实秒/点','不足3秒的余量跨停顿和存档保留'),
('natural_recovery','自然耐力恢复周期',30,'现实秒/点','按恢复速度属性换算；移动时仍恢复'),
('sleep_recovery','睡眠恢复倍率',2,'倍','无其他加成时15现实秒恢复1点；不跳到次日'),
('stamina_integer','耐力最小计量',1,'点','存为整数点，不使用小数耐力'),
('work_concurrency','同时进行的生产或用餐任务',1,'项/角色','未完成任务不跨重启恢复，不凭存档发奖'),
('meal_duration','用餐时长',6,'现实秒','无生产耐力消耗；食物成功吃完才扣'),
('meal_effect','食物效果持续',1,'游戏天','3600世界秒；新餐替换旧餐，不叠加'),
('resource_refresh','资源刷新范围','1～2','游戏天','各节点错开；节点ID和刷新代次决定稳定伪随机值'),
('transaction_qty','一次交易数量','1～99','件','工具/服装单次仅1，且不能重复购买已拥有物品'),
('attribute_floor','属性最终倍率下限',0.2,'倍','不是负加成绝对值上限；详见04'),
])
s += '\n### 移动和交互动作\n\n'
s += table(['整理标识','规则','目标值','单位或范围','说明'],[
('walk_speed','玩家基础移动速度',2.8,'场景单位/现实秒','物种共用控制器；再乘移动速度倍率'),
('run_multiplier','奔跑速度倍率',1.7,'倍','无加成理想目标速度4.76；耐力耗尽不可继续跑'),
('jump_velocity','跳跃初速度',7,'场景单位/现实秒','着地、未做动作、未暂停时可跳'),
('gravity','重力加速度',18,'场景单位/现实秒²','玩家和NPC当前共用该数值'),
('move_accel','移动加速度',20,'场景单位/现实秒²','存在移动输入时'),
('move_decel','停止减速度',24,'场景单位/现实秒²','没有移动输入时'),
('work_move_cancel','工作移动取消距离',1,'场景单位','距工作起点超过此距离取消'),
('dialogue_end_distance','交谈结束距离',4,'三维场景距离','离开NPC超过该距离结束交谈'),
('bench_nap','坐席小憩动作',6,'现实秒','动作完成自动起身；不等同于床上睡眠'),
('daydream','原地发呆动作',2.5,'现实秒','R键；不产生生产经验'),
])
s += '\n### 恢复与存档中的开发约束\n\n下列是读取旧存档时的清洗边界，不代表在线交易或背包已经实现同名容量玩法。改动时需同时核对保存、恢复和显示。\n\n'
s += table(['规则','当前基线','说明'],[
('金币恢复范围','0～99,999,999','当前加减金币不统一按此上限截断'),
('普通物品恢复数量','1～99,999','不是已实现的单格堆叠上限；零数量移除'),
('工具/服装恢复数量',1,'唯一持有'),
('总经验及技能经验恢复范围','0～2,147,483,647','技能结算也截断到此上限'),
('属性存档加成范围','-0.8～10.0','0.15表示+15%'),
('技能设计等级范围','1～50','当前经验范围造成可达等级冲突，见06'),
('自动存档间隔', '15现实秒','另在完成动作、换装、交易等节点保存'),
])
s += '\n自然/睡眠恢复支持离线，使用现实时间；单人调整当天时分会平移Buff和资源刷新期限，不借此恢复耐力。新建角色共用菜地、节点和世界时钟；钱、背包、经验、技能、耐力与穿搭独立。\n'
s += src('scripts/services/local_authority.gd','scripts/services/session.gd','scripts/characters/animal_actor.gd','scripts/city/city_world.gd')
s += '\n## 02 角色初始\n\n'
s += table(['物种ID','显示名称','初始地图','位置 X Y Z','金币','耐力','总经验','各技能等级/经验'],[
('bunny','兔兔','city','(0, 0.1, 9)',650,100,0,'1 / 0'),
('cat_teacher','猫咪','city','(0, 0.1, 9)',650,100,0,'1 / 0'),
('panda','熊猫','city','(0, 0.1, 9)',650,100,0,'1 / 0'),
])
s += '\n名字去除首尾空白后1～12个字符，同档不重名（不区分大小写），不能含换行或控制字符。当前没有物种专属生产属性，所有属性初始加成均为0。初始头/身体/脖子槽为空，再将03中选中的一件服装发放并穿戴。地图和位置为新建角色初始值，不覆盖共享世界进度。\n'
s += src('scripts/services/local_authority.gd','scripts/services/session.gd','scripts/characters/animal_catalog.gd')
s += '\n## 03 初始发放\n\n### 固定发放\n\n'
s += table(['物品ID','名称','数量','发放时机'],[(i,name(i),q,'每个新建角色一次') for i,q in DATA['initial_state']['inventory'].items()])
s += '\n### 可选服装\n\n全部候选属于同一选择组，**合计选择1件**，并自动穿戴。不是每槽一件，也不是全部发放。\n\n'
s += table(['物品ID','名称','槽位','选中时数量'],[(i,name(i),ITEMS[i]['slot'],1) for i in DATA['starter_clothes']])
s += src('scripts/services/game_data.gd','scripts/services/session.gd')
s += '\n## 04 属性定义\n\n加成存储口径：0.15=+15%，0=无额外加成。总加成=角色基础加成+已穿装备加成+当前食物加成；最终倍率=max(0.2,1+总加成)。当前所有服装均未配置属性加成。\n\n'
effects={'stamina_capacity':'基础耐力100×倍率后向下取整，至少1','stamina_regen':'恢复计时速度乘倍率','move':'基础移动速度×倍率','water':'浇水基础秒/倍率','plant':'播种基础秒/倍率','weed':'除草基础秒/倍率','harvest':'作物收获与橘子采摘基础秒/倍率','cook':'配方基础秒/倍率','stone':'石灰石/砂石采集基础秒/倍率','mining':'铜矿/铁矿采集基础秒/倍率','wood':'树枝/桦木采集基础秒/倍率'}
s += table(['属性ID','名称','初始加成','作用'],[(r[0],r[1],0,effects[r[0]]) for r in DATA['attributes']])
s += '\n示例：浇水速度+30%时，2现实秒变为2÷1.3≈1.538现实秒。烹饪不属于食物`farm`加成；浇水单独对应`water`。\n'
s += src('scripts/services/character_stats.gd','scripts/services/local_authority.gd')
s += '\n## 05 技能定义\n\n'
s += table(['技能ID','名称','图标物品ID','初始等级','初始经验','设计上限','等级属性效果'],[(r[0],r[1],r[2],1,0,50,'无') for r in DATA['skills']])
s += '\n经验按成功生产次数发放：种植四动作和橘子→种植；料理→烹饪；矿石→采矿；石材→采石；树枝/桦木→伐木。一级工作技能经验+1，二级采集+2，与产量无关；生产总经验每次仍为+1。吃饭、交易、换装不计经验。取消、失败和重复命令不能额外加经验。\n'
s += src('scripts/services/character_stats.gd','scripts/services/local_authority.gd')
s += '\n## 06 等级曲线\n\n5种技能共用下表。当前升级公式为`ceil(100 × 1.5^(等级−1))`，溢出经验保留。下表是当前公式逐级结果；修改目标经验时可直接改逐级表，并在记录中说明是否仍保留统一公式。\n\n'
s += table(['等级','到达本级累计技能经验','升下一级所需技能经验','当前存储范围内可到达'],[(r['level'],r['total'],r['required'] if r['level']<50 else '封顶，不升级',r['total']<=2147483647) for r in DATA['levels']])
s += '\n**待决策项 G01：**设计上限50级，但总技能经验上限2,147,483,647；40级起始累计1,474,310,793，升41级需737,155,489，现有经验存储上限只能到40级。本次保留现状，未调整曲线或数值范围。后续需选择调整曲线、扩大经验范围或变更设计上限，并考虑旧角色等级迁移。\n'
s += src('scripts/services/character_stats.gd','scripts/services/local_authority.gd','scripts/services/session.gd')
write('01_全局规则与角色成长.md',s+end())

# 02 种植与采集
s=start('种植与采集机制','记录当前全部可种植作物、照料阶段、表现、采集类型和资源布点。价格统一在04文档修改，经验基础与恢复规则见01文档。',[(7,'动作规则'),(8,'作物定义'),(9,'照料阶段'),(10,'作物表现'),(11,'资源类型'),(12,'资源布点')])
s+='## 07 动作规则\n\n动作整理标识便于引用；`gather_资源`是本次文档拆分标识，程序命令仍是`gather`。所有成功生产动作均总经验+1，取消/失败不加经验。\n\n'
actions=[('plant','播种','plant',2,'plant',1,'种子1','planting',1),('water','浇水','water',2,'water',1,'木水壶永久保留','planting',1),('weed','除草','weed',2,'weed',1,'除草剂1','planting',1),('harvest','收获','harvest',2,'harvest',1,'无','planting',1)]
resource_specs=[('branch',1,'',2,3,'wood','woodcutting'),('orange',1,'',2,'3+刷新代次%3','harvest','planting'),('copper',1,'pickaxe',2,2,'mining','mining'),('limestone',1,'stone_hammer',2,2,'stone','quarrying'),('birch',2,'copper_axe',5,1,'wood','woodcutting'),('iron',2,'pickaxe',5,1,'mining','mining'),('sandstone',2,'stone_hammer',5,1,'stone','quarrying')]
for rid,tier,tool,sec,yield_,attr,skill in resource_specs:
    actions.append(('gather_'+rid,'采摘' + name(rid) if rid=='orange' else '采集'+name(rid),'gather',sec,attr,1,name(tool)+'永久保留' if tool else '徒手',skill,tier))
actions.extend([('craft','烹饪','craft','引用配方5/6/8/10','cook',1,'引用配方材料','cooking',1),('eat','用餐','eat',6,'无',0,'料理1','无',0)])
s+=table(['整理标识','动作','程序命令','基础现实秒','速度属性','预留耐力','工具或耗材','技能','技能经验'],actions)
s+='''
共用规则：

- 生产耐力在开始时预留1点，成功不重复扣，取消/失败退回，最高退到当时耐力上限。用餐不预留生产耐力，也不加总经验。
- 种子、除草剂、料理材料、食物都在成功完成后扣除；取消不消耗。木水壶、矿镐、采石锤、铜斧永久保留。
- 基础耗时除以相应速度倍率。一次只能做一项生产或用餐，任务不跨重启恢复。
- 在场景中离工作起点超过1场景单位会取消工作。烹饪、用餐完成时还会校验设施距离和材料，工具/收获等条件按现有命令实现核对。
- F快捷照料只对当前选中菜地生效；优先成熟收获，其次有工具的浇水、有药剂的除草，再提示缺少的操作。它和E共用目标选择。
'''
s+=src('scripts/services/local_authority.gd','scripts/city/city_world.gd')
s+='\n## 08 作物定义\n\n下表为可种植作物的目标主表。照料组`care_common`和表现组`visual_作物ID`是文档整理标识。\n\n'
s+=table(['作物ID','名称','种子ID','收获物品ID','有效成长游戏天','单株产量','照料组','成熟后处理'],[(i,c['name'],c['seed'],i,c['days'],c['yield'],'care_common','收获清空土地') for i,c in CAT['crops'].items()])
s+='''
成长计量为累计有效成长世界秒。缺水或有杂草时暂停，补齐后继续；大时间步和离线推进不能跨过照料门槛。成熟后不会自动出售或自动再种。橘子目前是采集节点产物，不能播种。

当前无季节限制、天气加成、肥料、枯死、品质、病虫害、授粉、复收次数或耐久等规则。若要新增，可以在本节写清目标机制，不应把“未实现”简单改成数字后当作已经支持。
'''
s+=src('data/catalog.json','scripts/services/local_authority.gd')
s+='\n## 09 照料阶段\n\n4种作物共享`care_common`。阶段名称是便于讨论的整理名称，不代表已有开花等植物生理机制。边界按累计有效成长进度计算；半开区间左闭右开。\n\n'
s+=table(['阶段标识','进度范围','进入时需水','进入时需除草','继续条件','完成后状态'],[
('empty','未种植',False,False,'种子充足、空地、完成播种','grow_1'),
('grow_1','0≤进度<1/3',True,False,'本阶段浇水完成','到1/3停止并进入grow_2'),
('grow_2','1/3≤进度<2/3',True,True,'本阶段浇水和除草都完成','到2/3停止并进入grow_3'),
('grow_3','2/3≤进度<1',True,True,'本阶段浇水和除草都完成','100%成熟'),
('mature','进度≥1',False,False,'完成收获动作','发产物，恢复empty'),
])
s+='\n浇水和除草可分先后完成，只要仍缺任一条件就不生长。每株从空地到收获共7次生产：播种1、浇水3、除草2、收获1。消耗种子1和除草剂2，工具不消耗。各动作基础2现实秒，累计动作时长14秒、预留耐力累计7点、总经验7、种植技能经验7。自然耐力恢复另算；14秒可能和成长时间重叠，不能直接相加当精确收获时间。\n\n'
s+=table(['作物','第1段有效现实分钟','第2段有效现实分钟','第3段有效现实分钟','总有效现实分钟'],[(c['name'],c['days']*20,c['days']*20,c['days']*20,c['days']*60) for c in CAT['crops'].values()])
s+='\n改变阶段门槛、数量或成长天数时，要说明已经种下作物如何迁移。现有`water_stage`、`weed_stage`是存档进度，不是可编辑策划值。\n'
s+=src('scripts/services/local_authority.gd','scripts/services/session.gd')
s+='\n## 10 作物表现\n\n表现进度与照料门槛分开维护。当前几何重建以`作物ID + int(进度×4) + 是否缺水 + 是否需除草`为变化签名，只有签名变化才重建；不保证严格在颜色判断阈值的瞬间换色。\n\n'
s+=table(['作物ID','收获物主色HEX','叶色HEX','变为收获色的判断','绘制样式'],[(i,c['color'],'70a95c',{'carrot':'始终使用收获色','lettuce':'叶色，无果实变色','tomato':'进度>0.6','pumpkin':'进度>0.5'}[i],i) for i,c in CAT['crops'].items()])
s+='\n共用缩放：`0.3 + 0.7 × min(1,进度)`，应用于重建时刻。当前每块土地绘制4簇作物（X=±0.38、Z=±0.33），**4簇是外观数量，不是产量**。需除草时加杂草，提示优先级为可收获→需浇水→需除草；提示文字高度1.35。叶片和果实的模型几何仍由程序样式控制。\n'
s+=src('scripts/city/crop_visual.gd','data/catalog.json')
s+='\n## 11 资源类型\n\n'
counts={m:{i:sum(r['map']==m and r['item']==i for r in DATA['resources']) for i,*_ in resource_specs} for m in ['city','valley']}
s+=table(['资源ID','名称','等级','工具ID','基础现实秒','产量规则','玩家出售单价','速度属性','技能','城镇/山谷节点'],[(i,name(i),tier,tool or '无',sec,yield_,ITEMS[i]['sell'],attr,skill,f'{counts["city"][i]} / {counts["valley"][i]}') for i,tier,tool,sec,yield_,attr,skill in resource_specs])
s+='''
出售单价是04物品表的本次参考值，正式修改入口为04；其余资源规则在本节修改。

- 资源成功采集后不可再次采集，直到累计世界时钟到达刷新期限；刷新等待1～2游戏天。
- 等待随机数的种子来自`节点ID:刷新代次`。刷新发生时`generation`加1，采完时据当前代次确定下一次刷新。
- 橘子产量为`3 + generation % 3`，初次3、下一次4、再下一次5，再循环。它不是随机3～5；橘子对应收获速度和种植经验。
- 桦木、铁矿、砂石是二级资源，耗时5秒、产量1、技能经验2；工具依旧分别是铜斧、现有矿镐、现有采石锤。
- 一次采集总经验1、预留耐力1。取消不消耗资源；工具不消耗。不同角色共享节点状态，换图不刷新。
'''
s+=src('scripts/services/game_data.gd','scripts/services/local_authority.gd','scripts/services/character_stats.gd')
s+='\n## 12 资源布点\n\n每行一个现有稳定节点，ID保留原值。位置单位为场景单位，坐标保留6位小数供复核；山谷Y来自地形采样，城镇Y为0。当前代码对城镇基础点做种子622471的±0.35扰动，山谷种子823165的±0.25扰动，下面记录的是实际结果，不再重新随机。\n\n'
s+=table(['节点ID','地图','资源ID','X','Y','Z'],[(r['id'],r['map'],r['item'],r['x'],r.get('y',0),r['z']) for r in DATA['resources']])
s+='\n共46节点：城镇19、山谷27。资源提示半径：普通资源1.95、橘子3.3；发起动作还受普通资源2.0、通用动作3.3限制，权威校验3.5，详见05交互距离。修改或删除节点ID需处理旧存档的可用状态、刷新期限和刷新代次。\n'
s+=src('scripts/services/game_data.gd','scripts/city/city_world.gd')
write('02_种植与采集机制.md',s+end())

# 03 烹饪与食物效果
s=start('烹饪与食物效果','记录4个料理配方、12条材料、4种食物效果及实际属性映射。原材料和成品价格在04维护，参考经济计算见07。',[(13,'料理配方'),(14,'配方材料'),(15,'增益定义'),(16,'增益属性明细')])
s+='## 13 料理配方\n\n'
s+=table(['配方ID','名称','设施','产物ID','每次产量','基础现实秒','速度属性','整理增益ID'],[(i,r['name'],r['station'],r['output'],1,r['seconds'],'cook','buff_'+i) for i,r in CAT['recipes'].items()])
s+='''
当前在城镇厨房烹饪，每次成功消耗14节材料并获得1份料理。开始预留耐力1，成功总经验1、烹饪技能经验1。取消/材料不足/完成时离开设施则不消耗材料，退回预留耐力。烹饪时长按`配方基础现实秒÷烹饪速度倍率`计算，与食物的用餐时长分开。

配方目前没有解锁等级、制作失败率、批量制作、额外品质或额外产出概率。动作完成后进入背包，需再到餐桌食用。
'''
s+=src('data/catalog.json','scripts/services/local_authority.gd')
s+='\n## 14 配方材料\n\n每行是一个配方的一种原料。数量在成功烹饪时统一扣，取消不消耗。\n\n'
s+=table(['配方ID','材料物品ID','材料名称','数量'],[(i,k,name(k),v) for i,r in CAT['recipes'].items() for k,v in r['ingredients'].items()])
s+=src('data/catalog.json')
s+='\n## 15 增益定义\n\n`buff_配方ID`为本次整理标识，当前代码直接把食物物品ID写进当前食物效果状态，没有独立Buff ID。\n\n'
s+=table(['整理增益ID','对应食物ID','显示名称','持续游戏天','用餐现实秒','效果组','完成规则'],[('buff_'+i,r['output'],r['name'],1,6,'同一用餐效果组','新餐替换上一餐') for i,r in CAT['recipes'].items()])
s+='''
共用生效规则：

- 用餐必须在城镇餐桌旁完成；6现实秒后扣食物1份，再开始计算1游戏天的效果期限。
- 食物只提供下表加速，不即时恢复耐力、不提供饱食度。生食作物目前不能代替料理食用。
- 一次只保留一种食物效果。新餐成功后替换上一餐；新餐取消或失败时旧餐效果保持原剩余期限。
- 食物期限依赖世界时钟，离线世界推进会消耗剩余期限；单人测试调整当天时分会平移期限以保持剩余时长。
- 用餐不扣生产耐力、不加总经验或烹饪技能经验；正常自然恢复仍照常计时。

效果说明文案目标在下表维护，修改属性数值后应同步校对文案及物品描述。
'''
s+=table(['整理增益ID','效果说明目标'],[('buff_'+i,r['effect_text']) for i,r in CAT['recipes'].items()])
s+=src('scripts/services/local_authority.gd','scripts/services/character_stats.gd','scripts/services/session.gd','data/catalog.json')
s+='\n## 16 增益属性明细\n\n百分比按小数存储：0.30=+30%。本节展开实际受影响属性，避免`mining`、`farm`聚合名造成理解遗漏。\n\n'
buff_rows=[]
for i,r in CAT['recipes'].items():
    for key,value in r['effect'].items():
        for attr in {'farm':['plant','weed','harvest'],'mining':['mining','stone']}.get(key,[key]):
            buff_rows.append(('buff_'+i,attr,value,f'+{value*100:g}%',key))
s+=table(['整理增益ID','实际属性ID','加成值','显示比例','当前食物effect键'],buff_rows)
s+='\n南瓜浓汤会加快橘子采摘，因为橘子使用`harvest`；不加快浇水、烹饪、树枝或桦木采集。番茄炖蔬菜加快两类矿石和两类石材，不加快树枝/桦木。\n\n当前食物物品和配方都保存了effect及effect_text，但实际角色计算读取食物物品的effect。后续根据本文改动时需一起核对重复字段，不能只改配方而漏改食物；这不是要求新增表驱动系统。\n'
s+=src('scripts/services/character_stats.gd','scripts/services/local_authority.gd','data/catalog.json')
write('03_烹饪与食物效果.md',s+end())

# 04 物品商店与服装
s=start('物品商店与服装','记录运行时完整51件物品、24件服装和3家商店。物品的玩家出售单价在17节编辑，商店买入单价在20节编辑，其他文档出现的价格属于关联参考。',[(17,'物品总表'),(18,'服装配置'),(19,'商店定义'),(20,'商店商品')])
s+='## 17 物品总表\n\n全部51件物品已包含代码运行时生成的服装。ID是现有目录与存档引用，原则上保留不变。`出售单价=0`表示当前不可出售，不表示可以0元买入。\n\n'
kind_names={'seed':'种子','consumable':'消耗品','tool':'工具','crop':'作物/果实','material':'材料','ingredient':'调料','food':'料理','clothing':'服装'}
s+=table(['物品ID','名称','分类','玩家出售单价','唯一持有','描述目标'],[(i,v['name'],kind_names[v['kind']],v.get('sell',0),v['kind'] in ['tool','clothing'],v.get('description','')) for i,v in ITEMS.items()])
s+='''
描述中的成熟天数、产量、效果和工具用途是现有文案，可直接修改。若文案和结构化数值产生冲突，需一并登记并在实现前核对，不用描述文字隐式覆盖主规则。

分类和持有规则：普通种子、作物、材料、调料、消耗品、料理可以累积；工具、服装唯一持有。当前没有单独的背包格数、负重、工具耐久或丢弃交易系统。恢复存档时的数量清洗上限见01，不等同于已实现的堆叠玩法。

关联关系：4种种子→02作物；4种料理→03配方及增益；7种采集产物→02资源类型；服装→下节外观；购买关系→20节。
'''
s+=src('data/catalog.json','scripts/services/game_data.gd','scripts/services/session.gd')
s+='\n## 18 服装配置\n\n以下填写当前有效外观值。未显式配置的辅色按材质默认`f7e5bc`列出；纹样尺度按纹样默认取值，格纹贝雷帽显式为9。纯色服装的纹样尺度不参与可见纹样计算。\n\n'
clothes={i:v for i,v in ITEMS.items() if v['kind']=='clothing'}
s+=table(['物品ID','槽位','样式','纹样','主色HEX','有效辅色HEX','有效纹样尺度'],[(i,v['slot'],v['style'],v['pattern'],v['color'],v.get('accent','f7e5bc'),v.get('pattern_scale',DATA['patterns'][v['pattern']]['scale'])) for i,v in clothes.items()])
s+='\n纹样字典（本节内附属说明，不额外计为业务表）：\n\n'
s+=table(['纹样ID','名称','纹理路径','默认尺度'],[(i,v['name'],v['texture'] or '无',v['scale']) for i,v in DATA['patterns'].items()])
s+='''
穿戴规则：头`head`、身体`body`、脖子`neck`各1件；同槽新穿会替换旧件但不丢失物品，重复点击已穿戴件可卸下。当前24件服装均没有额外属性加成。

服装店允许免费组合试穿，试穿与购买分离，离店不保存试穿状态。当前支持颜色、辅色、样式和纹样的资源结构，但玩家自由染色/纹样选择UI及对应持久化尚未实现。物种尺寸适配沿用`config/animals/*.tres`，不在本节用手工比例覆盖。
'''
s+=src('scripts/services/game_data.gd','scripts/city/outfit.gd','scripts/city/fabric_library.gd')
s+='\n## 19 商店定义\n\n'
s+=table(['商店ID','名称','地图','商人ID/名字','交易校验中心 X Z','可回收物品','营业时段'],[
('farm','春芽商店','city','Merchant_farm / 春芽',pos(DATA['shops']['farm']),'任意出售单价>0的物品','无昼夜关店规则'),
('tools','工具店','city','Merchant_tools / 木木',pos(DATA['shops']['tools']),'不回收','无昼夜关店规则'),
('clothes','服装店','city','Merchant_clothes / 云朵',pos(DATA['shops']['clothes']),'不回收','无昼夜关店规则'),
])
s+='\n交易校验为X/Z平面距离≤4.8；商人提示半径3.3。一次数量1～99；工具与服装要求数量1且尚未拥有。商店不采用每日限量库存、不做日刷新价格。买入需足额金币，出售需足额背包数量。重复命令ID不能重复扣费。\n'
s+=src('scripts/services/game_data.gd','scripts/services/local_authority.gd','scripts/city/city_world.gd')
s+='\n## 20 商店商品\n\n此处“买入单价”是玩家向商店支付的钱。商品价格属于本节主数据，出售价格属于17节；调整时不要只修改总览。\n\n'
offers=[(v['shop'],i,v['name'],v['price'],'一次1件且已拥有不可买' if v['kind'] in ['tool','clothing'] else '一次1～99件','常驻，无有限库存') for i,v in ITEMS.items() if 'price' in v]
s+=table(['商店ID','物品ID','名称','玩家买入单价','数量与持有要求','上架规则'],offers)
s+=f'\n共{len(offers)}条商品关系：农场店{sum(r[0]=="farm" for r in offers)}、工具店{sum(r[0]=="tools" for r in offers)}、服装店{sum(r[0]=="clothes" for r in offers)}。当前水壶80、采石锤100、矿镐140、铜斧160；价格按上表修改。\n'
s+=src('data/catalog.json','scripts/services/game_data.gd','scripts/services/local_authority.gd')
write('04_物品商店与服装.md',s+end())

# 05 地图交互
anchors={(a['map'],a['path']):a['position'] for a in DATA['scene_anchors']}
def anchor(map_id,path): return pos(anchors[(map_id,path)])
s=start('地图交互与旅行','记录两张地图、现有可交互点、48块菜地和两条船行路线。坐标使用场景单位，三维为X Y Z，二维为X Z。相同交互ID可在不同地图出现，需用地图加ID共同定位。',[(21,'地图定义'),(22,'地图交互点'),(23,'旅行路线')])
s+='## 21 地图定义\n\n'
s+=table(['地图ID','名称','入口场景','场景资源','旅行到达点 X Y Z','越界返回点 X Y Z'],[
('city','海岛城','scenes/city.tscn','scenes/city_map.tscn','(13, 0.2, 39.5)','(0, 1, 7)'),
('valley','眠风山谷','scenes/valley.tscn','scenes/valley_map.scn','(-11, 0.2, 43)','(-11, 0.3, 43)'),
])
s+='\n新建角色在城镇(0,0.1,9)，与船行到达点不同。山谷约108×106场景单位，平台基准0/2/4，五座阶梯连接；城镇玩家边界为`Vector2(x,z/0.88).length()<52`，山谷通行、地形/河岸/码头由现有布局资源决定。碰撞、坡道、河道与导航须与几何同步，不能只改本页坐标就视作关卡已经修改。\n\n'
s+=table(['行为','城镇city','山谷valley'],[
('种植四动作','开放，48块菜地','未开放'),('资源采集','开放，19节点','开放，27节点'),('购买/出售','3家商店；农场店回收','未开放'),('烹饪/用餐','厨房/餐桌','未开放'),('玩家睡床','海风小屋床','未开放；潘达床仅NPC作息'),('坐席小憩','已注册座椅','已注册沙发/工作台坐席'),('服装穿脱','开放','开放'),('坐船旅行','去山谷收费10','回城免费'),
])
s+='\n两张地图属于同一共享世界；菜地、节点、世界时钟共用。不是切换角色后重新生成地图。当前多人游戏尚未开放。地图几何和房屋蓝图保持现有资源，日后改建可在本节提出设计并由开发修改对应资源。\n\n### 房屋现状参考\n\n'
houses=[json.loads(p.read_text()) for p in sorted((ROOT/'data/houses').glob('*.json'))]
s+=table(['蓝图ID','名称','原点 X Y Z','大小 X Z','网格','地板高','墙高','墙厚','屋顶起拱'],[(h['id'],h['name'],pos(h['origin']),pos(h['size']),h['grid'],h['floor_height'],h['wall_height'],h['wall_thickness'],h['roof_rise']) for h in houses])
s+='\n当前无玩家建造编辑器、扩建、多层房屋或建造费用。海风小屋门打开角度±102°，运动速度170°/现实秒，角度超过70°时解除门洞阻挡；门扇运动中不能连续切换，关门前检查角色是否占据门扇区域。门和室内剖切属于场景机制，修改需同步碰撞与导航。\n\n环境昼夜参考：蝴蝶在日光系数>0.25时显示，发光微粒在日光系数<0.35时显示；并非NPC的06:00/22:00作息。两图各8只蝴蝶，城镇12、山谷24个发光微粒，山谷带3处小范围光源。\n'
s+=src('scripts/city/city_world.gd','scripts/valley/valley_world.gd','scripts/valley/valley_layout.gd','scripts/city/seabreeze_home.gd','scripts/city/ambient_life.gd','data/houses/seabreeze_cottage.json','data/houses/mianfeng_cottage.json')
s+='\n## 22 地图交互点\n\n### 距离口径\n\n提示选择通常使用X/Z平面距离，动作发起使用三维距离，权威校验使用X/Z平面距离。这些值分别起作用；修改时要一起核对，但并不要求全部相等。\n\n'
s+=table(['类型','提示半径','场景动作发起距离','权威校验距离','说明'],[
('菜地',2.1,3.3,3.5,'种植/浇水/除草/收获'),('普通资源',1.95,'2.0，另受通用3.3限制',3.5,'资源中心；不包括橘子'),('橘子',3.3,3.3,3.5,'按资源点位置；果树外观另关联附近树'),('厨房',2.6,3.3,3.8,'提示位置与权威中心不同'),('餐桌',2.8,3.3,3.8,'提示MealAnchor，权威按设施中心'),('玩家床',2.3,'从选中目标进入睡眠',3.4,'仅城镇'),('住宅门',4.6,'从选中目标切换门','场景逻辑','门扇范围另检查'),('住宅坐席',1.65,'从选中目标入座','场景逻辑','提示使用ExitAnchor'),('公园Bench',2.4,'从选中目标入座','场景逻辑','提示使用Bench节点原点'),('商店商人',3.3,'从选中目标打开商店',4.8,'对应商店中心'),('码头小船',3.1,'从选中目标出发',3.6,'码头位置'),('城镇路人',2.6,'从选中目标聊天','场景逻辑','猫咪老师/又木为3.0'),('山谷NPC',2.8,'从选中目标聊天','场景逻辑','熟睡/出入场受作息限制'),
])
s+='\n### 非菜地设施实例\n\n下表列出现有注册交互点；“提示位置”来自场景实际挂点或码头定义，“权威中心”为经济/睡眠等命令使用的二维位置。资源和NPC实例分别在02、06维护，不重复填写位置。\n\n'
interactions=[]
for iid,typ,path,rad,authority in [
('home_bed','床','SeabreezeHome/Furnishing/bed/ActionAnchor',2.3,'(-30.7, -4.75)'),
('home_door','门','SeabreezeHome/Door/ActionAnchor',4.6,'场景逻辑'),
('home_sofa','沙发','SeabreezeHome/Furnishing/sofa/ExitAnchor',1.65,'场景逻辑'),
('home_desk','书桌坐席','SeabreezeHome/Furnishing/desk/ExitAnchor',1.65,'场景逻辑'),
('kitchen','厨房','Kitchen/PotSteam',2.6,'(21, -20)'),
('dining','餐桌','DiningTable/MealAnchor',2.8,'(27.8, -18.5)'),
('Bench','公园座椅','CentralPark/Bench',2.4,'场景逻辑'),
('Merchant_farm','商店','Shop_farm/MerchantAnchor',3.3,pos(DATA['shops']['farm'])),
('Merchant_tools','商店','Shop_tools/MerchantAnchor',3.3,pos(DATA['shops']['tools'])),
('Merchant_clothes','商店','Shop_clothes/MerchantAnchor',3.3,pos(DATA['shops']['clothes'])),
]: interactions.append(('city',iid,typ,path,anchor('city',path),rad,authority))
interactions.append(('city','boat','码头','valley_layout.dock(city)','(13, 0.1, 41.5)',3.1,'(13, 41.5)'))
for iid,path in [('home_sofa','ValleyHome/Furnishing/sofa/ExitAnchor'),('home_desk','ValleyHome/Furnishing/desk/ExitAnchor')]:
    interactions.append(('valley',iid,'坐席',path,anchor('valley',path),1.65,'场景逻辑'))
interactions.append(('valley','boat','码头','valley_layout.dock(valley)','(-5.8, 0.1, 47.2)',3.1,'(-5.8, 47.2)'))
s+=table(['地图','交互ID','类型','挂点或来源','提示位置 X Y Z','提示半径','权威中心 X Z'],interactions)
s+='\n**待核对项 W01：**厨房、餐桌、床的场景提示锚点与权威校验中心并不重合。本次分别保留，不擅自改为同一个坐标；若修改布局，需一起检查可交互范围和动作对齐位置。\n\n未注册为交互目标的装饰坐席不承诺可坐；例如其他自动命名的公园长椅和海边椅虽有SeatAnchor，当前目标登记只处理公园中名称以Bench开头的节点。\n\n### 菜地实例\n\n48块菜地，6行×8列；编号是现有存档ID，X间距2.25，Z间距2.5。提示位置Y=0，外观在Y=0.17。\n\n'
s+=table(['交互ID','地图','行号','列号','X','Y','Z'],[(p['id'],'city',i//8+1,i%8+1,p['x'],0,p['z']) for i,p in enumerate(DATA['plots'])])
s+='\n### 坐席和睡床退出点\n\n这些是姿态/退出挂点，不是额外开放的可操作设施。例如山谷床只供潘达，不因本表列出就支持玩家睡眠。\n\n'
s+=table(['地图','挂点路径','位置 X Y Z'],[(a['map'],a['path'],pos(a['position'])) for a in DATA['scene_anchors'] if a['path'].startswith(('SeabreezeHome/','ValleyHome/','DiningTable/','CentralPark/Bench/')) and a['path'].endswith(('SeatAnchor','ExitAnchor','SleepExit'))])
s+=src('scripts/city/city_world.gd','scripts/valley/valley_world.gd','scripts/services/game_data.gd','scripts/services/local_authority.gd','scripts/valley/boat_travel.gd')
s+='\n## 23 旅行路线\n\n路线整理标识用于文档定位，程序仍按当前地图和destination处理。两条方向分开填写。\n\n'
s+=table(['路线整理标识','出发地图','出发码头 X Z','到达地图','到达落点 X Y Z','费用','条件'],[
('city_to_valley','city','(13, 41.5)','valley','(-11, 0.2, 43)',10,'无工作、未休息、距离≤3.6且钱足够'),
('valley_to_city','valley','(-5.8, 47.2)','city','(13, 0.2, 39.5)',0,'无工作、未休息、距离≤3.6'),
])
s+='\n先在遮罩下加载目标场景，再提交旅程；加载失败不扣费，保存失败回滚费用和地图。当前没有固定航班、船上航行玩法或可配置航程时间，遮罩时长依赖场景加载。更改费用时需同步代码预检查、提示牌、通知和权威扣费。\n'
s+=src('scripts/valley/boat_travel.gd','scripts/valley/valley_layout.gd','scripts/services/local_authority.gd','scripts/services/session.gd')
write('05_地图交互与旅行.md',s+end())

# 06 NPC
s=start('NPC作息与对话','记录12位NPC的身份、初始位置、服装、活动规则和45条现有聊天台词。商人打开商店，不使用普通NPC随机聊天组。',[(24,'NPC定义'),(25,'NPC作息'),(26,'NPC对话')])
s+='## 24 NPC定义\n\nNPC ID保留现有场景名；作息组和对话组是本次文档整理标识。初始位置是生成点，不是漫步时固定位置；商人位置引用设施挂点。\n\n'
npc_rows=[]
for iid,n,shop,head,body in [('Merchant_farm','春芽','farm','beret_sage','apron_sage'),('Merchant_tools','木木','tools','beret_plaid_honey','vest_sage'),('Merchant_clothes','云朵','clothes','bow_rose','vest_rose')]:
    npc_rows.append((iid,n,'bunny','city',anchor('city',f'Shop_{shop}/MerchantAnchor'),f'head={head}; body={body}','merchant_always','打开商店'+shop,3.3))
for i,p in enumerate(DATA['people']):
    npc_rows.append((f'Passerby{i}',p['name'],'bunny','city',pos([-16+i*8,.1,16 if i%2 else -16]),f'head={p["head"]}; body={p["body"]}','city_wander','dialogue_Passerby'+str(i),2.6))
npc_rows.extend([
('CatTeacher','猫咪老师','cat_teacher','city','(-10, 0.1, 17.7)','neck=bell_red','city_wander','dialogue_CatTeacher',3.0),
('Youmu','又木','panda','city','(16, 0.1, 19.5)','head=beret_plaid_sage; neck=scarf_red','city_wander','dialogue_Youmu',3.0),
('Panda','潘达','panda','valley','(12, 4.2, -29.5)','头/身体/脖子各随机1件','panda_day_night','dialogue_Panda',2.8),
('ValleyVisitor0','叶芽','bunny','valley','(-18, 0.1, 20)','头/身体/脖子各随机1件','visitor_day_night','dialogue_ValleyVisitor0',2.8),
('ValleyVisitor1','溪豆','bunny','valley','(22, 2.1, -16)','头/身体/脖子各随机1件','visitor_day_night','dialogue_ValleyVisitor1',2.8),
])
s+=table(['NPC ID','名字','物种','地图','初始位置 X Y Z','基础服装','作息组','对话组或功能','互动半径'],npc_rows)
s+='\n城镇三位商人和四位兔兔路人这7位中，每次生成时随机选2位，再各随机加一件现有脖子服装；猫咪老师固定bell_red。山谷3位角色每次生成时每槽随机，不能把某次截图中的穿搭当固定设计。\n\n性格资料：\n\n'
s+=table(['NPC','已有性格说明'],[(p['name'],p['personality']) for p in DATA['people']]+[('又木',DATA['youmu']['personality']),('猫咪老师','资料未单列性格字段'),('潘达/叶芽/溪豆','资料未单列性格字段')])
s+='\n### 漫步基础规则\n\n'
s+=table(['参数','当前目标','解释'],[
('初始默认速度',1.45,'场景单位/现实秒；选择目的地后重新赋值'),
('正常选点后的速度范围','1.10～1.65 × 物种walk_speed_scale','兔1、猫0.85、熊猫0.93；影响NPC漫步'),
('四位兔兔初始化速度范围','1.15～1.70','初始化用固定随机种子23093；首次选点后按上行规则'),
('猫咪老师初始化速度',0.9,'首次选点后也会按共用规则重设'),
('到达目的地停留概率','50%','停留0.5～3.5现实秒，否则立即选点'),
('目的地最小距离',3,'场景单位'),
('近期目的地区域避重',4,'保留最近4个区域/索引'),
('目标路径点判定距离',0.32,'场景单位'),
('聊天移动','停止并转向玩家','玩家离开4.0三维距离结束聊天'),
('潘达夜间回床速度',1.6,'场景单位/现实秒'),
('潘达到床退出点入睡距离',1,'场景单位'),
])
s+='\n卡墙退让、无进展重规划和导航障碍处理沿用共用程序；不能为NPC分别复制一套运动实现。当前无好感、任务、赠礼、职业生产或商人离店规则。\n'
s+=src('scripts/city/city_world.gd','scripts/valley/valley_world.gd','scripts/city/npc_driver.gd','scripts/city/npc_profiles.gd','config/animals/cat_teacher.tres','config/animals/panda.tres')
s+='\n## 25 NPC作息\n\n所有时分均是世界时钟。时间段左闭右开；跨日段单独注明。渐变时间是现实秒。\n\n'
s+=table(['作息组','开始','结束','跨日','目标状态','互动','渐变现实秒'],[
('merchant_always','00:00','次日00:00',True,'固定店内，不执行漫步','打开商店',0),
('city_wander','00:00','次日00:00',True,'正常漫步','可聊天',0),
('panda_day_night','06:00','20:00',False,'醒来漫步','可聊天',0),
('panda_day_night','20:00','次日06:00',True,'回床并睡觉','回床途中按普通状态；熟睡不唤醒',0),
('visitor_day_night','06:00','22:00',False,'渐现后漫步','完全显示才可聊天',1),
('visitor_day_night','22:00','次日06:00',True,'渐隐后隐藏','转出时立即禁止聊天',1),
])
s+='''
潘达使用`ValleyHome/Furnishing/bed`及其`SleepExit`。到夜间先走回床，靠近退出点才入睡；若地图首次初始化就在夜间则直接安排入睡。熟睡点击仅提示睡得正香，不会唤醒。06:00起床到退出点，稍等0.5现实秒后恢复选点；不能和访客一样在夜间隐藏。

访客22:00开始退出时立即终止聊天、停止移动、取消目标与碰撞，然后1现实秒渐隐；完全隐藏后不运行角色动作。06:00渐现完成后恢复碰撞、动作与互动。距离玩家65场景单位外还有显示剔除，这是表现规则，不改变06:00～22:00作息。
'''
s+=src('scripts/valley/panda_routine.gd','scripts/valley/visitor_routine.gd','scripts/city/npc_driver.gd')
s+='\n## 26 NPC对话\n\n每条台词ID为本次整理标识，现有程序按profile索引选台词。默认从该角色5句中随机选择，排除刚说过的一句；对话文字中的`<br>`表示换行。改台词无需编写任务条件。\n\n'
dialogue_groups=[(f'Passerby{i}',p['name'],p['lines']) for i,p in enumerate(DATA['people'])]+[('CatTeacher','猫咪老师',DATA['cat']['lines']),('Youmu','又木',DATA['youmu']['lines']),('Panda','潘达',DATA['panda']['lines']),('ValleyVisitor0','叶芽',DATA['visitors'][0]),('ValleyVisitor1','溪豆',DATA['visitors'][1])]
for iid,n,lines in dialogue_groups:
    s+=f'### {n}\n\n'
    s+=table(['整理台词ID','对话组','文本目标'],[(f'{iid}_{i:02d}','dialogue_'+iid,t) for i,t in enumerate(lines,1)])+'\n'
s+='共9个聊天组、45句现有台词。商人使用商店面板，当前无独立商人聊天组。若在台词中调整开放时间、工具需求或奖励承诺，应同时改相应机制文档，避免文字与游戏规则冲突。\n'
s+=src('scripts/city/npc_profiles.gd','scripts/city/city_world.gd')
write('06_NPC作息与对话.md',s+end())

# 07 四类总览
s='''# 机制总览与经济成长对比

版本：v0.1　参考基线：2026-11-01。

本页将6份正文的重要关联数据放在一起，方便比较。这里是根据本次代码基线计算的参考结果，Markdown不会自动重算；调整主文档后，后续核对与开发时同步更新本页。发生冲突时，以对应主题文档的明确目标设计为准，并记录需要核对的差异。

这里的表为4类参考视图，不额外增加26项业务配置。价格主入口在04，作物和动作在02，料理和效果在03，成长在01。不要仅修改本页的派生收益来表达设计目标。

## 参考视图一 农作物全量总览

'''
crop_rows=[]
for i,c in CAT['crops'].items():
    seed=ITEMS[c['seed']]; product=ITEMS[i]; gross=c['yield']*product['sell']; cost=seed['price']+2*ITEMS['herbicide']['price']; net=gross-cost
    crop_rows.append((i,c['name'],c['days'],c['days']*60,c['yield'],seed['price'],seed['sell'],product['sell'],gross,cost,net,f'{net/c["days"]:.2f}'))
s+=table(['作物ID','名称','成长游戏天','有效现实分钟','产量','种子买价','种子卖价','成品卖价','销售额','种子和药剂成本','单株净收益','每游戏天净收益'],crop_rows)
s+='''
成本和时间口径：每株种子1、除草剂2；共用木水壶首次购买80，不摊入每株成本。`单株净收益=产量×出售单价−种子买价−2×除草剂买价12`。每游戏天净收益只除以有效成长天数，不计行走、操作、缺少照料造成的暂停、工具和耐力价值。

共同生产负担：播种1、浇水3、除草2、收获1，共7次；各基础2现实秒，合计动作14秒、累计预留耐力7、总经验7、种植技能经验7。不是7点净耐力消耗，因为自然恢复仍生效。14秒可能与有效成长重叠，也不能简单加上去当作精确周期。

照料进度门槛：0%需水，1/3需水和除草，2/3需水和除草，100%成熟。每段有效生长现实时间依次为胡萝卜20分钟、生菜30分钟、番茄40分钟、南瓜60分钟；及时照料前提下合计60/90/120/180分钟。

料理关联：

'''
s+=table(['作物','用途','对应配方中用量'],[(name(i),'、'.join(r['name'] for r in CAT['recipes'].values() if i in r['ingredients']),'；'.join(f'{r["name"]}×{r["ingredients"][i]}' for r in CAT['recipes'].values() if i in r['ingredients'])) for i in CAT['crops']])
s+='\n## 参考视图二 采集资源总览\n\n'
s+=table(['资源','等级','基础现实秒','工具','产量','单次销售额','技能经验','城镇/山谷节点','刷新游戏天'],[(name(i),tier,sec,name(tool) if tool else '徒手',yield_,'45/60/75循环' if i=='orange' else yield_*ITEMS[i]['sell'],tier,f'{counts["city"][i]} / {counts["valley"][i]}','1～2') for i,tier,tool,sec,yield_,attr,skill in resource_specs])
s+='\n每次成功总经验1、累计预留耐力1；二级资源技能经验2。橘子3/4/5是刷新代次循环，不是随机。城镇19、山谷27，共46个资源点。刷新受累计世界时间控制，换角色或换地图不会重置。\n'
s+='\n## 参考视图三 料理与增益总览\n\n'
recipe_audit=[]
for i,r in CAT['recipes'].items():
    ingredients='、'.join(f'{name(k)}×{q}' for k,q in r['ingredients'].items())
    opportunity=sum(q*ITEMS[k].get('price',ITEMS[k]['sell']) for k,q in r['ingredients'].items())
    sale=ITEMS[r['output']]['sell']
    recipe_audit.append((r['name'],ingredients,r['seconds'],6,r['effect_text'],'1游戏天',sale,opportunity,sale-opportunity))
s+=table(['料理','原料','烹饪现实秒','用餐现实秒','效果','持续','成品卖价','原料价值','加工出售差额'],recipe_audit)
s+='''
“原料价值”将自种作物按可出售单价、海盐/橄榄油/鲜奶油按商店买入单价计价，属于机会成本口径，不是从种子起算的生产成本。当前4种料理卖价都为25，按该口径加工出售差额均为负；是否让料理主要服务增益，由策划决定。本次未调整价格。

食物效果在一餐完成后替换上一餐，不叠加；不即时补充耐力。烹饪和用餐的时间分开，取消新餐不清除旧效果。

## 参考视图四 经济与成长对比

### 同类生产的基础效率

'''
s+=table(['行为','基础现实秒','每次总经验','每次技能经验','累计预留耐力','无加成单位时间技能经验'],[
('一级采集/单次种植动作',2,1,1,1,'0.5/现实秒，未计移动和刷新'),
('二级采集',5,1,2,1,'0.4/现实秒，未计移动和刷新'),
('烹饪胡萝卜汤',5,1,1,1,'0.2/现实秒，未计材料获取'),
('烹饪沙拉',6,1,1,1,'约0.1667/现实秒，未计材料获取'),
('烹饪炖蔬菜',8,1,1,1,'0.125/现实秒，未计材料获取'),
('烹饪南瓜汤',10,1,1,1,'0.1/现实秒，未计材料获取'),
('用餐',6,0,0,0,'无生产经验'),
])
s+='\n以上只比较动作本身，不能当连续在线刷取速率。当前技能等级不带速度加成。所有技能初始Lv.1、首级100经验，后续需求按1.5倍增长并向上取整。\n\n### 初始经济与常见支出\n\n'
s+=table(['项目','当前基线','口径'],[
('初始金币',650,'每个新角色'),('初始种子总量',10,'胡萝卜3、生菜3、番茄2、南瓜2'),('四件工具全部购买',480,'80+100+140+160；永久持有'),('种满48格胡萝卜的种子',480,'不扣除初始赠送，不含水壶和照料药剂'),('一轮48株作物除草剂',1152,'每株2瓶，共96瓶×12'),('城镇去山谷',10,'单程；回城0'),('Lv.40累计经验',1474310793,'现有经验范围内可达到'),('Lv.41累计经验',DATA['levels'][40]['total'],'超过技能经验上限2,147,483,647'),
])
s+='''
当前比较发现与待决策项：

1. G01 等级设计上限50与经验存储上限冲突，当前可达最高40级。主入口见01。
2. E01 四类料理的出售单价相同且低于本页原料价值，是否保留增益用途优先的定位尚未做调优决定。主入口见03与04。
3. W01 厨房、餐桌、床的提示锚点与命令校验中心不同，改布局时需要联动复核。主入口见05。
4. C01 种子描述、配方效果、食物效果和提示文案存在重复数据，按文档实现时需要同步修改。不是必须建设自动配置系统。

本页计算根据2026-11-01代码数据快照，未新增或修改游戏规则。更改目标设计后，由核对者重新计算并记录日期。
'''
write('07_机制总览与经济成长对比.md',s)

# 使用入口与覆盖清单
file_titles=[('01_全局规则与角色成长.md','全局规则与角色成长','01～06','时间、耐力、初始角色/发放、属性、技能、50级曲线'),('02_种植与采集机制.md','种植与采集机制','07～12','动作、4种作物、照料/表现、7种资源、46个资源点'),('03_烹饪与食物效果.md','烹饪与食物效果','13～16','4个配方、12条材料、4种增益及7条属性明细'),('04_物品商店与服装.md','物品商店与服装','17～20','51件物品、24件服装、3家商店、36条商品'),('05_地图交互与旅行.md','地图交互与旅行','21～23','2张地图、48块菜地、设施距离与坐标、2条旅行路线'),('06_NPC作息与对话.md','NPC作息与对话','24～26','12位NPC、作息、9组45句台词'),('07_机制总览与经济成长对比.md','机制总览与经济成长对比','4类参考视图','农作物、资源、料理、经济成长对比')]
readme='''# 策划数值与机制文档使用说明

本目录提供可直接修改的Markdown策划文档，供策划调整设计后，由后续核对者审查并开发实现。当前初稿填入2026-11-01项目已有数值和机制，修改文档不会直接改变游戏。

本套交付为**6份主题正文，覆盖原规划的26项业务表**；另有1份4类参考总览和本使用说明，共8份MD。没有Excel、自动导入、热更新或实时生效要求。原《配置表拆分建议》仅为历史结构说明；后续目标设计集中在本目录维护。

## 从这里开始

'''
readme+=table(['文档','覆盖编号','内容'],[(f'[{title}]({OUT / f})',ids,scope) for f,title,ids,scope in file_titles])
readme+='''
建议先看07总览，再到对应主题正文修改。最常用的价格入口为04的17节和20节；作物成长、产量和照料阶段在02的08～10节。

## 怎样修改

1. 直接修改相应正文表格的数字、范围、触发条件或说明；初稿中的数值就是当前基线，不需要另填配置语法。
2. 在该文档末尾的“设计修改记录”添加一行，说明条目ID、原值、目标值和预期。若只改正文也能核对，记录能减少对意图的猜测。
3. 新机制请同时写清什么时候触发、需要什么条件、如何进行、成功得到什么、取消或失败怎么处理。新增行用“新增”标记；删除现有ID最好先注明“拟移除”，便于处理旧存档。
4. 将实现状态留为“待核对”。后续核对者比较初稿和当前代码，检查关联影响，再实现和验证；完成后更新状态。文档写成新值不代表代码已实现。

例如：把胡萝卜有效成长1游戏天改为0.8天，在02的08节直接改为0.8，并在记录中说明照料门槛是否仍为0%、1/3、2/3、已有作物如何生效。核对者再更新参考时长、收益和相关种子说明。

目标值与代码基线可以不同。现有《开发接手指南》及源代码描述当前实现；本目录被修改后的正文表达目标设计。两者有差异时，要报告差异并按需求开发，不能自行把修改恢复成旧值。

## 单位和标识

- 现实秒/分钟：操作等待、移动、耐力消耗/恢复、渐变。游戏天/世界时分：昼夜、生长、资源刷新、食物持续。当前1游戏天=3600现实秒。
- 金额为贝壳币；0出售单价表示不可出售；“无”表示不适用，“未实现”表示没有现成机制。
- 加成0.15表示+15%；工作耗时按基础秒数除以倍率。不是直接减少同百分比耗时。
- 物品、作物、资源节点、角色物种和NPC ID来自当前实现，保留这些ID有助于兼容旧存档。
- `care_common`、`grow_1`、`buff_配方ID`、`dialogue_角色ID`、路线名等标有“整理标识”的名字仅用于本文讨论，不代表已有运行时配置或新增存档字段。
- 交互点用地图ID加交互ID定位，同名home_sofa等可以在两张地图存在。普通物品数量恢复上限不等于已实现的堆叠玩法。

## 同一数据在哪里改

'''
readme+=table(['要修改什么','主要编辑位置','核对时联动'],[
('一天长度/耐力恢复','01的01节','成长、刷新、Buff、NPC作息、显示和恢复常量'),
('初始金币/赠送','01的02～03节','新建角色规则和旧角色是否补发'),
('技能经验/曲线','01的05～06节及02动作奖励','经验上限、旧角色累计经验/等级、显示'),
('动作时长/耐力/经验','02的07节','料理特有时长、属性倍率、取消/失败退款'),
('作物成长/产量/阶段','02的08～10节','种子说明、已有作物迁移、07收益'),
('资源采集/刷新/位置','02的11～12节','工具、产量策略、旧节点ID、表现与碰撞'),
('配方/材料/效果','03的13～16节','物品描述及重复effect字段、07原料价值'),
('出售价格/购买价格','04的17节/20节','总览、显示和交易测试'),
('服装外观','04的18节','物种适配、预览、纹样和实际材质'),
('设施/路线/地图开放','05的21～23节','场景挂点、校验距离、费用和切图回滚'),
('NPC身份/作息/台词','06的24～26节','导航、睡姿、出入场互动、文字承诺'),
])
readme+='''
07中的收益、时长折算和机会成本属于本次参考计算。Markdown不会自动联动；调整正文后由核对者更新总览。重复出现的描述和参考价格不能悄悄互相覆盖，出现冲突时记录并澄清。

## 后续核对与开发约定

核对者先比较本目录目标正文、初稿基线和当前源代码，列出明确修改、含糊处及依赖影响。原有目标已明确的改动直接实现；只有无法合理确定的机制含义再提出必要澄清。

实现时不要求建设新的配置读取系统，可以直接调整当前目录数据、程序逻辑与场景；保持权威校验和结算边界。涉及已有角色、作物、资源ID、经验、价格或阶段时明确存档兼容与生效时机。程序完成后记录实际验证结果，不只改文档状态。

当前待决策项：G01等级上限/经验范围冲突；E01料理出售价值定位；W01设施提示位置与校验中心差异；C01重复数值文案。初稿保留现状，没有自动决定这些设计取舍。

## 基线和制作记录

`.核对基线/文档初稿/`保留本次8份MD的原始副本，`.核对基线/代码数据快照.json`保存从GameData/Stats提取的实际目录和场景锚点，`.核对基线/来源文件清单.json`记录相关源文件哈希。它们只用于比较，不是游戏运行配置。

`.制作记录/`保留一次性提取和成稿脚本。正文已有编辑后不要重新运行制作脚本覆盖文档；本次生成器也会拒绝覆盖已有MD。正常只编辑本目录顶层8份MD。

本次在`--test`模式下只读提取静态/生成目录和未入树场景挂点，未读取或改写玩家主存档、未修改游戏逻辑、未导出发布。已核对数量、引用、字段和计算；未把这次资料提取当作完整玩法回归测试。
'''
write('README.md',readme)

# 将原始稿与相关代码摘要冻结，支持后续人工修改对比。
sources=['data/catalog.json','data/houses/seabreeze_cottage.json','data/houses/mianfeng_cottage.json','scripts/services/game_data.gd','scripts/services/character_stats.gd','scripts/services/local_authority.gd','scripts/services/session.gd','scripts/characters/animal_catalog.gd','scripts/characters/animal_actor.gd','scripts/city/city_world.gd','scripts/city/crop_visual.gd','scripts/city/npc_profiles.gd','scripts/city/npc_driver.gd','scripts/city/seabreeze_home.gd','scripts/city/fabric_library.gd','scripts/city/outfit.gd','scripts/city/ambient_life.gd','scripts/valley/valley_layout.gd','scripts/valley/valley_world.gd','scripts/valley/panda_routine.gd','scripts/valley/visitor_routine.gd','scripts/valley/boat_travel.gd','config/animals/bunny.tres','config/animals/cat_teacher.tres','config/animals/panda.tres','scenes/city_map.tscn','scenes/valley_map.scn']
manifest={'date':DATE,'source_root':str(ROOT),'files':[{'path':p,'sha256':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()} for p in sources],'counts':{'items':len(ITEMS),'clothes':len(clothes),'plots':len(DATA['plots']),'resources':len(DATA['resources']),'recipes':len(CAT['recipes']),'recipe_ingredients':sum(len(r['ingredients']) for r in CAT['recipes'].values()),'skills':len(DATA['skills']),'levels':len(DATA['levels']),'buff_modifiers':len(buff_rows),'shop_offers':len(offers),'npcs':len(npc_rows),'dialogues':sum(len(g[2]) for g in dialogue_groups)}}
(OUT/'.核对基线/来源文件清单.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
initial=OUT/'.核对基线/文档初稿'
initial.mkdir(exist_ok=True)
for path in OUT.glob('*.md'): shutil.copy2(path,initial/path.name)
print(json.dumps({'documents':len(list(OUT.glob('*.md'))),'counts':manifest['counts'],'output':str(OUT)},ensure_ascii=False))

