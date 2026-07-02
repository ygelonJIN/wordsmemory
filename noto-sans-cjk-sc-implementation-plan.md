# Noto Sans CJK SC 全项目落地实施方案

## 目标

把项目字体统一到 `Noto Sans CJK SC`，实现以下目标：

- Android 和 iPhone 使用同一款字体
- 中文、英文、数字统一风格
- 中文字重真正生效，不再依赖系统回退字体
- 避免 `GoogleFonts` 运行时加载带来的不稳定性
- 逐步替换现有分散的字体调用，不一次性炸掉全项目

---

## 当前问题背景

你已经验证出几个关键事实：

1. 英文和数字的 `fontWeight` 是有效的
2. 中文的 `fontWeight` 无效，说明当前中文字体链路没有多字重能力
3. `Noto Sans SC` 作为 Google Fonts 里的在线字体，中文字重表现不适合当前项目的统一需求
4. 你明确希望 Android 和 iPhone 用同一款字体，而不是系统字体分平台回退

因此，最终方案应该是：

> **把 `Noto Sans CJK SC` 本地打包进项目，作为全局统一字体。**

---

## 总体实施策略

不要一次性把 226 处 `GoogleFonts` 全部手工重写。

推荐分三步推进：

1. **先把字体文件打包进项目**
2. **先在全局主题入口切换字体**
3. **再逐步清理页面里的散点字体覆盖**

这样可以先让全局字体真正生效，再慢慢收口旧代码。

---

# 第一阶段 准备字体文件

## 目标

把 `Noto Sans CJK SC` 的必要字重准备好，并放入项目资产目录。

## 推荐准备的字重

先不要贪多，第一版建议准备这些就够了：

- `Light`
- `Regular`
- `Medium`
- `SemiBold`
- `Bold`

如果你希望更细腻，也可以补：

- `ExtraLight`

但第一版建议先控制文件数量，避免资产太大。

## 放置位置

建议放到：

- `assets/fonts/`

例如：

- `assets/fonts/NotoSansCJKsc-Light.otf`
- `assets/fonts/NotoSansCJKsc-Regular.otf`
- `assets/fonts/NotoSansCJKsc-Medium.otf`
- `assets/fonts/NotoSansCJKsc-SemiBold.otf`
- `assets/fonts/NotoSansCJKsc-Bold.otf`

## 注意事项

### 1. 文件来源要可靠
确保字体包来源合法可用。

### 2. 字体文件命名要一致
后面 `pubspec.yaml` 和代码里会按这些名字引用，尽量统一命名风格。

### 3. 先不要把所有历史字体都删掉
第一阶段只新增字体，不要急着删旧字体，避免回滚困难。

---

# 第二阶段 在 `pubspec.yaml` 注册字体

## 目标

让 Flutter 知道这套本地字体文件存在，并且能按 `fontWeight` 自动切换。

## 要做的事

在 `pubspec.yaml` 里增加 `fonts` 配置。

## 示例结构

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/fonts/
    - assets/images/
    - assets/videos/
    - assets/audios/
    - assets/rive_animations/
    - assets/pdfs/
    - assets/jsons/
    - assets/databases/
    - assets/ecdict/
    - assets/reading/

  fonts:
    - family: Noto Sans CJK SC
      fonts:
        - asset: assets/fonts/NotoSansCJKsc-Light.otf
          weight: 300
        - asset: assets/fonts/NotoSansCJKsc-Regular.otf
          weight: 400
        - asset: assets/fonts/NotoSansCJKsc-Medium.otf
          weight: 500
        - asset: assets/fonts/NotoSansCJKsc-SemiBold.otf
          weight: 600
        - asset: assets/fonts/NotoSansCJKsc-Bold.otf
          weight: 700
