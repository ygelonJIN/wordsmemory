# 设置页与学习页联动重写方案
## 仅保留“全部展示 + 设置项高亮”的最终执行说明

> 这份文档是给“另一个执行窗口”直接照着改代码用的。
>
> 你当前的真实需求只有一句话：
>
> **学习页 6 个辅助模块必须全部展示；设置页勾选的模块在学习页里蓝色高亮；未勾选的模块保持普通黑色；第一行固定显示词根词缀 / 词义 / 英文释义，第二行固定显示例句 / 近义词辨析 / 时态变形。**

---

## 一、必须先纠正的语义

### 1. 旧语义，必须废弃
旧实现里把设置项当成“显示 / 隐藏”开关：

- 勾选 = 显示
- 不勾选 = 隐藏

这就是你现在看到“没勾选的不显示”的根因。

### 2. 新语义，必须采用
设置页的勾选项现在只表示：

- 这个模块是否高亮

不是：

- 这个模块是否显示

### 3. 新语义的最终表现
学习页里：

- 6 个模块全部显示
- 设置里勾选的模块显示蓝色、加粗、带下划线
- 未勾选的模块显示普通黑色

---

## 二、你的最终 UI 目标

### 第一行固定显示
- 词根词缀
- 词义
- 英文释义

### 第二行固定显示
- 例句
- 近义词辨析
- 时态变形

### 注意
这里的“第一行 / 第二行”不是指隐藏或折叠，而是指**布局分组**。

也就是说：
- 模块始终在页面上
- 只是被分到两组 `Wrap` / `Row` 里显示
- 每组里按固定顺序排列

---

## 三、当前问题为什么会出现

### 1. 你现在虽然改了标题样式
但如果学习页里仍然保留这种结构：

```dart
if (_model.showEtymology) ...[
  ...
]
```

那就还是老逻辑。

### 2. 标题样式替换不会自动改变显隐逻辑
所以你会看到：
- 勾选的还是黑色
- 不勾选的没显示

这是因为：
- 高亮样式还没真正接上
- 更关键的是“显示 / 隐藏”逻辑还没删干净

### 3. 第一行 / 第二行没出现
因为当前渲染仍然是纵向堆叠，而不是两个分组容器。

---

# 四、逐文件执行清单

---

## 4.1 `lib/pages/random_learn_page/random_learn_page_widget.dart`

### 目标
这是本次重写的核心文件。必须同时完成三件事：

1. 删掉“按布尔值隐藏模块”的旧逻辑
2. 让 6 个模块全部展示
3. 把模块分成两组布局，并实现高亮样式

---

### 4.1.1 先删除所有 `if (_model.showXxx)` 形式的显示控制

#### 必删的代码模式
把学习页辅助模块里所有类似下面的代码删掉：

```dart
if (_model.showEtymology) ...[
  ...
]
```

```dart
if (_model.showDefinition) ...[
  ...
]
```

```dart
if (_model.showEnglishDefinition) ...[
  ...
]
```

```dart
if (_model.showExample) ...[
  ...
]
```

```dart
if (_model.showSynonym) ...[
  ...
]
```

```dart
if (_model.showTense) ...[
  ...
]
```

#### 为什么必须删
因为这些条件会直接导致“不勾选的模块不显示”。

---

### 4.1.2 改成“全部无条件展示”

#### 新写法原则
每个模块都应该直接构建，不再包 `if`：

- 词根词缀：始终显示
- 词义：始终显示
- 英文释义：始终显示
- 例句：始终显示
- 近义词辨析：始终显示
- 时态变形：始终显示

#### 你要实现的结果
不是“显示/隐藏切换”，而是“样式切换”。

---

### 4.1.3 用一个统一组件渲染模块

#### 建议新增局部组件
在 `random_learn_page_widget.dart` 文件底部，新增一个统一组件，例如：

```dart
class _AuxDisplayItem extends StatelessWidget {
  const _AuxDisplayItem({
    required this.title,
    required this.content,
    required this.highlighted,
  });

  final String title;
  final Widget content;
  final bool highlighted;
```

#### 这个组件的职责
- 接收标题
- 接收内容
- 接收是否高亮
- 统一控制字体颜色、字重、下划线、边框或浅色背景

#### 这个组件是本次重写的关键
以后每个辅助模块都统一走它。

---

### 4.1.4 设置高亮样式规则

#### 高亮态
当 `highlighted == true` 时：
- 标题颜色：蓝色 `Color(0xFF0000FF)`
- 字重：`FontWeight.w700`
- 下划线：显示
- 可选：浅蓝背景或蓝色边框

#### 普通态
当 `highlighted == false` 时：
- 标题颜色：`Colors.black87`
- 字重：`FontWeight.w500` 或 `FontWeight.w400`
- 不显示下划线
- 不显示蓝色边框

#### 重点
高亮要落在**视觉样式**上，而不是只在逻辑层有一个 bool。

---

### 4.1.5 把 6 个模块分成两组 `Wrap`

#### 第一组：
- 词根词缀
- 词义
- 英文释义

#### 第二组：
- 例句
- 近义词辨析
- 时态变形

