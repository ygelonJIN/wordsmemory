# 回退系统字体的全项目落地方案

## 目标

把项目从 `GoogleFonts` / 本地自定义字体方案回退到**系统默认字体**，实现以下目标：

- 零额外字体体积
- 零运行时下载
- 零字体资产维护成本
- iOS 使用 `San Francisco + PingFang SC`
- Android 使用 `Roboto + Noto Sans CJK`
- 让系统自行处理中文、英文、数字的字体回退与字重匹配

这个方案的核心不是“让两端完全长得一模一样”，而是：

> **用系统字体获得最稳、最省事、最不易坏的跨平台视觉基线。**

---

## 为什么选这条路

你已经验证出以下事实：

1. 英文和数字的 `fontWeight` 能正常区分
2. 中文在当前 `GoogleFonts` 字体链路里字重不可靠
3. 本地打包一整套中文多字重字体体积太大，不划算
4. 你现在更看重稳定性、零体积和低维护，而不是强行统一成一套字库

因此，回退系统字体是一个非常现实的工程决策。

---

## 这条方案的边界

这条方案**不会**做到：

- Android 和 iPhone 像素级完全一致
- 中文字重在两端完全相同
- 所有字形都严格一致

它会做到的是：

- 字体稳定
- 字重自然
- 中文不再依赖 Google Fonts 在线加载
- 不再需要维护字体资产文件
- 不再为“某个字重没命中”反复排查

如果后续发现 iOS / Android 的轻微视觉差异可接受，那么这就是最省成本的长期方案。

---

## 总体实施思路

不要一次性把所有样式改烂再回滚。

推荐按下面顺序推进：

1. **先移除全局字体强制设置**
2. **再清理 `GoogleFonts` 调用**
3. **再删除页面里的显式 `fontFamily` 覆盖**
4. **最后做首页和高风险页面的视觉复核**

这样可以最大限度避免“回退系统字体后，页面又被局部样式覆盖掉”。

---

# 第一阶段 移除全局字体强制设置

## 目标

让 Flutter 恢复使用系统字体链路，而不是在全局主题里继续强行指定字体。

## 先改什么

优先检查：

- `lib/main.dart`
- `lib/flutter_flow/flutter_flow_theme.dart`

## 需要做的事

### 1. 取消全局 `fontFamily` 绑定
如果 `main.dart` 里设置了类似：

- `fontFamily: '...'`
- `textTheme` 统一指定某个自定义字体

需要移除或回退到系统默认。

### 2. 检查是否还有自定义字体注入点
重点排查：

- `ThemeData`
- `TextTheme`
- `CupertinoThemeData`
- 任何自定义的 `Typography` 封装

### 3. 保留系统默认的文本缩放和平台回退
不要再给字体链路加额外下载或缓存逻辑。

## 验证方式

- 启动 iPhone 真机
- 启动 Android 真机
- 查看首页、设置页、列表页是否都能正常显示中文、英文、数字
- 检查文字是否恢复为系统默认风格

## 阶段 1 成功标准

- 项目不再依赖全局自定义字体
- 页面能自然落到系统字体上
- 没有明显的字体报错或缺字问题

---

# 第二阶段 批量清理 `GoogleFonts`

## 目标

把项目里所有 `GoogleFonts.xxx(...)` 的强制字体调用逐步删掉，让文本回到系统默认字体路径。

## 先改什么

优先改这些高频文件：

1. `lib/pages/home_page/home_page_widget.dart`
2. `lib/pages/setting_page/setting_page_widget.dart`
3. `lib/pages/reports_page/reports_page_widget.dart`
4. `lib/pages/random_learn_page/random_learn_page_widget.dart`
5. `lib/pages/result_page/result_page_widget.dart`
6. `lib/pages/random_ask_page/random_ask_page_widget.dart`
7. `lib/pages/random_ask_page2/random_ask_page2_widget.dart`
8. `lib/pages/topic_reading_page1/topic_reading_page1_widget.dart`
9. `lib/pages/topic_reading_page2/topic_reading_page2_widget.dart`
10. `lib/widgets/hi_greeting.dart`

## 需要做的事

### 1. 删除显式 `GoogleFonts` 包装
把像下面这种：

```dart
style: FlutterFlowTheme.of(context).bodyMedium.override(
  font: GoogleFonts.notoSans(...),
  fontSize: 28.0,
  fontWeight: FontWeight.w600,
)
```

逐步收敛成：

- 只保留必要的 `fontSize`
- 保留必要的 `fontWeight`
- 不再显式指定 `font:`