```

## 建议

- 如果你已经确认 `Light`、`Medium` 等文件完整可用，再加进去
- 如果只有少量权重，先只注册可确认的文件
- 不要写一堆不存在的 weight 映射

---

# 第三阶段 全局切换字体入口

## 目标

让应用默认字体先切到 `Noto Sans CJK SC`，这样大部分未显式覆盖的文本会自动使用它。

## 重点文件

- `lib/main.dart`
- `lib/flutter_flow/flutter_flow_theme.dart`

---

## 3.1 修改 `main.dart`

### 目标

让全局 `ThemeData` 默认采用本地字体。

### 建议做法

在 `ThemeData` 里加上 `fontFamily: 'Noto Sans CJK SC'`。

这样即使某些页面没有显式写 `fontFamily`，也会先走统一字体。

### 同时建议

保留你已经做过的文本缩放控制，不要让系统缩放重新把排版拉乱。

---

## 3.2 修改 `flutter_flow_theme.dart`

### 目标

把主题层的默认字体逻辑从 `GoogleFonts` 逐步转向本地字体。

### 建议做法

当前这个文件里有大量：

- `GoogleFonts.notoSans(...)`
- `GoogleFonts.inter(...)`

第一阶段不要求一次删完，但建议先把最核心的主题方法切到本地字体。

### 推荐策略

把主题中的基础 `TextStyle` 改成类似：

```dart
TextStyle(
  fontFamily: 'Noto Sans CJK SC',
  fontWeight: FontWeight.w400,
  fontSize: 14.0,
)
```

再通过 `override` 让不同层级复用。

---

# 第四阶段 先替换首页和高风险页面

## 目标

先让最重要、最容易出问题的页面稳定下来，再去碰全项目。

## 优先页面

1. `lib/pages/home_page/home_page_widget.dart`
2. `lib/pages/setting_page/setting_page_widget.dart`
3. `lib/pages/reports_page/reports_page_widget.dart`
4. `lib/pages/result_page/result_page_widget.dart`
5. `lib/pages/random_learn_page/random_learn_page_widget.dart`
6. `lib/pages/random_ask_page/random_ask_page_widget.dart`
7. `lib/pages/random_ask_page2/random_ask_page2_widget.dart`
8. `lib/pages/topic_reading_page1/topic_reading_page1_widget.dart`
9. `lib/pages/topic_reading_page2/topic_reading_page2_widget.dart`
10. `lib/pages/tree_page/tree_page_widget.dart`
11. `lib/pages/tree_catelog/tree_catelog_widget.dart`
12. `lib/pages/topic_catelog/topic_catelog_widget.dart`

## 改法

### 1. 把页面内联 `GoogleFonts.xxx(...)` 改为本地字体 `TextStyle`
例如从：

```dart
style: GoogleFonts.notoSans(
  fontWeight: FontWeight.w600,
  fontSize: 28.0,
)
```

改成：

```dart
style: TextStyle(
  fontFamily: 'Noto Sans CJK SC',
  fontWeight: FontWeight.w600,
  fontSize: 28.0,
)
```

### 2. 优先保留语义不变，只替换字体入口
第一轮不要顺手改布局，先只做字体替换。

### 3. 对首页这种大字号页面重点观察
因为字体换了以后，最容易变化的是：

- 文本宽度
- 是否换行
- 行高
- 首页高度

---

# 第五阶段 清理散落的字体覆盖

## 目标

把项目里不再需要的 `GoogleFonts` 调用逐步收掉，避免以后新页面又把字体体系弄乱。

## 重点处理对象

- `GoogleFonts.notoSans(...)`
- `GoogleFonts.inter(...)`
- 任何页面里单独写死的字体族

## 推荐替换原则

### 原则 1 能走主题就走主题
优先使用 `Theme.of(context).textTheme` 或你的统一封装。

### 原则 2 只保留必要的局部覆写
比如：
- 特殊标题
- 需要强调的按钮
- 少量风格性文本

### 原则 3 不要再新增散点字体族
后续新代码统一只用 `Noto Sans CJK SC`。

---

# 第六阶段 验证中文、英文、数字一致性

## 目标

确认换成 `Noto Sans CJK SC` 后，三类文本都表现正常：

- 中文
- 英文
- 数字

## 验证维度

### 1. 中文字重是否真的变化
测试：
- `w300`
- `w400`
- `w500`
- `w600`
- `w700`

观察是否能看出明显层次。

### 2. 英文和数字是否保持一致风格
重点看：
- 首页数字
- 导航项英文
- 混排文本

### 3. 页面是否出现新的换行或溢出
尤其是：首页和设置页。

### 4. iPhone / Android 是否保持统一
重点对比：
- 字形
- 粗细
- 标题宽度
- 按钮高度
- 文本行高

---

# 第七阶段 回收旧字体方案

## 目标

当新字体稳定后，再把旧的在线字体依赖慢慢清理掉。

## 建议保留一段过渡期
不要一上来就把 `GoogleFonts` 全删了。

建议先：

1. 新字体上线
2. 验证首页和关键页面正常
3. 再批量删旧字体调用
4. 最后考虑移除不再需要的 `google_fonts` 依赖

## 风险

如果你一次性删掉太多旧调用，出了问题会很难定位。

---

# 推荐执行顺序

## 最稳妥的顺序

1. 准备字体文件
2. 在 `pubspec.yaml` 注册字体
3. 在 `main.dart` 设全局 `fontFamily`
4. 改首页和几个核心页面
5. 验证中文、英文、数字
6. 逐步替换其余页面
7. 收尾清理 `GoogleFonts`

---

# 改动难度评估

## 难度等级
**中等**

不是特别难，但需要耐心。

## 主要工作量来源

- 字体文件准备
- `pubspec.yaml` 配置
- 主题层统一
- 页面里大量散点 `GoogleFonts` 替换

## 哪些地方最容易出问题

- 首页大字号文本
- 设置页和列表页
- 阅读页中的混排文本
- 基线对齐和固定 padding 导致的布局漂移

---

# 预期效果

当这套方案完成后，应该能达到：

- Android 和 iPhone 使用同一款字体
- 中文字重真正生效
- 英文、数字、中文在视觉上统一
- 页面不会再因为平台回退字体而出现明显差异

---

# 备注

这份方案的核心不是“换一个名字”，而是**把字体从在线、分散、不可控，改成本地、统一、可验证**。

只有这样，你后面的页面排版修复才会真正稳定。