#### 推荐代码结构

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _AuxDisplayItem(...词根词缀...),
        _AuxDisplayItem(...词义...),
        _AuxDisplayItem(...英文释义...),
      ],
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _AuxDisplayItem(...例句...),
        _AuxDisplayItem(...近义词辨析...),
        _AuxDisplayItem(...时态变形...),
      ],
    ),
  ],
)
```

#### 为什么用 `Wrap`
- 可以自然换行
- 保证第一组和第二组的视觉分区
- 不会强行挤爆小屏幕

---

### 4.1.6 每个模块怎么绑定高亮状态

#### 词根词缀
```dart
highlighted: _model.showEtymology,
```

#### 词义
```dart
highlighted: _model.showDefinition,
```

#### 英文释义
```dart
highlighted: _model.showEnglishDefinition,
```

#### 例句
```dart
highlighted: _model.showExample,
```

#### 近义词辨析
```dart
highlighted: _model.showSynonym,
```

#### 时态变形
```dart
highlighted: _model.showTense,
```

---

### 4.1.7 彻底检查旧逻辑残留
把以下逻辑全部清掉：

- 依赖 `if (_model.showXxx)` 的隐藏条件
- 任何“开关=显示/隐藏”的旧解释
- 任何只渲染半截模块的条件分支

#### 原则
学习页里只允许有：
- 显示
- 高亮 / 普通

不允许再有：
- 显示 / 隐藏 的分裂

---

## 4.2 `lib/pages/random_learn_page/random_learn_page_model.dart`

### 目标
确保 model 只负责承载高亮状态，不再作为隐藏逻辑来源。

---

### 4.2.1 `_loadData()` 必须读取完整字段

#### 必须读取
- `showEtymology`
- `showDefinition`
- `showEnglishDefinition`
- `showExample`
- `showSynonym`
- `showTense`

#### 代码要求
这几个字段要完整赋值给 model。

---

### 4.2.2 这些字段的语义要统一

#### 以前理解
- showXxx = 显示 / 隐藏

#### 现在理解
- showXxx = 是否高亮

这个语义要在文档和代码注释中统一。

---

### 4.2.3 默认值保持安全
如果设置表里某些字段缺失，默认值建议为：
- `true`

这样学习页不会突然出现未高亮的异常状态。

---

## 4.3 `lib/pages/setting_page/setting_page_model.dart`

### 目标
设置页仍然保存用户偏好，但保存的语义要与学习页高亮一致。

---

### 4.3.1 继续保留 setter
以下 setter 要保留：
- `setShowEtymology`
- `setShowDefinition`
- `setShowEnglishDefinition`
- `setShowExample`
- `setShowSynonym`
- `setShowTense`

### 4.3.2 不要恢复成“隐藏控制”语义
设置页仍然只是记录“哪个模块要高亮”，不是决定学习页显示与否。

### 4.3.3 删除 `dailyRefreshHour`
如果还有残留，继续删干净。

---

## 4.4 `lib/backend/provider.dart`

### 目标
保证设置页、学习页读取的是同一组字段。

---

### 4.4.1 `loadSettings()` 必须完整返回
确认返回对象里带有：
- `showEtymology`
- `showDefinition`
- `showEnglishDefinition`
- `showExample`
- `showSynonym`
- `showTense`

### 4.4.2 `updateSetting()` 必须能写回
确认数据库 key 对应正确，至少包括：
- `show_etymology`
- `show_definition`
- `show_english_definition`
- `show_example`
- `show_synonym`
- `show_tense`

---

## 4.5 `lib/pages/setting_page/setting_page_widget.dart`

### 目标
这个文件现在主要是布局，不再承载学习页隐藏逻辑。

---

### 4.5.1 保证不再有滚动内嵌容器
确认“单词学习数量”和“学习辅助显示”不是 `ListView`。

### 4.5.2 这些区域只负责保存勾选状态
设置页不做隐藏，不做学习页渲染控制，只管保存。

---

# 五、必须执行的替换步骤

---

## 第 1 步
修改 `random_learn_page_widget.dart`

### 动作
- 删除所有 `if (_model.showXxx)` 条件显示
- 新增 `_AuxDisplayItem`
- 用两个 `Wrap` 分组
- 给每个模块加高亮样式

### 结果
学习页 6 个模块全部显示，且可按设置高亮。

---

## 第 2 步
检查 `random_learn_page_model.dart`

### 动作
- 确认 6 个布尔字段都已读取
- 确认默认值正确

### 结果
学习页 widget 拿到的高亮状态稳定。

---

## 第 3 步
检查 `provider.dart`

### 动作
- 确认 `loadSettings()` 返回完整字段
- 确认 `updateSetting()` key 正确

### 结果
设置页和学习页数据链路一致。

---

## 第 4 步
检查 `setting_page_model.dart`

### 动作
- 确认 setter 保存的是高亮状态
- 确认没有 `dailyRefreshHour`

### 结果
设置页语义统一。

---

# 六、不要再做的事情

## 1. 不要再用 `if` 隐藏模块
这是导致“没勾选的不显示”的直接原因。

## 2. 不要只改标题样式，不改渲染逻辑
如果模块还在 `if` 里，样式根本不够。

## 3. 不要把“高亮”理解成“隐藏逻辑”
高亮是视觉状态，不是开关状态。

---

# 七、最终验收标准

## 设置页
- [ ] 单词学习数量不滚动
- [ ] 学习辅助显示不滚动
- [ ] 不再有 `ListView` 承载这些设置块

## 学习页
- [ ] 6 个模块全部显示
- [ ] 设置中勾选的模块蓝色高亮
- [ ] 未勾选的模块普通黑色
- [ ] 第一组：词根词缀 / 词义 / 英文释义
- [ ] 第二组：例句 / 近义词辨析 / 时态变形

## 数据链路
- [ ] 设置页勾选状态能同步到学习页
- [ ] 学习页高亮状态正确
- [ ] 不再有“勾选后不显示”的行为

---

# 八、最后一句话

你现在要的唯一正确结果是：

> **所有模块都在学习页显示，设置页只控制模块是否高亮，而不是控制它们是否出现。**