### 2. 删除对字体家族的硬绑定
例如：

- `font: GoogleFonts.inter(...)`
- `font: GoogleFonts.notoSans(...)`
- `fontFamily: 'Inter'`

都应逐步移除。

### 3. 保留必要的视觉差异，但让字体交给系统
并不是所有 `TextStyle` 都要删光。

保留这些是合理的：
- `fontSize`
- `fontWeight`
- `fontStyle`
- `letterSpacing`
- `decoration`
- `height`

但**不要**再强制指定字体来源。

## 验证方式

- 每改完一个高风险页面就真机看一次
- 重点看：
  - 首页标题
  - 导航项
  - 按钮文字
  - 中文说明文字
  - 数字显示

## 阶段 2 成功标准

- 项目里不再依赖 `GoogleFonts` 作为主字体来源
- 中文、英文、数字都能自然使用系统字体
- 页面样式没有出现大面积崩坏

---

# 第三阶段 收口首页和核心页面的局部样式

## 目标

字体切回系统后，重新检查首页和几个高风险页面的排版是否需要微调。

## 先改什么

优先看：

- `lib/pages/home_page/home_page_widget.dart`
- `lib/pages/setting_page/setting_page_widget.dart`
- `lib/widgets/hi_greeting.dart`

## 需要做的事

### 1. 复核首页字号和间距
系统字体回退后，页面宽度、换行、行高可能和之前不同。

需要检查：
- 首页大标题是否换行
- 按钮是否还在正确位置
- 底部渐变块是否贴底
- 页面是否还会无意义滚动

### 2. 复核 `hi_greeting.dart`
这个组件之前就属于高风险布局点。

要检查：
- 动态字号是否还合理
- `baseline` 是否仍然稳定
- 编辑态是否撑高页面

### 3. 复核设置页和阅读页
这些页面往往有较多中文说明文字和列表项，切回系统字体后可能有轻微宽度变化。

## 验证方式

- iPhone 真机打开首页
- Android 真机打开首页
- 对比：
  - 标题是否还过粗
  - 中文是否正常显示
  - 按钮排列是否错位
  - 页面是否产生新的滚动问题

## 阶段 3 成功标准

- 首页视觉稳定
- 关键页面可读性正常
- 系统字体没有带来明显布局事故

---

# 第四阶段 删除无用字体资产和依赖

## 目标

彻底清掉不再需要的字体维护成本。

## 先改什么

### 1. 删除无用的字体资产引用
如果项目里原本有：

- `assets/fonts/`
- 字体资源声明
- 相关的字体加载逻辑

在确认全项目都不再需要后再删。

### 2. 清理 `google_fonts` 相关调用
如果确认整个项目都不再使用 `GoogleFonts`，再考虑：

- 删除直接调用
- 最后再评估是否移除依赖

### 3. 不要过早删依赖
建议先确认所有页面都能正常跑，再删依赖和资产。

## 验证方式

- 全局搜索 `GoogleFonts.`
- 全局搜索 `fontFamily:`
- 全局搜索字体资产声明
- 确认没有残留调用导致回退异常

## 阶段 4 成功标准

- 字体资产不再占额外体积
- 字体配置不再维护
- 项目字体链路完全回到系统默认

---

# 验收标准

回退系统字体后，最终至少要满足这些条件：

1. 中文、英文、数字都能正常显示
2. iPhone 和 Android 都能正常运行
3. 不再依赖在线字体下载
4. 不再依赖本地字体大文件
5. 页面没有明显排版崩坏
6. 首页和核心页面能接受轻微平台差异

---

# 风险提示

系统字体方案的主要风险是：

- iOS 和 Android 的默认字形会有细微差别
- 同一个 `fontWeight` 的视觉厚度可能不完全一样
- 某些页面宽度可能会发生变化

但这些风险通常都比继续维护自定义字体链路更低。

---

# 推荐执行顺序

如果按最稳的落地顺序来，我建议这样做：

1. **先移除全局字体强制设置**
2. **再批量清理 `GoogleFonts`**
3. **再复核首页和高风险页面**
4. **最后再删无用字体资产和依赖**

---

# 最终建议

如果你已经决定回退系统字体，就不要再中途犹豫去做平台补偿或字体打包。

这条路的核心价值就是：

- 简单
- 稳定
- 零额外体积
- 零下载
- 易维护

它不是最“统一”的字体方案，但很可能是你当前项目里**工程上最划算**的方案。
