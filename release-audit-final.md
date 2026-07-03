# 发布前全量完整审查报告

项目：`demo1red` / WordMemory
审查范围：核心工作流、页面 UI、数据接口、内容渲染、异常兜底、发布准备
审查结论：**当前已经接近发布候选状态，核心阅读/学习链路可运行，但仍存在“页面职责边界、会话状态机收口、错误页映射、统计口径一致性、跨端发布验证”方面的残余风险。**

---

## 1. 审查方法

本次审查按以下维度展开：

1. **应用启动与初始化链路**
2. **主工作流**：主页、学习、复习、快速筛选、专题阅读、结构树、收藏、报表、设置
3. **UI 层**：每个主要页面的可见入口、交互按钮、内容展示
4. **数据层**：`BackendManager`、`StudySessionManager`、`TopicReadingManager`、`TreeManager`
5. **阅读内容解析**：`Content_JSON`、高亮段、UUID 校验、点击行为
6. **发布准备**：测试、构建、文案、异常兜底、数据兼容性

审查依据来自当前仓库中可见的核心文件：

- `lib/main.dart`
- `lib/backend/provider.dart`
- `lib/backend/study.dart`
- `lib/pages/topic_reading_page2/topic_reading_page2_widget.dart`
- `lib/pages/topic_reading_page2/topic_reading_page2_model.dart`
- `test/widget_test.dart`
- `pubspec.yaml`
- `README.md`

---

## 2. 总体结论

### 结论等级
- **核心功能：已可用**
- **发布质量：接近达标**
- **最大风险：页面职责边界、会话状态机收口、错误映射、统计口径一致性、跨端发布验证不足**

### 是否可以正式发布
- **可以进入发布候选阶段**
- **建议在正式对外发布前补一轮回归测试与多端 release 验证**

### 直接原因
1. 核心阅读/学习链路、专题阅读高亮过滤、点击进入学习、结果回流都已串通。
2. 页面级问题主要集中在职责边界和导航/结算语义，而不是核心业务逻辑断裂。
3. 首页、专题阅读、结构树、收藏、报表、设置之间仍有共享状态和统计口径耦合，需要继续收敛。
4. 测试覆盖与多端发布验证仍不够完整，但不再是“硬阻塞级”的单点缺陷。

---

## 3. 发布前检查清单

---

### A. 启动与基础框架

#### A1. App 启动
- 状态：**已完成**
- 依据：`lib/main.dart`
- 说明：
  - `runApp(MyApp())` 正常存在
  - Flutter Web 下已切换 `databaseFactory = databaseFactoryFfiWeb`
  - 已执行 `usePathUrlStrategy()`
  - 已初始化 `FlutterFlowTheme`

#### A2. 路由框架
- 状态：**已完成**
- 依据：`lib/main.dart`
- 说明：
  - 使用 `go_router`
  - 页面之间通过路由跳转
  - 主体架构不是单页临时 demo

#### A3. 本地化与主题
- 状态：**已完成**
- 依据：`lib/main.dart`
- 说明：
  - 已配置本地化 delegates
  - 已配置明暗主题
  - 字体使用 `GoogleFonts.inter()`

#### A4. 启动页 / 加载流程
- 状态：**基本完成**
- 依据：`lib/backend/provider.dart`
- 说明：
  - `BackendManager.initialize()` 有完整的分阶段加载状态
  - 包括存储路径、ROM 数据库、热数据库、TTS、完整性检查、迁移、种子数据
- 风险：
  - Web / 非 Web 的插件兼容性虽然有防护，但需要真实设备和浏览器验证

---

### B. 核心工作流审查

---

#### B1. 首页工作流

##### 功能意义
首页承担“用户进入 app 后的总览和分流”作用，应提供：
- 今日学习状态
- 总进度
- 当前词书进度
- 待复习数量
- 新词数量
- 备份提醒

##### 状态
- **基本完成**

##### 依据
- `BackendManager.loadHomePageData()`
- `HomePageData` 文本派生字段

##### 结论
- 首页的数据结构和业务指标已经存在
- 但仍需确认具体 UI 是否准确绑定所有字段

---

#### B2. 学习会话工作流

##### 功能意义
这是 app 的核心闭环：
- 创建会话
- 获取卡片
- 展示问答内容
- 提交评级
- 更新 FSRS 状态
- 记录日志
- 刷新统计

##### 状态
- **已完成，但需回归验证**

##### 依据
- `StudySessionManager.createLearnSession`
- `submitRating`
- `confirmPendingRating`
- `endSession`
- `undo`

##### 关键逻辑点
- 新卡、复习卡、收藏夹学习、收藏夹复习、快速筛选均有分支
- `pendingPreviewCard` 支持 Ask→Learn 的预览/确认双阶段流程
- 记录 `Review_Log`
- 更新 `total_study_count`、`total_study_time_ms`、`today_study_time_ms`

##### 风险点
- `undo()` 对不同状态的回退逻辑复杂，需确认不会误删或漏删日志
- `confirmPendingRating()` 与 `submitRating()` 两条路径要确保结果一致
- 学习后进度统计依赖多表更新，需防止统计不一致

---

#### B3. 复习工作流

##### 功能意义
用于 FSRS 到期卡片的复习。

##### 状态
- **已完成**

##### 依据
- `createReviewSession()`
- `queryDueCards()`
- `calculateNextState()`

##### 结论
- 结构完整
- 仍需要用真实数据验证“到期卡筛选”和“复习后重算间隔”是否符合预期

---

#### B4. 快速筛选工作流

##### 功能意义
用于快速标记“认识/不认识”，形成轻量筛选流。

##### 状态
- **已完成**

##### 依据
- `QuickScreenManager.initSession()`
- `toggleKnown()`
- `nextPage()` / `prevPage()`

##### 结论
- 支持分页和状态同步
- 但需要确认与 `Quick_Screen` 表的持久化一致性

---

#### B5. 收藏夹工作流

##### 功能意义
支持收藏单词的查看、学习、复习。

##### 状态
- **基本完成**

##### 依据
- `createFavoriteSession()`
- `createFavoriteReviewSession()`
- `createFavoriteLearnSession()`
- `loadFavorites()`

##### 风险点
- 收藏夹学习和收藏夹复习的语义要再确认是否与产品定义一致
- 对已删除 Note 的收藏项，当前 `loadFavorites()` 会跳过，这属于合理降级，但应明确是否需要提示用户

---

#### B6. 结构树工作流

##### 功能意义
用于词根词缀/结构树浏览，不直接计入学习进度。

##### 状态
- **基本完成**

##### 依据
- `TreeManager.getAllGroups()`
- `getRootsByGroup()`
- `getWordsByRoot()`
- `visitWord()`

##### 风险点
- 树词条可能依赖批量 Note 查询，需确认缺失 Note 时 UI 是否仍可正常显示

---

#### B7. 专题阅读工作流

##### 功能意义
这是本次审查最关注的页面之一：
- 显示文章
- 解析高亮词
- 点击高亮词进入学习
- 统计已学词/词汇命中数
- 下一篇/上一篇切换

##### 状态
- **已完成，但曾存在阻塞缺陷，需重点回归**

##### 依据
- `TopicReadingManager.getArticleDisplay()`
- `TopicReadingManager._parseContentJson()`
- `TopicReadingManager._countTopicReadUuids()`
- `TopicReadingPage2Widget`
- `TopicReadingPage2Model`

##### 当前实现要点
- `Content_JSON` 被解析成 `segments`
- `filterInvalidHighlightUuids()` 会批量检查 `Note` 表中的 `Concept_UUID`
- 失效高亮会被降级为普通文本
- 页面层渲染时仍然通过 `isHighlighted && uuid != null` 做防御性判断

##### 结论
- **高亮失效问题已经进入“双保险”状态**：
  1. 数据层过滤
  2. UI 层防御
- 这部分现在比最初状态安全得多

##### 仍需关注
- 文章 JSON 的所有格式分支是否都会走到同样的过滤逻辑
- `_countTopicReadUuids()` 仍有逐条查询 `queryCardByUuid()` 的行为，长文下可能偏慢，但不是阻塞项

---

### C. 页面 UI 审查

---

#### C1. 主页 UI
- 状态：**待确认最终视觉验收**
- 意义：展示概览和入口
- 风险：文本长度、空态、数字格式是否完整

#### C2. 阅读页 UI
- 状态：**基本完成**
- 意义：承载专题阅读和点击学习
- 风险：
  - 高亮渲染是否完全符合数据层结果
  - `next` / `finish` / `catelog` 等按钮状态是否与文章列表一致

#### C3. 学习页 UI
- 状态：**基本完成**
- 意义：呈现单词详情、例句、词根、释义、评级结果
- 风险：
  - 不同字段的显隐是否与设置一致
  - 卡片状态转换后 UI 是否立即刷新

#### C4. 快速筛选 UI
- 状态：**基本完成**
- 意义：快速标记认识词
- 风险：分页、状态同步、进度文本是否准确

#### C5. 收藏页 UI
- 状态：**基本完成**
- 意义：收藏单词浏览与学习入口
- 风险：删除词条后空态处理

#### C6. 报表页 UI
- 状态：**基本完成**
- 意义：展示学习统计、复习统计、数据库统计
- 风险：数值类型转换和空值显示

#### C7. 设置页 UI
- 状态：**基本完成**
- 意义：配置用户名、词书、刷新时间、显示项
- 风险：设置更新后是否都触发对应页面刷新

#### C8. 错误页 UI
- 状态：**存在**
- 意义：异常兜底
- 风险：是否覆盖所有异常路径，仍需验证

---

### D. 数据接口与接口意义审查

---

#### D1. `BackendManager`
- 状态：**已完成**
- 意义：整个 app 的统一数据入口
- 说明：
  - 承担初始化、主页、学习、专题、收藏、树、报表、导入导出等全部数据层协调

#### D2. `StudySessionManager`
- 状态：**已完成**
- 意义：管理学习会话生命周期
- 说明：
  - 学习、复习、收藏夹、快速筛选均由它驱动

#### D3. `TopicReadingManager`
- 状态：**已完成**
- 意义：专题阅读文章解析、文章导航、点击词处理
- 说明：
  - 本次高亮问题的核心修复点就在这里

#### D4. `TreeManager`
- 状态：**已完成**
- 意义：结构树浏览

#### D5. `QuickScreenManager`
- 状态：**已完成**
- 意义：快速筛选流程

---

### E. 内容解析与高亮审查

---

#### E1. 专题文章内容解析
- 状态：**已完成**
- 依据：`TopicReadingManager._parseContentJson()`
- 意义：把 JSON 内容转换成页面可渲染的文本段

#### E2. 高亮词有效性校验
- 状态：**已完成**
- 依据：`filterInvalidHighlightUuids()`
- 意义：防止失效 UUID 继续以高亮样式展示

#### E3. UI 防御性渲染
- 状态：**已完成**
- 依据：`topic_reading_page2_widget.dart`
- 意义：即便数据层偶发漏网，页面层也不会把 `uuid == null` 的段渲染成高亮

#### E4. 点击保护
- 状态：**已完成**
- 依据：`TopicReadingPage2Model.onWordTap()`
- 意义：无效或空 UUID 不会继续进入学习流程

#### E5. 结论
- 状态：**当前已修复到较安全状态**
- 说明：
  - 这条链路从“只在点击层保护”升级为“数据层过滤 + UI 层防御 + 点击层保护”
  - 这已经接近可发布标准

---

### F. 测试审查

#### F1. 默认 widget test
- 状态：**不足**
- 依据：`test/widget_test.dart`
- 问题：当前仍然是基础 smoke test，不足以覆盖业务逻辑

#### F2. 语义高亮专项测试
- 状态：**如果 `test/semantic_highlight_test.dart` 已存在并通过，则为已完成**
- 说明：用户提供的信息中提到：
  - 7 个测试用例全部通过
  - 覆盖有效 UUID、无效 UUID、混合场景、空列表、空 UUID、重复 UUID
- 结论：
  - 这说明专题高亮修复至少已有专项测试保障

#### F3. 回归测试体系
- 状态：**仍需加强**
- 说明：
  - 需要更完整地覆盖首页、学习、专题、收藏、报表、设置等关键流程
  - 目前看更像是局部测试可用，整体自动化回归还不够

---

### G. 构建与发布准备

#### G1. Web release build
- 状态：**已完成**
- 说明：用户已提供“Web release build 成功”的结果

#### G2. Android / iOS release build
- 状态：**未确认**
- 说明：
  - 仓库里有平台目录，但未看到当前审查证据证明两端 release 构建已通过

#### G3. README 发布文案
- 状态：**已完成基础更新**
- 依据：用户提供信息中说明 `README.md` 已由默认 Flutter 描述替换为项目实际内容
- 说明：
  - 这对发布来说是必要但不充分的准备

#### G4. 依赖配置
- 状态：**已完成**
- 依据：`pubspec.yaml`
- 说明：
  - 你提到已新增 `sqflite_common_ffi` 到 dev_dependencies，用于测试支持

---

## 4. 具体工作流逐条核查结果

---

### 4.1 用户首次进入 app
**流程**：启动 → 初始化存储 → 打开数据库 → 初始化 TTS → 初始化会话/路由 → 进入首页

- 结果：**正常，基本完成**
- 可能风险：Web 环境插件初始化和数据库完整性探针需要实际运行再确认

---

### 4.2 从首页进入学习
**流程**：首页 → 创建学习会话 → 拉取卡片 → 展示详情 → 评级 → 写回数据库 → 更新统计

- 结果：**正常，已完成**
- 关注点：`undo()`、`pendingPreviewCard`、`confirmPendingRating()` 的边界要再测

---

### 4.3 从首页进入复习
**流程**：加载到期卡 → 复习评级 → FSRS 更新 → 写 review log → 回写卡片状态

- 结果：**正常，已完成**
- 关注点：历史积压、成熟卡失忆率等报表统计是否准确

---

### 4.4 快速筛选流程
**流程**：创建筛选会话 → 分页展示 → 切换认识状态 → 写入状态表

- 结果：**正常，已完成**
- 关注点：翻页后状态保持、无数据时回退策略

---

### 4.5 收藏夹流程
**流程**：进入收藏页 → 浏览收藏词 → 标记已学/未学 → 可进入学习会话

- 结果：**正常，基本完成**
- 关注点：收藏项对应 Note 缺失时的处理

---

### 4.6 结构树流程
**流程**：浏览树分组 → 打开 root → 浏览词根下单词 → 点击进入学习

- 结果：**正常，基本完成**
- 关注点：大量条目时的批量查询性能

---

### 4.7 专题阅读流程
**流程**：进入专题页 → 选择文章 → 解析内容 → 渲染高亮 → 点击词条 → 进入学习 → 学完返回

- 结果：**目前已修正关键缺陷，整体可用**
- 关注点：是否所有文章格式都能走到 `filterInvalidHighlightUuids()`

---

### 4.8 报表流程
**流程**：统计学习时长、次数、词书进度、复习分布、成熟词数量

- 结果：**正常，基本完成**
- 关注点：数值统计与实际学习/复习日志是否一致

---

### 4.9 设置流程
**流程**：修改用户名、词书、单次会话限制、显示选项、刷新时刻

- 结果：**存在，基本完成**
- 关注点：是否所有设置项都会及时刷新对应页面数据

---

## 5. 已完成、未完成、阻塞项

---

### 已完成
1. App 启动与路由框架
2. 数据库与初始化链路
3. 核心学习、复习、快速筛选、收藏、结构树、报表基础流程
4. 专题阅读的高亮解析修复
5. 高亮点击防御
6. Web release build 成功
7. README 基础更新
8. 专项测试覆盖高亮过滤场景

---

### 未完成
1. Android / iOS release build 的最终验证
2. 全量自动化回归测试体系
3. 对所有页面的端到端验收脚本
4. 对长内容、边界内容、脏数据的统一压力验证
5. 发布说明与用户验收标准的正式归档

---

### 阻塞项
当前**没有看到仍然明确阻塞发布的同级别问题**，前提是以下两点属实：

- 你提供的修改确实已经合并并通过测试
- `Web release build` 成功结果真实有效

如果这两点成立，那么**当前主要不再是“功能阻塞”，而是“发布质量风险”**。

---

## 6. 最终判断

### 现在是否“做好了”
**接近做好，但更准确的说法是：核心阻塞已解除，发布前审查仍需完成最终验收。**

### 具体含义
- 如果只看语义阅读高亮问题：**已经修到位了**
- 如果看整个 app 上线：**还需要补最终回归与多端 release 验证**

### 发布建议
- **可进入候选发布状态**
- 但建议先完成：
  1. Android release 验证
  2. iOS release 验证
  3. 一轮完整人工回归
  4. 专题阅读、学习、报表、收藏、设置全链路抽检

---

## 7. 继续深挖后新增的具体问题

### 7.1 `ErrorPageModel` 的自定义文案映射存在明显逻辑错误
- 位置：`lib/pages/error_page/error_page_model.dart`
- 现象：`_resolveTitle()` 和 `_resolveGuide()` 都把 `customGuide` 当成“标题”和“说明”的共同覆盖值。
- 根因：当外部传入 `guideText` 时，页面标题会被错误替换为说明文案，导致错误页标题与说明混淆。
- 影响：导入存档、部分错误提示等页面会出现“标题不再是标题”的问题，属于**用户可见的文案逻辑缺陷**。
- 严重级别：**中等**。

### 7.2 `SettingPage` 的每日刷新时间展示文案不规范
- 位置：`lib/pages/setting_page/setting_page_widget.dart`
- 现象：时间选项显示为 `0.`、`4.`、`8.`、`18.`，缺少明确单位或格式。
- 根因：UI 文案直接用数字拼点号，像是未完成的占位写法。
- 影响：用户可能无法确认含义，尤其是“0 点 / 4 点 / 8 点 / 18 点”到底是不是刷新时间。
- 严重级别：**中等偏低**，但属于发布前应修正的体验问题。

### 7.3 `SettingPage` 的布局复杂度过高，窄屏下有溢出风险
- 位置：`lib/pages/setting_page/setting_page_widget.dart`
- 现象：页面使用多层 `Column + ListView + Row`，并且大量内容不具备自适应换行策略。
- 根因：词书项和时间选项是横向排布，且没有明显的溢出保护或响应式换行。
- 影响：在小屏手机或系统字体放大时，页面可能出现截断、挤压或 overflow。
- 严重级别：**中等**。

### 7.4 `ResultPage` 的会话结束逻辑存在重复/分支耦合风险
- 位置：`lib/pages/result_page/result_page_model.dart`
- 现象：`fromQuickLearn`、`fromRandomLearn`、`fromSemanticReading`、`fromTreeLearning` 以及默认分支都在 `_loadData()` 里分别调用 `endSession()`。
- 根因：结果页把“总结展示”和“会话收尾”绑定在一起，不同来源逻辑分叉较多。
- 影响：一旦导航参数传错、重复进入结果页或 session 已提前结束，就可能出现统计不一致或重复结算风险。
- 严重级别：**中等**。

### 7.5 `ResultPage` 对统计来源的混用，可能导致展示口径不一致
- 位置：`lib/pages/result_page/result_page_model.dart`
- 现象：有些分支使用 `learnedSpellings`，有些分支使用 `stats.learnedSpellings`，默认分支又额外查询 `getQuickMarkedSpellings()`。
- 根因：统计数据来源没有统一口径。
- 影响：相同一轮学习在不同入口下，结果页展示的“本次已学/已标/已标注”可能口径不同。
- 严重级别：**中等**。

### 7.6 首页与多个页面仍存在“静态定位文本较多”的问题
- 位置：主页、设置页、报表页、结果页、学习页
- 现象：大量标题、说明、统计文本是直接硬编码的中文字符串。
- 根因：当前版本明显偏向业务直写，未统一抽象为文案层。
- 影响：后续如果做多语言、统一文案修正、A/B 调整会非常痛苦。
- 严重级别：**低到中等**，但属于长期维护风险。

### 7.7 学习/结果链路强依赖页面跳转顺序
- 位置：`random_ask_page_model.dart`、`random_learn_page_model.dart`、`result_page_model.dart`
- 现象：Ask 页预览后跳 Learn，Learn 再确认评分，最终跳 Result；任何一步顺序改变都可能影响状态机。
- 根因：流程状态机分散在页面模型中，没有单独的统一状态协调层。
- 影响：一旦出现重复点击、返回键中断、后台恢复、热重载或跨页重进，容易造成状态错位。
- 严重级别：**中等**。

### 7.8 错误页背后的返回行为不够稳健
- 位置：`lib/pages/error_page/error_page_widget.dart`
- 现象：返回按钮直接 `Navigator.of(context).pop()`。
- 根因：它假设错误页总是被 push 到栈里。
- 影响：如果错误页是在某些 `go()` 路径、深链或清栈路径下进入，`pop()` 可能没有可返回栈，用户体验不稳定。
- 严重级别：**中等偏低**。

## 8. 继续深挖后的新发现

### 8.1 `FavoritePage` 入口行为存在“完成/继续”语义混乱
- 位置：`lib/pages/favorite_page/favorite_page_widget.dart`
- 现象：页面顶部有 `finish`，底部有 `复习/学习`，但顶部 `finish` 直接跳 `ResultPage`，没有先确认当前会话是否真实结束。
- 根因：页面把“返回结果页”和“结束会话”两种职责混在同一入口上。
- 影响：如果用户只是浏览收藏夹，却点了 `finish`，会直接进入总结页，造成流程语义混乱。
- 严重级别：**中等**。

### 8.2 `FavoritePageModel.removeFavorite()` 没有做失败兜底
- 位置：`lib/pages/favorite_page/favorite_page_model.dart`
- 现象：直接 `toggleFavorite(uuid)` 后刷新，没有捕获异常，也没有用户可见反馈。
- 根因：删收藏被当作“必定成功”的本地动作处理。
- 影响：如果数据库写入失败，用户会看到状态不一致，却不知道原因。
- 严重级别：**中等偏低**。

### 8.3 `FavoritePage` 的“学习/复习”入口缺少空态约束
- 位置：`lib/pages/favorite_page/favorite_page_widget.dart`、`favorite_page_model.dart`
- 现象：即使收藏为空，底部入口仍可点击。
- 根因：UI 没有根据 `items.isEmpty` 或 `totalCount==0` 禁用学习/复习按钮。
- 影响：用户点击后要么进入空会话，要么走错误兜底，不符合预期。
- 严重级别：**中等**。

### 8.4 `TreePageWidget` 的 `didUpdateWidget` 在路由跳转场景下不一定可靠
- 位置：`lib/pages/tree_page/tree_page_widget.dart`
- 现象：依赖 `didUpdateWidget` 检测 `rootId` 变化，但该页面大多数情况下是通过路由重建而不是父组件更新触发。
- 根因：把“路由参数变化”当成“Widget 更新”来处理。
- 影响：某些路径下可能无法按预期刷新到新词根，尤其是快速切换或 `go()`/`pushNamed()` 混用时。
- 严重级别：**中等**。

### 8.5 `TreePageModel.finishLearning()` 只收集当前 session 的已学词，不检查场景是否真是树学习
- 位置：`lib/pages/tree_page/tree_page_model.dart`
- 现象：只要 `hasSession` 为真就会把 session learnedCards 丢给结果页。
- 根因：缺少“当前 session 类型”为树学习的显式判定。
- 影响：如果用户从别的页面误入 tree 页面，`finish` 可能会展示错误的总结口径。
- 严重级别：**中等**。

### 8.6 `TopicCatelogModel._loadData()` 有初始化重复和超时掩盖问题
- 位置：`lib/pages/topic_catelog/topic_catelog_model.dart`
- 现象：目录页进入时再次调用 `BackendManager.instance.initialize().timeout(Duration(seconds: 5))`。
- 根因：页面层对初始化的职责和启动层职责重复了。
- 影响：
  - 如果 initialize 本身慢，目录页会出现超时打印但不一定明确报错；
  - 如果 initialize 已完成，这一步又多了一层不必要的等待与噪音。
- 严重级别：**中等**。

### 8.7 `TopicCatelogWidget` 中部分打印日志属于发布噪音
- 位置：`lib/pages/topic_catelog/topic_catelog_widget.dart`
- 现象：`initState`、`dispose`、`setOnUpdate` 都有大量 `print`。
- 根因：调试日志未按发布环境分级。
- 影响：Web/移动端控制台会被大量调试输出污染，不利于正式环境排错。
- 严重级别：**低**，但建议清理。

### 8.8 `TopicReadingPage2Widget` 的文章切换逻辑存在路由名不一致风险
- 位置：`lib/pages/topic_reading_page2/topic_reading_page2_widget.dart`、`topic_reading_page2_model.dart`
- 现象：代码里有 `context.pushNamed(TopicCatelogWidget.routeName)`、`ctx.go('/topicReadingPage1?...')`，但当前页面文件是 `TopicReadingPage2Widget`。
- 根因：页面命名、路由名、实际跳转路径之间仍残留历史版本痕迹。
- 影响：如果路由配置不完全兼容，可能出现跳转到错误页面或跳转失败。
- 严重级别：**中等**。

### 8.9 `TopicReadingPage2Model.onFinish()` 会在无 session 时直接进结果页，可能造成“空总结”
- 位置：`lib/pages/topic_reading_page2/topic_reading_page2_model.dart`
- 现象：`BackendManager.instance.hasSession` 为 false 时仍然进入 `ResultPage`。
- 根因：把“退出文章”与“学习结算”混在同一个 finish 行为里。
- 影响：用户可能看到没有内容的总结页，或者误以为本次阅读有统计数据。
- 严重级别：**中等**。

### 8.10 `TopicReadingPage2` 的高亮渲染目前只看 `isHighlighted && uuid != null`
- 位置：`lib/pages/topic_reading_page2/topic_reading_page2_widget.dart`
- 现象：只要 uuid 非空且高亮标记存在，就直接渲染为蓝色高亮。
- 根因：UI 层没有再校验 uuid 是否仍在有效词库内。
- 影响：虽然数据层已过滤大部分无效项，但如果数据源有新脏数据，UI 仍可能出现误高亮。
- 严重级别：**低到中等**，属于防御层不够彻底。

### 8.11 `ReportsPage` 的首页刷新触发方式偏重
- 位置：`lib/pages/reports_page/reports_page_widget.dart`、`reports_page_model.dart`
- 现象：`didChangeDependencies()` 里直接调用 `_model.refresh()`，而 `refresh()` 又会重置并重新拉取数据。
- 根因：页面进入和依赖变化的职责没有拆开。
- 影响：在某些主题切换、媒体查询变化、locale 切换场景下，可能导致不必要的重复刷新。
- 严重级别：**低到中等**。

### 8.12 `ResultPage` 的“home / continue”按钮会把用户直接送回流程入口，但不保证状态已清空
- 位置：`lib/pages/result_page/result_page_widget.dart`、`result_page_model.dart`
- 现象：`continue` 只是按来源跳回对应页面；没有验证 session 是否已被完全结算且没有残留 pending 状态。
- 根因：结果页只负责展示，不负责兜底清状态。
- 影响：如果前一个流程有遗漏，继续按钮可能让用户回到一个“看似正常、实际状态残留”的页面。
- 严重级别：**中等**。

### 8.13 `ErrorPageModel` 的问题是真根因级别的文案逻辑错误
- 位置：`lib/pages/error_page/error_page_model.dart`
- 现象：当传入 `guideText` 时，标题和说明都会被同一个值覆盖。
- 根因：`_resolveTitle()` 把 `customGuide` 当成 title 使用，`_resolveGuide()` 也把它当 guide 使用，变量命名和职责完全混乱。
- 影响：错误页会显示成“标题=说明”，导致用户看不懂页面到底在讲什么。
- 严重级别：**中等**。

### 8.14 `QuickLearnPage` 的分页/会话初始化存在隐性未使用代码和状态漂移风险
- 位置：`lib/pages/quick_learn_page/quick_learn_page_model.dart`
- 现象：`loadSettings()` 的结果被读取但未使用；`hasNext/hasPrev` 只读 backend 状态，没有对应 UI 控件；`prevPage()` 也没有入口。
- 根因：页面功能做了一半，保留了未完成接口和状态字段。
- 影响：代码可读性下降，后续容易误以为分页已完成，实际 UI 却没提供对应操作。
- 严重级别：**低到中等**。

### 8.15 `QuickLearnPage` 的“finish”会直接结束到结果页，但不检查是否还有未处理条目
- 位置：`lib/pages/quick_learn_page/quick_learn_page_widget.dart`
- 现象：顶部 `finish` 直接 `push` 到结果页。
- 根因：完成动作和会话完成状态没有强绑定。
- 影响：用户未筛完就结束，结果统计可能与实际操作不一致。
- 严重级别：**中等**。

## 9. 最新结论与合并版审查结果

**当前状态已经可以从“发现阻塞”调整为“发布候选阶段审查”**。

### 9.1 已确认可用的核心链路
- 应用启动与数据库初始化链路可运行
- 学习 / 复习 / 快速筛选 / 收藏 / 结构树 / 专题阅读主流程可串通
- 专题阅读高亮已实现解析阶段过滤 + UI 防御 + 点击层保护
- 学习会话的 Ask → Learn → confirm → endSession 主路径已完整

### 9.2 仍需继续收口的风险
- 页面职责边界仍偏混合，尤其是 `ResultPage`、`TopicReadingPage2`、`QuickLearnPage`
- 会话状态机仍是多入口共享的全局对象，边界脆弱
- 错误页映射、统计口径、设置刷新、专题目录重复初始化仍有可优化空间
- 多端 release 验证和全量回归测试还不够完整

### 9.3 按优先级整理后的关键问题
1. `ResultPageModel._loadData()` 将结算与展示混在一起，建议收口为幂等展示
2. `TopicReadingPage2Model.onFinish()` 需要区分“浏览结束”与“学习结算”
3. `ErrorPageModel._resolveTitle()` / `_resolveGuide()` 需要修正 title / guide 的映射职责
4. `BackendManager.initialize()` 目前是容错式启动，适合容错，不适合作为“完全就绪”判断
5. `loadHomePageData()` 的今日学习口径混合了学习日志与快速筛选
6. `QuickLearnPageModel` 的 finish / next / prev 需要和会话完成态更强绑定
7. `TopicCatelogModel._loadData()` 不应在页面层重复 initialize

### 9.4 关键调用链已串联完成
- `HomePageModel._loadData()` → `BackendManager.initialize()` → `loadHomePageData()`
- `TopicCatelogModel._loadData()` → `BackendManager.initialize()` → `loadTopics()` / `topicManager.getArticlesByTopic()`
- `TopicReadingPage2Model._loadData()` → `BackendManager.loadArticle()` → `TopicReadingManager.getArticleDisplay()` → `_parseContentJson()` / `filterInvalidHighlightUuids()`
- `TopicReadingPage2Model.onWordTap()` → `BackendManager.visitTopicWord()` / `startTopicReadingWordSession()` → `StudySessionManager.createSingleCardLearnSession()`
- `QuickLearnPageModel._loadData()` → `BackendManager.initQuickLearnSession()` → `StudySessionManager.createLearnSession()`
- `QuickLearnPageModel.toggleKnown()` → `BackendManager.toggleQuickLearnKnown()` → `toggleWordScreenStatus()`
- `ResultPageModel._loadData()` → `BackendManager.endSession()` → `StudySessionManager.endSession()`

### 9.5 最终判断
- **核心功能：已可用**
- **发布质量：接近达标**
- **建议动作：补回归测试与多端 release 验证后即可进入正式发布窗口**

如果后续继续修，优先顺序建议是：
1. 收敛 `ResultPage` / `TopicReadingPage2` 的收口语义
2. 修正 `ErrorPageModel` 的映射职责
3. 统一 `HomePageData` 与报表页统计口径
4. 去掉页面层重复初始化和无意义的调试噪音
5. 补充针对会话边界与空态的自动化测试
- 现象：Ask→Learn 预览时先算 `pendingPreviewCard`，真正写盘时又重新计算一次 `confirmedCard`。
- 根因：预览与确认分离，但没有把预览结果作为确定结果的单一来源。
- 影响：理论上如果当前卡状态在两次计算之间发生变化，预览与最终落盘可能出现轻微偏差。
- 严重级别：**低到中等**，但属于一致性风险。

### 12.4 `undo()` 的回滚语义并不等价于“恢复到用户操作前的完全状态”
- 位置：`lib/backend/study.dart`
- 现象：当撤销的是已落盘评级，会尝试从数据库恢复卡片，但依赖 `lastReviewLogId` 精准删除日志。
- 根因：回滚是“事后修复”，不是“事务反向提交”。
- 影响：一旦中间日志字段缺失、卡片状态已被别处改写，撤销就可能只恢复一部分状态。
- 严重级别：**中等**。

### 12.5 `undo()` 在第一张卡时回退到 `undoLastOperation(hotDb)`，这意味着最后一步被上移到了更广义的全局撤销
- 位置：`lib/backend/study.dart`
- 现象：如果 session 内没有上一张卡，撤销会走全局操作撤回函数。
- 根因：学习会话撤销和应用级撤销混在一起，没有独立定义边界。
- 影响：用户对“撤销本次学习”与“撤销最后一次全局操作”的理解可能不一致。
- 严重级别：**中等**。

### 12.6 `endSession()` 会无条件更新统计与词书进度，但不校验当前 session 是否已全部消费完成
- 位置：`lib/backend/study.dart`
- 现象：只要调用就会统计时长、天数、进度增量，并清掉 session。
- 根因：结束动作偏“强收口”，缺少未完成会话保护。
- 影响：如果用户在中途离开、重复进入结果页或页面层误触结束，会导致统计口径偏移。
- 严重级别：**中等**。

### 12.7 `createSingleCardLearnSession()` 和 `createTreeLearnSession()` 都是在全局 session 里塞单卡上下文
- 位置：`lib/backend/study.dart`
- 现象：专题阅读、结构树、收藏夹等跨入口都会复用同一个 `_currentSession`。
- 根因：多个业务入口共享同一套学习状态机，而不是每个入口都有独立会话对象。
- 影响：如果中途跳转、回退、并发点击或深链进入，容易出现上下文被覆盖。
- 严重级别：**中等偏高**。

### 12.8 `previewRating()` 固定把预览态的可回忆率显示为 100%，这是产品设计，但会掩盖“预览仅是估算”这一事实
- 位置：`lib/backend/study.dart`
- 现象：预览详情里 `retrievabilityPct` 恒为 100.0。
- 根因：为了强调“先选择、后确认”的流程，预览态没有展示真实遗忘概率。
- 影响：如果用户把预览当最终结果，会误解模型实际变化幅度。
- 严重级别：**低**，但建议在 UI 上明确“预览”状态。

### 12.9 `_buildCardDetails()` 对新卡与复习卡采用不同的统计路径，导致同一页面上存在双口径
- 位置：`lib/backend/study.dart`
- 现象：新卡直接返回固定默认值，复习卡则动态算 rating 分布和 retrievability。
- 根因：为了兼容新卡空历史和复习卡历史数据，代码走了两条分叉。
- 影响：如果 UI 没把“新卡/复习卡”状态展示得足够明确，用户会误以为同类卡片指标不一致。
- 严重级别：**低到中等**。

### 12.10 `TopicReadingManager._parseContentJson()` 的自定义 JSON 解析器是高风险实现点
- 位置：`lib/backend/study.dart`
- 现象：项目没有直接使用标准 JSON 库，而是维护了一个简化解析器。
- 根因：为了兼容多种 content 格式，作者选择了轻量自实现。
- 影响：遇到复杂转义、异常嵌套、非标准内容时，解析可能与标准 JSON 行为不完全一致。
- 严重级别：**中等**。

### 12.11 `_countTopicReadUuids()` 是逐条查卡，文章越长越慢，且日志噪音很大
- 位置：`lib/backend/study.dart`
- 现象：每个高亮段都要 `queryCardByUuid()` 一次，并打印大量调试信息。
- 根因：读取统计没有做批量化，也没有把 debug 和 release 充分隔离。
- 影响：长文下进入文章会更慢，且控制台污染严重。
- 严重级别：**中等**。

### 12.12 `filterInvalidHighlightUuids()` 只校验 `Note` 表存在性，不校验词条是否还能真正进入学习链路
- 位置：`lib/backend/study.dart`
- 现象：高亮是否有效只看 Note 记录是否存在。
- 根因：数据层只做了最基本的存在性筛查。
- 影响：如果 Note 存在但 Card 已损坏、状态不完整，点击仍可能在后续学习链路中失败。
- 严重级别：**低到中等**。

### 12.13 `QuickScreenManager` 的“只在内存分页”意味着应用重启后筛选状态不可恢复
- 位置：`lib/backend/study.dart`
- 现象：`_allItems`、`_items`、`_currentPage` 都只存在内存。
- 根因：快速筛选被设计成轻量、短生命周期流程。
- 影响：中途退出会丢失分页位置，但这可能是接受的产品选择；若不是，就属于功能缺失。
- 严重级别：**低**。

### 12.14 `TreeManager.getWordsByRoot()` 的批量 Note 查询是对的，但缺失兜底时只会静默降级到 `compoundForm`
- 位置：`lib/backend/study.dart`
- 现象：拿不到 Note 时直接使用树词表里的原文。
- 根因：为了保证页面不断裂，选择了保底显示。
- 影响：页面看似正常，但某些词的真实 spelling / 解释上下文可能丢失。
- 严重级别：**低到中等**。

### 12.15 `TopicReadingManager.getArticleDisplay()` 的文章与专题查询有较强串联依赖
- 位置：`lib/backend/study.dart`
- 现象：文章存在不代表 Topic 一定存在，Topic 存在也不代表文章段可正常渲染。
- 根因：文章展示由文章表、专题表、内容解析、UUID 过滤四步串起来。
- 影响：任何一个环节有脏数据，都会导致页面半正常、半失败。
- 严重级别：**中等**。

## 13. 继续下钻后的根因收束

### 13.1 现在可以把问题归纳成三个“真正的根因簇”

#### 根因簇 A：会话状态机没有单一真相源
- 表现：学习、收藏、结构树、专题阅读都能创建 session，并且都可能进入结果页。
- 后果：`finish`、`continue`、`undo`、`confirm` 的语义容易混乱。
- 归属函数：`StudySessionManager`、各页面 model 的结束/跳转逻辑。

#### 根因簇 B：初始化和统计口径偏“尽量可用”，不是“强一致可证明”
- 表现：初始化允许部分失败继续，首页统计口径混合快速筛选与学习日志，报表页一次拉多组数据。
- 后果：页面能开，但数据可能有偏差，根因更难定位。
- 归属函数：`BackendManager.initialize()`、`loadHomePageData()`、`loadReportsData()`。

#### 根因簇 C：专题阅读与错误页的展示逻辑存在“文案/路径/状态”三者不一致
- 表现：高亮过滤、点击进入学习、错误页标题和说明、路由跳转路径都存在不同程度的约定混杂。
- 后果：用户看到的不是单点 bug，而是“某些页面语义不统一”。
- 归属函数：`TopicReadingManager`、`ErrorPageModel`、相关页面 model。

### 13.2 最值得优先修的根因
1. `ErrorPageModel` 的标题/说明映射错误
2. `StudySessionManager` 的结束/撤销/确认一致性
3. `TopicReadingManager` 的解析/过滤/点击链路是否能统一校验
4. `BackendManager.initialize()` 的“部分失败继续跑”是否要分级提示
5. `ResultPageModel` 是否应该只做展示，不再承担会话收口

### 13.3 最终结论再升级
- 这版 app **不是单纯“有 bug”**，而是已经能看出一个比较明确的架构特征：
  - **前端页面很多，页面之间通过全局 session 串联；**
  - **后端初始化偏容错，统计偏聚合；**
  - **因此能跑，但一致性靠纪律，不靠强约束。**
- 所以发布前审查的重点不应再是“有没有一个页面坏掉”，而是：
  1. **状态机能不能闭环**
  2. **结果页是不是唯一收口点**
  3. **错误页是不是准确反映根因**
  4. **专题阅读是否不会把脏数据放大成用户可见错误**

如果你要，我下一步可以继续把 `HomePage`、`SettingPage`、`ReportsPage`、`ResultPage` 逐个拆到模型层，把“页面行为—后端函数—数据表”的对应关系补成最终版发布审查表。

---

## 14. 继续下钻后的页面级新发现（本轮补充）

### 14.1 `HomePage` 同时依赖主动刷新和后端监听，存在重复刷新与状态抖动风险
- 位置：`lib/pages/home_page/home_page_widget.dart`、`home_page_model.dart`
- 现象：页面 `initState()` 中先 `_model.refresh()`，随后又 `BackendManager.instance.addListener(_onBackendChanged)`，而 build 中再套一层 `ListenableBuilder(listenable: BackendManager.instance)`。
- 根因：同一页面对后端状态变更绑定了三种路径：手动刷新、监听回调、构建期重建。
- 影响：在设置修改、统计更新、收藏状态变化时，首页可能被频繁重拉，出现不必要的 UI 抖动或性能浪费。
- 严重级别：**中等**。

### 14.2 `HomePage` 的滚动容器被强制禁用滚动，长屏/小屏下可能截断内容
- 位置：`lib/pages/home_page/home_page_widget.dart`
- 现象：`SingleChildScrollView(physics: NeverScrollableScrollPhysics())`。
- 根因：看起来像是希望视觉固定，但又把所有内容放进可滚动容器里。
- 影响：当系统字体增大、用户名过长、文案变长时，页面内容可能直接被挤出可视区域，用户无法滚动查看。
- 严重级别：**中等**。

### 14.3 `HomePage` 的核心指标“今日已学”与“每日目标”语义上正确，但口径是否含快速筛选并不直观
- 位置：`lib/pages/home_page/home_page_model.dart` + `lib/backend/provider.dart`
- 现象：页面展示的今日统计和目标文本组合在一起，但底层统计中曾把学习与快速筛选混合口径。
- 根因：展示层没有明确说明“今日已学”是否包含快速筛选、专题阅读点词等行为。
- 影响：用户会把首页数字当作唯一真实口径，但实际可能是混合统计。
- 严重级别：**中等**。

### 14.4 `SettingPage` 的导入/导出把正常结果也跳转到错误页展示，属于“借错误页做结果页”但语义很绕
- 位置：`lib/pages/setting_page/setting_page_widget.dart`
- 现象：导入成功后，如果有 `skippedCount > 0`，会跳到 `ErrorPage` 并传入 `IMPORT_UUID_MISMATCH`；导出失败也跳 `ErrorPage`。
- 根因：错误页被当成统一消息容器使用，而不仅仅是错误展示页。
- 影响：用户会把“成功导入但有丢弃”误理解成真正错误，或者看不出这是正常的兼容性提示。
- 严重级别：**中等**。

### 14.5 `SettingPageModel` 的导入导出错误码被过度压缩，排障信息不足
- 位置：`lib/pages/setting_page/setting_page_model.dart`
- 现象：导出几乎统一返回 `EXPORT_ERROR`，导入主要返回 `IMPORT_FORMAT_ERROR`。
- 根因：异常种类被吞并成少量错误码。
- 影响：磁盘权限问题、JSON 格式问题、路径取消、数据库迁移失败都可能被误报成同一类错误。
- 严重级别：**中等**。

### 14.6 `SettingPage` 的词书选择、会话限制、展示项开关都是“改了就写库”，但没有明显的二次校验/回退
- 位置：`lib/pages/setting_page/setting_page_model.dart`
- 现象：设置方法直接写 setting 表，再更新本地状态。
- 根因：对设置值合法性的约束主要依赖 UI 层，而不是模型层。
- 影响：如果调用方传入非法值，仍可能污染设置表，后续页面出现难以解释的异常。
- 严重级别：**中等偏低**。

### 14.7 `SettingPage` 的 `dailyRefreshHour` 显示逻辑有体验问题：语义存在，但文本不够标准
- 位置：`lib/pages/setting_page/setting_page_widget.dart`
- 现象：UI 上使用“0.”、“4.”、“8.”、“18.”之类表达。
- 根因：时间选项文案像是临时占位，没有明确“点”或“时”的单位。
- 影响：用户难以立即理解这是刷新时间配置。
- 严重级别：**低到中等**。

### 14.8 `ReportsPage` 每次依赖变化都会强制刷新，可能造成重复查询
- 位置：`lib/pages/reports_page/reports_page_widget.dart`、`reports_page_model.dart`
- 现象：`didChangeDependencies()` 里直接 `_model.refresh()`。
- 根因：页面把“首次进入”和“依赖变化”统一视作“需要重拉数据”。
- 影响：主题切换、媒体查询变化、路由嵌套变化都会让报表数据重刷，属于可见但不致命的性能浪费。
- 严重级别：**低到中等**。

### 14.9 `ReportsPage` 的数据显示高度依赖一次性聚合，任何一个子查询异常都会让整页价值下降
- 位置：`lib/pages/reports_page/reports_page_model.dart`
- 现象：报表页聚合学习时长、次数、词书、成熟率、失忆率、积压等多项指标。
- 根因：报表页是“总成页”，但没有把每个指标拆成独立容错单元。
- 影响：如果其中一项异常，页面可能依旧能打开，但用户看到的会是“缺一块”的报表。
- 严重级别：**中等**。

### 14.10 `ResultPage` 把“展示”和“会话收口”混在一起，生命周期风险依旧存在
- 位置：`lib/pages/result_page/result_page_widget.dart`、`result_page_model.dart`
- 现象：`initState()` 就创建模型并可能在初始化阶段触发结算逻辑；来源类型不同，`endSession()` 也有不同分支。
- 根因：结果页不是纯展示页，而是会话完成的收口页。
- 影响：一旦页面被重复进入、后退重进、参数组合异常，就可能出现重复结算、空结果或展示口径错乱。
- 严重级别：**中等**。

### 14.11 `ResultPage` 的“home / continue”实际是按来源回跳，用户可能把它理解成“重新开始”
- 位置：`lib/pages/result_page/result_page_widget.dart`、`result_page_model.dart`
- 现象：按钮文案语义比较轻，但行为是重路由跳转。
- 根因：文案没有明确区分“返回主页”和“继续上一流程”。
- 影响：如果用户在专题、收藏、树、快速筛选等入口结束后点击 continue，可能回到自己不预期的位置。
- 严重级别：**低到中等**。

### 14.12 `FavoritePage` 的 `finish` 不检查会话类型，也不确认是否真的处于收藏学习/复习流程
- 位置：`lib/pages/favorite_page/favorite_page_widget.dart`
- 现象：顶部 `finish` 直接 `pushNamed(ResultPageWidget.routeName)`。
- 根因：收藏页把结果页当成通用结束页，但没有对 session 做约束。
- 影响：用户只是进收藏浏览，也可能一键进入结果页，流程语义混乱。
- 严重级别：**中等**。

### 14.13 `FavoritePage` 的收藏数量、剩余数量、学习/复习入口需要和空态绑在一起看
- 位置：`lib/pages/favorite_page/favorite_page_widget.dart`、`favorite_page_model.dart`
- 现象：页面展示计数，但入口是否可点击并不总是跟随空态变化。
- 根因：计数展示和操作入口分离。
- 影响：当收藏为空或 Note 缺失时，用户可能仍能点到空流程。
- 严重级别：**中等**。

### 14.14 `TreePage` 的 `didUpdateWidget()` 只处理参数变更，不处理路由首次进入时的全量刷新语义
- 位置：`lib/pages/tree_page/tree_page_widget.dart`
- 现象：页面依赖 `didUpdateWidget()` 判断 rootId 变化，但首次进入通常是 `initState()` 创建模型后由模型自己加载。
- 根因：页面初始化和路由更新两条路径并行。
- 影响：路由参数切换、快速跳转、深链场景下，tree 页面可能出现加载时机不统一。
- 严重级别：**中等**。

### 14.15 `TreePage` 的 `finishLearning()` 与 `reloadPage()` 暗示它既是浏览页又是学习页，职责有点混
- 位置：`lib/pages/tree_page/tree_page_widget.dart`、`tree_page_model.dart`
- 现象：页面顶部同时有 `finish`、`next`，底层还可能调用学习会话收口。
- 根因：结构树页面承载了浏览、筛选、学习入口三重职责。
- 影响：用户很难直觉判断“next”是下一词根、下一页还是下一条学习内容。
- 严重级别：**中等**。

### 14.16 `QuickLearnPage` 的 finish 直接跳结果页，但没有检查当前是否已有未确认状态
- 位置：`lib/pages/quick_learn_page/quick_learn_page_widget.dart`、`quick_learn_page_model.dart`
- 现象：按钮直接跳 `ResultPageWidget.routePath?fromQuickLearn=true`。
- 根因：快速筛选结果页被当作出口，而不是流程状态检查点。
- 影响：如果分页没完成、状态未保存或会话未正确初始化，结果页依旧会出现。
- 严重级别：**中等**。

### 14.17 `QuickLearnPage` 对“下一页”有入口，但未见清晰的“上一页”或边界反馈
- 位置：`lib/pages/quick_learn_page/quick_learn_page_widget.dart`、`quick_learn_page_model.dart`
- 现象：UI 只暴露 `next`，而模型层还有分页状态。
- 根因：功能设计偏单向推进，没有把分页边界做成显式交互。
- 影响：用户可能不知道自己到底在第几页，也不知道有没有到末尾。
- 严重级别：**低到中等**。

### 14.18 `ErrorPage` 目前是全局兜底页，但返回行为仅 `pop()`，在深链/清栈时不够稳
- 位置：`lib/pages/error_page/error_page_widget.dart`
- 现象：back 直接 `Navigator.of(context).pop()`。
- 根因：错误页假设自己一定在导航栈中间，而不是可能成为当前路由栈顶。
- 影响：如果错误页是通过 `go()`、重定向或清栈方式进入，`pop()` 可能没有回退目标。
- 严重级别：**中等偏低**。

### 14.19 `ErrorPage` 与 `SettingPage` 的组合暴露出“错误页兼结果页”模式，应该进一步规范
- 位置：`lib/pages/error_page/error_page_widget.dart`、`setting_page_widget.dart`
- 现象：成功导入但有丢弃时依然进入 ErrorPage 展示 guideText。
- 根因：缺少独立的“提示页”或“结果页”层。
- 影响：错误、警告、成功提示全挤进同一页，后续容易误读。
- 严重级别：**中等**。

### 14.20 `HomePage`、`SettingPage`、`ReportsPage`、`ResultPage` 的页面间跳转没有统一的收口策略
- 位置：多个页面 widget/model
- 现象：有的页面用 `pushNamed`，有的用 `push` 拼路径，有的用 `go`。
- 根因：路由进入方式混用，缺少统一策略。
- 影响：状态恢复、返回栈、错误页返回、结果页回跳都会受影响。
- 严重级别：**中等**。

## 15. 本轮继续深挖的结论

### 15.1 目前页面级问题已经可以归纳成四个主要簇
1. **首页/统计页的刷新与重绘偏重，存在重复刷新和口径不清的问题**
2. **设置页/错误页把“错误、警告、结果提示”混用了，语义层需要拆开**
3. **结果页仍是会话收口页，生命周期复杂，重复进入风险依旧**
4. **收藏、结构树、快速筛选、专题阅读都在共享一套会话/跳转约定，状态机边界不够硬**

### 15.2 当前最应该优先验证的不是“有没有页面”，而是这些页面之间的边界
- `Home -> Setting -> Back -> Home` 是否只刷新一次、口径是否一致
- `Setting import/export -> ErrorPage` 是否会让用户误会成真正错误
- `Favorite/Tree/QuickLearn/TopicReading -> ResultPage` 是否都真的完成了 session 收口
- `ErrorPage -> Back` 是否在所有导航方式下都能回到正确来源

### 15.3 如果再继续往下扒，下一步最值得进入的是模型层与后端口径
- `home_page_model.dart`
- `reports_page_model.dart`
- `result_page_model.dart`
- `tree_page_model.dart`
- `favorite_page_model.dart`
- `quick_learn_page_model.dart`
- `error_page_model.dart`

因为这些文件里会把“页面现象”真正落实到“后端函数、数据库字段、会话状态”的根因上。

---

## 16. 模型层与后端函数继续下钻（本轮新增）

### 16.1 `HomePageModel` 的刷新链路是“自动加载 + 手动刷新 + 后端监听”三重叠加
- 位置：`lib/pages/home_page/home_page_model.dart`、`lib/backend/provider.dart`
- 现象：模型 `initState()` 立即 `_loadData()`，`refresh()` 又可随时重拉；页面层还监听 `BackendManager` 变更。
- 根因：首页被设计成全局状态展示入口，因此对后端 notify 过度敏感。
- 影响：`updateSetting()`、收藏变更、导入导出、会话结算都可能触发首页重绘，刷新频率偏高。
- 严重级别：**中等**。

### 16.2 `HomePageModel.saveDailyTarget()` 只本地更新再异步写库，存在短暂 UI/DB 不一致
- 位置：`lib/pages/home_page/home_page_model.dart`
- 现象：先 `updatePage(() => dailyTarget = target)`，后 `updateSetting('daily_target', ...)`。
- 根因：采用乐观更新策略。
- 影响：如果写库失败，页面会短暂显示已保存，但实际持久化未成功。
- 严重级别：**低到中等**。

### 16.3 `HomePageModel.saveUserName()` 会触发整页重新加载，属于“重操作式保存”
- 位置：`lib/pages/home_page/home_page_model.dart`
- 现象：用户改一次名字，方法会写库后直接 `_loadData()`。
- 根因：为了保证展示同步，采取全量刷新。
- 影响：昵称修改后伴随全页重拉，体验上有轻微闪烁/延迟风险。
- 严重级别：**低到中等**。

### 16.4 `loadHomePageData()` 的“今日已学”其实是学习日志 + 快速筛选的混合口径
- 位置：`lib/backend/provider.dart`
- 现象：`todayLearnedCount: todayCount + todayQuickKnown`。
- 根因：希望首页展示更接近“今天实际碰过的词数”，所以把 Quick_Screen 也算进去。
- 影响：如果用户以为“今日已学”只表示真正学习流程，那首页数字会偏大，口径需要说明。
- 严重级别：**中等**。

### 16.5 `loadHomePageData()` 的日切逻辑依赖 `daily_refresh_hour`，跨时区/系统时间变动时口径会脆
- 位置：`lib/backend/provider.dart`
- 现象：既用 `calculateLocalDateStr(now)`，又用 `todayStartMs = todayLocal.subtract(Duration(hours: refreshHour))`。
- 根因：逻辑日同时存在“日期字符串”和“毫秒区间”两套判定。
- 影响：在时区变化、夏令时、系统时间被手动调整时，今日统计与重置时点可能错位。
- 严重级别：**中等**。

### 16.6 `loadReportsData()` 是典型重聚合页，任何一个小查询都可能拖慢整体响应
- 位置：`lib/backend/provider.dart`、`lib/pages/reports_page/reports_page_model.dart`
- 现象：一次拉总学习时长、总次数、总天数、词书进度、所有词书进度、数据库统计、总复习数、分布、成熟率、失忆率、积压。
- 根因：报表页承担“总览”职责，数据粒度太多。
- 影响：SQL 慢、数据库大、冷启动或老设备下，报表页打开会明显变慢。
- 严重级别：**中等**。

### 16.7 `ReportsPageModel.refresh()` 没有去抖或并发保护
- 位置：`lib/pages/reports_page/reports_page_model.dart`
- 现象：`didChangeDependencies()` 触发刷新时，如果环境变化频繁，刷新请求可重入。
- 根因：模型层没有 `_isLoading` 锁。
- 影响：重复刷新会让报表页反复取数、闪烁，甚至短时显示空态。
- 严重级别：**低到中等**。

### 16.8 `ResultPageModel._loadData()` 把 `endSession()` 当成各来源的统一结算入口，但分支口径差异很大
- 位置：`lib/pages/result_page/result_page_model.dart`、`lib/backend/provider.dart`
- 现象：quick / semantic / tree / random / default 五套逻辑并行，且都在 `_loadData()` 内完成会话收口。
- 根因：结果页同时负责“结束会话”和“展示总结”。
- 影响：只要来源参数错传，`endSession()` 的时机、内容、展示口径都可能变。
- 严重级别：**中等偏高**。

### 16.9 `ResultPageModel` 的 `dailySummary` 与 `sessionSummary` 不是同一口径，用户容易混淆
- 位置：`lib/pages/result_page/result_page_model.dart`
- 现象：`dailySummary` 用 `homeData.todayLearnedCount`，`sessionSummary` 用本次会话 learnedSpellings。
- 根因：页面同时展示“今天总共做了多少”和“本次会话做了多少”。
- 影响：如果用户没意识到这两个数字不同，会误判本次学习效果。
- 严重级别：**低到中等**。

### 16.10 `ResultPageModel` 的 `learnedSpellings` 有“内存参数优先”策略，避免查库失败，但可能和数据库真实状态不一致
- 位置：`lib/pages/result_page/result_page_model.dart`
- 现象：`final spellings = learnedSpellings ?? stats.learnedSpellings;`。
- 根因：倾向于用导航参数传过来的即时结果，减少依赖 DB。
- 影响：如果会话中途已发生状态变化，页面显示可能比数据库更“乐观”或更“旧”。
- 严重级别：**低到中等**。

### 16.11 `ResultPageModel._queryTotalMarkedCount()` 统计的是历史累计，不是本次
- 位置：`lib/pages/result_page/result_page_model.dart`、`lib/backend/provider.dart`
- 现象：通过 `getQuickMarkedSpellings()` 直接拿所有已标记单词总数。
- 根因：该辅助函数没有按会话切分。
- 影响：页面里“本次已标”与“本课已学/累计已标”口径不同，但文案没有特别强调，容易误读。
- 严重级别：**低到中等**。

### 16.12 `FavoritePageModel` 的计数字段是三套来源拼出来的，容易在 Note 缺失时失真
- 位置：`lib/pages/favorite_page/favorite_page_model.dart`、`lib/backend/provider.dart`
- 现象：`collectionCount` 来自 `queryFavoriteCount`，`currentCollection` 来自 `queryFavoriteLearnedCount`，列表数据却来自 `loadFavorites()`。
- 根因：列表和计数分别查，不共用同一过滤后的数据集。
- 影响：只要 `Note` 缺失，顶部计数与列表长度就可能不一致。
- 严重级别：**中等**。

### 16.13 `FavoritePageModel.startFavoriteLearnSession()` / `startFavoriteReviewSession()` 只负责入会话，不负责空态阻断
- 位置：`lib/pages/favorite_page/favorite_page_model.dart`
- 现象：即使收藏为空，依然可调用创建会话并跳转。
- 根因：模型层没有根据 `items` 或 `totalCount` 做前置判定。
- 影响：用户可能进入一个空学习/空复习流程，最后落到空结果页。
- 严重级别：**中等**。

### 16.14 `TreePageModel.finishLearning()` 直接从当前 session 取 learnedCards，但没有验证 session 类型确实是 tree 学习
- 位置：`lib/pages/tree_page/tree_page_model.dart`、`lib/backend/provider.dart`
- 现象：只要当前有 session，就能把 learnedCards 丢给结果页。
- 根因：Tree 页的收口逻辑依赖“当前 session 一定是树学习”这一隐含前提。
- 影响：如果用户跨入口串场，结果页会展示错误来源的总结。
- 严重级别：**中等**。

### 16.15 `TreePageModel.reloadPage()` 采用 `go('/treePage?rootId=...')`，会重建路由但不保留栈
- 位置：`lib/pages/tree_page/tree_page_model.dart`
- 现象：`reloadPage` 不是局部刷新，而是整路由跳转。
- 根因：用路由重进来模拟刷新。
- 影响：返回栈、页面状态、过渡动画都会变化；对用户来说像“重开页面”而不是“下一项”。
- 严重级别：**低到中等**。

### 16.16 `QuickLearnPageModel._loadData()` 读取 settings 但当前没有实际使用，属于残留依赖
- 位置：`lib/pages/quick_learn_page/quick_learn_page_model.dart`
- 现象：`final settings = await BackendManager.instance.loadSettings();` 结果未使用。
- 根因：历史上可能打算用词书/限制配置，但最终逻辑没落地。
- 影响：增加阅读噪音，也暗示功能可能做了一半。
- 严重级别：**低**。

### 16.17 `QuickLearnPageModel.getQuickLearnProgress()` 的“1/100”类进度其实是 `已标注/总卡数`，不是“当前第几页”
- 位置：`lib/backend/provider.dart`、`lib/pages/quick_learn_page/quick_learn_page_model.dart`
- 现象：文本是 `本次已标注: $known 个 / ${session.total} 张`。
- 根因：进度条语义是“完成度”，不是分页器。
- 影响：用户看到 `1/100` 容易理解成“第 1 页/共 100 页”，但这里实际上是“已标 1 张/总 100 张”。
- 严重级别：**中等**，属于明显的可理解性风险。

### 16.18 `QuickLearnPageModel.toggleKnown()` 与 `BackendManager.toggleQuickLearnKnown()` 是“表面切换、实际双态写库”
- 位置：`lib/pages/quick_learn_page/quick_learn_page_model.dart`、`lib/backend/provider.dart`
- 现象：模型点击后交给后端，后端根据当前学习/Quick_Screen 状态决定写入。
- 根因：当前词是否 known 的真相分散在 session learnedCards 和 Quick_Screen 表两处。
- 影响：若中间刷新或并发点击，状态可能短暂不一致。
- 严重级别：**中等**。

### 16.19 `QuickLearnPageModel.nextPage()/prevPage()` 目前只是壳函数
- 位置：`lib/pages/quick_learn_page/quick_learn_page_model.dart`、`lib/backend/provider.dart`
- 现象：后端函数明确注释“QuickScreen 不需要翻页”，实际也不做事。
- 根因：UI 保留了分页概念，但数据结构已改成全量 queue。
- 影响：这是典型的“UI 逻辑遗留”——看上去有分页，实际没有分页。
- 严重级别：**低到中等**。

### 16.20 `ErrorPageModel` 的问题已经明确是根因级 bug，不是小文案问题
- 位置：`lib/pages/error_page/error_page_model.dart`
- 现象：`_resolveTitle()` 和 `_resolveGuide()` 都把 `customGuide` 直接作为 override，导致传 `guideText` 时标题会被说明文本覆盖。
- 根因：标题与说明两个字段的职责没有分离。
- 影响：导入结果、错误提示、警告提示都可能出现“标题像说明”的错位页面。
- 严重级别：**中等**。

### 16.21 `BackendManager.updateSetting()` 只 `notifyListeners()`，不会自动刷新所有依赖缓存
- 位置：`lib/backend/provider.dart`
- 现象：设置改了以后，是否马上刷新取决于各页面自己有没有监听/重新加载。
- 根因：通知是粗粒度的，没有事件分型。
- 影响：首页、报表页、设置页、结果页之间容易出现不同步。
- 严重级别：**中等**。

### 16.22 `BackendManager.loadFavorites()` 的静默跳过会让收藏数据“看起来少了”
- 位置：`lib/backend/provider.dart`
- 现象：Note 缺失时 `continue`。
- 根因：以保底展示为优先。
- 影响：收藏条数与列表不一致，且没有明确提示用户数据被过滤。
- 严重级别：**中等**。

### 16.23 `BackendManager.loadTreePageData()` / `loadArticle()` / `loadReportsData()` 都是“页面一把抓”式函数
- 位置：`lib/backend/provider.dart`
- 现象：页面模型只负责展示，真正的数据组合都在 backend provider 里拼好。
- 根因：FlutterFlow 风格偏向把聚合都放到 provider。
- 影响：一旦某个组合函数变慢或异常，整页就会整体受影响，且难以局部降级。
- 严重级别：**中等**。

### 16.24 `endSession()` 在结果页多入口中被反复调用，但缺少“只结算一次”的可见保护
- 位置：`lib/backend/provider.dart`、`lib/pages/result_page/result_page_model.dart`
- 现象：不同来源都可能触发 endSession，而 result 页模型又在 `_loadData()` 完成时驱动展示。
- 根因：结算动作没有明确幂等标识。
- 影响：理论上可能出现重复计时、重复统计写入的风险，尤其在重复进入/重建场景。
- 严重级别：**中等偏高**。

## 17. 本轮进度条/1/100 语义补充结论

### 17.1 目前仓库里大多数“进度”其实是文本进度，不是视觉进度条
- `QuickLearnPage`：`本次已标注: X 个 / Y 张`
- `FavoritePage`：`当前收藏/总收藏`、`剩余到期数`
- `HomePage`：今日已学、每日目标、书进度
- `ReportsPage`：统计字符串而非条形图

### 17.2 真正容易误导用户的，是这种“分数式文本”
- `1/100` 很容易被理解成页码或题号
- 但在当前代码里，它通常是“已处理数 / 总数”
- 如果页面没有明确“已标注/总卡数”“已学/总词数”“已收藏/总收藏”的标签，用户会自然误判

### 17.3 结论
- 进度显示逻辑本身基本成立
- 主要问题不是算错，而是**语义不够清晰、部分页面没有显式说明分子分母含义、且与分页概念容易混淆**

## 18. 当前深挖结论

这轮继续下钻后，已经能把问题定位到更具体的层面：

1. **首页**：刷新链路叠加，今日口径混合
2. **设置页**：导入导出和错误页语义混用
3. **报表页**：重聚合、重查询、重展示
4. **结果页**：结算与展示耦合，且多来源分支很重
5. **收藏/结构树/快速筛选/专题阅读**：共享一套 session 约定，导致进度与收口逻辑边界模糊
6. **进度文本**：大量“X/Y”是完成度，不是分页，但 UI 文案未总是写清楚

### 下一步如果继续，我会优先再扒：
- `home_page_widget.dart` 里每个数值如何映射到 `HomePageData`
- `reports_page_widget.dart` 里每个统计块如何映射到 `ReportsPageData`
- `result_page_widget.dart` 的每个总结字段如何由 `SessionStats` 生成
- `tree_page_widget.dart` / `favorite_page_widget.dart` / `quick_learn_page_widget.dart` 的每个计数与空态逻辑

这样就能把“页面文本”彻底对回“模型字段”和“后端查询”。

---

## 19. 字段级对照表：Home / Reports / Result / Favorite / Tree / Quick Learn

### 19.1 `HomePage` 字段对照表

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `HiGreeting.name` | `HomePageModel.userName` | `BackendManager.loadHomePageData()` | `User_Settings.user_name` | 用户昵称展示 | 为空时显示占位，体验可接受但不够个性化 |
| 问候语 | `HomePageModel.greeting` | 模型内拼接 | 无 | 首页欢迎语 | 静态文本，无问题 |
| `今日已学0词，0min` | `HomePageModel.todayLearned` | `loadHomePageData()` | `queryLogCountByDate()` + `_queryTodayStudyTimeMs()` + `queryTodayQuickKnownCount()` | 今日学习总览 | 口径混合，容易把快速筛选也算进去 |
| `已X天未备份` / 备份提醒 | `HomePageModel.exportWarning` | `loadHomePageData()` | `User_Settings.last_export_time` | 备份健康提醒 | 7 天阈值固定，解释性一般 |
| `remaining` / `bookProgress` | `HomePageModel.remaining`, `bookProgress` | `loadHomePageData()` | `queryTotalDueCount()`、`queryLearnedCountByBook()`、`queryWordBookById()` | 当前词书推进度 | 页面里可能存在显示但未完全使用的字段 |
| `dailyTarget` | `HomePageModel.dailyTarget` | `loadHomePageData()` | `User_Settings.daily_target` | 每日目标 | 乐观更新后若写库失败会短暂不一致 |

#### 19.1.1 首页关键结论
- 首页展示字段基本都能找到来源。
- 真正风险是**口径混用**与**刷新链路过重**，不是字段缺失。
- `todayLearned` 不是单纯“学习流程完成数”，而是“学习 + 快速筛选”的混合指标。

---

### 19.2 `ReportsPage` 字段对照表

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `userName` | `ReportsPageModel.userName` | `loadReportsData()` | `User_Settings.user_name` | 报表页标题用户标识 | 无明显风险 |
| `totalStudyTimeText` | `ReportsPageModel.totalStudyTimeText` | `loadReportsData()` | `User_Settings.total_study_time_ms` | 总学习时长 | 只要统计口径不统一就会偏差 |
| `totalStudyCountText` | `totalStudyCountText` | `loadReportsData()` | `User_Settings.total_study_count` | 累计学习次数 | 依赖 `endSession()` 写盘完整 |
| `totalReviewCountText` | `totalReviewCountText` | `loadReportsData()` | `queryTotalReviewCount()` | 累计复习次数 | 历史数据一旦缺日志就会少算 |
| `totalDaysText` | `totalDaysText` | `loadReportsData()` | `User_Settings.total_study_days` | 学习天数 | 仅代表结算过的天数 |
| `bookProgressText` | `bookProgressText` | `loadReportsData()` | `queryBookProgress()` + `queryAllBookProgress()` | 词书进度 | 词书切换后需确保刷新 |
| `ratingDistributionText` | `ratingDistributionText` | `loadReportsData()` | `queryTotalRatingDistribution()` | 评级分布 | 四类 rating 的总和若不为 100% 会误导 |
| `matureRateText` | `matureRateText` | `loadReportsData()` | `queryMatureCardCount()` / total | 成熟词转化率 | 依赖 mature 定义一致 |
| `forgotRateText` | `forgotRateText` | `loadReportsData()` | `queryMatureForgottenCount()` | 成熟词失忆率 | 口径较专业，需解释 |
| `throughputText` | `throughputText` | `loadReportsData()` | `totalStudyCount / totalStudyTimeMs` 派生 | 认知吞吐量 | 时间为 0 时需防除零 |
| `backlogText` | `backlogText` | `loadReportsData()` | `queryHistoricalBacklogCount()` | 历史积压量 | 对历史截止点敏感 |

#### 19.2.1 报表页关键结论
- 报表页字段都来自聚合查询，而不是单一表。
- 它的风险不是“字段没取到”，而是**某个子查询失败导致整页信息不完整**。

---

### 19.3 `ResultPage` 字段对照表

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `savingStatus` | `ResultPageModel.savingStatus` | 模型内状态 | 无 | 保存状态提示 | 纯 UI 文案 |
| `userName` | `ResultPageModel.userName` | `loadSettings()` | `User_Settings.user_name` | 用户称呼 | 若 settings 拉取失败会空 |
| `dailySummary` | `dailySummary` | `loadHomePageData()` + `endSession()` | 首页统计 + 本次会话结算 | 今日总览 | 与本次会话 summary 不是同一口径 |
| `sessionSummary` | `sessionSummary` | `endSession()` / 导航参数 | `SessionStats.learnedSpellings` / `learnedSpellings` 参数 | 本次学习/标注数量 | 多来源参数优先级较复杂 |
| `learnedWords` | `learnedWords` | `getSpellingsByUuids()` | `Note.spelling` | 展示本次学过的词 | 数据缺失时只显示“无” |
| `newCount` | `newCount` | `endSession()` | SessionStats | 新学数量 | 统计与界面来源耦合 |
| `reviewCount` | `reviewCount` | `endSession()` | SessionStats | 复习数量 | 依赖状态分类正确 |
| `relearnCount` | `relearnCount` | `endSession()` | SessionStats | 重学数量 | 与 FSRS 状态变化相关 |
| `againPercent` 等 | 评级占比字符串 | `endSession()` | SessionStats | 本次评级分布 | 文案与数值格式固定为整百分比 |
| `avgStabilityChange` / `avgRetrievabilityChange` | 平均变化值 | `endSession()` | SessionStats | 模型效果反馈 | 单位显示要注意一致性 |

#### 19.3.1 结果页关键结论
- 结果页是**强耦合展示页 + 会话收口页**。
- 它展示的数据几乎全来自 `SessionStats`，但 `dailySummary` 又来自首页聚合，因此混合了两套口径。

---

### 19.4 `FavoritePage` 字段对照表

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `collectionCount` | `FavoritePageModel.collectionCount` | `_loadData()` | `queryFavoriteCount()` | 收藏总数 | 与列表长度可能因 Note 缺失不一致 |
| `currentCollection` | `currentCollection` | `_loadData()` | `queryFavoriteLearnedCount()` | 已学收藏数 | 不一定表示已复习或已掌握 |
| `remaining` | `remaining` | `_loadData()` | `queryDueFavoriteLearnedCount()` | 收藏中到期复习数 | 到期定义依赖 FSRS |
| `items` | `FavoritePageModel.items` | `BackendManager.loadFavorites()` | `Card` + `Note` | 收藏列表 | Note 缺失会静默跳过 |
| `isLearned` | `FavoriteItemData.isLearned` | `loadFavorites()` | `Card.favoriteLearned` | 是否已在收藏夹学习过 | 仅是标记，不等于掌握 |

#### 19.4.1 收藏页关键结论
- 收藏页顶部计数和列表数据来自不同查询链。
- 只要 `Note` 断裂，顶部就可能显示比列表更多的收藏。

---

### 19.5 `TreePage` 字段对照表

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `currentRootId` | `TreePageModel.currentRootId` | `reloadData()` / `onInitialized()` | 路由参数 `rootId` | 当前词根上下文 | 路由切换与 widget 更新语义有偏差 |
| `rootName` | `rootName` | `loadTreePageData()` | `Tree_Root.Root_Name` | 词根名 | 为空时回退默认“re” |
| `rootDefinition` | `rootDefinition` | `loadTreePageData()` | `Tree_Root.Root_Definition` | 英文/中文释义 | 为空时有默认文案掩盖问题 |
| `rootOrigin` | `rootOrigin` | `loadTreePageData()` | `Tree_Root.Root_Origin` | 来源说明 | 如果格式不标准会影响排版 |
| `rootFunction` | `rootFunction` | `loadTreePageData()` | `Tree_Root.Root_Function` | 功能说明 | 目前更多是展示性字段 |
| `words` | `words` | `loadTreePageData()` + `_treeManager.getWordsByRoot()` | `Tree_Word` + `Note` | 该根下单词列表 | 缺 Note 时降级为树词原文 |

#### 19.5.1 结构树页关键结论
- 页面字段很清晰，核心是 `Tree_Root` 和 `Tree_Word` 两张表。
- 风险在于 `Note` 断裂时会降级显示，用户不一定知道数据已退化。

---

### 19.6 `QuickLearnPage` 字段对照表

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `items` | `QuickLearnPageModel.items` | `getSessionCardsWithNote()` | `Card` + `Note` + `Quick_Screen` | 快速筛选列表 | 本质是 session queue 的视图 |
| `progressText` | `progressText` | `getQuickLearnProgress()` | `currentSession.learnedCards` / `currentSession.total` | 当前完成度 | `1/100` 容易被误读成页码 |
| `hasNext` / `hasPrev` | `QuickLearnPageModel.hasNext/hasPrev` | 后端壳函数 | 无 | 分页能力 | 实际固定 false，UI 却保留入口 |
| `isKnown` | `QuickLearnItemData.isKnown` | `getSessionCardsWithNote()` / `toggleQuickLearnKnown()` | `Quick_Screen.Status` + `session.learnedCards` | 当前认识状态 | 真相分散在内存和表里 |

#### 19.6.1 快速筛选页关键结论
- `1/100` 不是分页，而是完成度文本。
- 页面 UI 如果不强调“已标注/总卡数”，很容易被看成“第 1 页/共 100 页”。

---

### 19.7 字段级对照的总判断

1. **字段绝大多数都有后端来源。**
2. **真正的问题不是缺字段，而是字段口径与页面语义不总一致。**
3. **`HomePage`、`ResultPage`、`QuickLearnPage` 是最容易让用户误解口径的三个页面。**
4. **`FavoritePage`、`TreePage` 主要问题在静默降级和空态提示不足。**

## 20. 继续补齐未深挖页面：Loading / Topic Catalog / Topic Reading / Random Ask-Learn

### 20.1 `LoadingPage` 字段与后端

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `loadingText` | `LoadingPageModel.loadingText` | `BackendManager.loadingStatusStream` + `initialize()` | 初始化各阶段状态 | 启动过程提示 | 只显示文本，不显示百分比/阶段数 |
| `GoldenE` / `v1.0.0` | 纯 UI 字段 | 无 | 无 | 启动页品牌展示 | 静态信息，风险低 |

#### 20.1.1 Loading 页关键结论
- 启动页的逻辑是“听后端 loadingStatus 流并跳首页”。
- 它是整个初始化链路的可视化出口，但没有阶段进度条，用户只能看到文本变化。

---

### 20.2 `TopicCatelog` 字段与后端

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `topics` | `TopicCatelogModel.topics` | `loadTopics()` + `getArticlesByTopic()` | `Topic` + `Article` | 专题目录列表 | 文章列表与专题列表两段式加载，较慢 |
| `isLoading` | `TopicCatelogModel.isLoading` | 模型状态 | 无 | 加载中提示 | initialize + timeout 双重复杂 |
| `topicId/topicName/articleIds` | `TopicItemModel` | `loadTopics()` + `getArticlesByTopic()` | `Topic` / `Article` | 专题跳转数据 | 文章 ID 为空时回退逻辑弱 |

#### 20.2.1 目录页关键结论
- 目录页不仅加载专题，还会为每个专题再查文章列表，属于典型的 N+1 结构。
- 页面里对 `initialize()` 做 5 秒超时，只是减少卡死感，不是根治方案。

---

### 20.3 `TopicReadingPage1/2` 字段与后端

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `pageData.topicName` | `pageData?.topicName` | `loadArticle()` | `Article` + `Topic` | 当前专题名 | 若文章解析失败则回退默认“科技” |
| `pageData.wordCountText` | `TopicReadingPageData.wordCountText` | `loadArticle()` | `Article.Word_Count` | 文章词数 | 纯展示 |
| `pageData.readCountText` | `pageData.readCountText` | `loadArticle()` + `countTopicReadUuids()` | `Card.Topic_Read` | 已读词数 | 逐条统计，长文慢 |
| `segments` | `TopicReadingPageData.segments` | `loadArticle()` | `Article.Content_JSON` | 正文段落+高亮词 | JSON 解析/过滤是核心风险 |
| `nextArticleId/previousArticleId` | `TopicReadingPage1/2Model` | `getTopicArticlesWithIndex()` / `getNextArticleId()` | `Article` 排序 | 上下篇导航 | 路由名与页面命名存在历史痕迹 |
| `hasNext/hasPrevious` | `TopicReadingPage1/2Model` | 同上 | `Article` 排序 | 按钮显隐 | 如果当前文章不在列表内，导航会失败 |
| `currentIndex/totalCount` | `TopicReadingPage1Model` | `getTopicArticlesWithIndex()` | `Article` 列表 | 文章序号/总数 | 主要用于“1/100”类型文本或跳转 |

#### 20.3.1 专题阅读页关键结论
- `Page1` 更像主阅读/交互页，`Page2` 像历史版本或另一路由变体，但两者逻辑高度重叠。
- 最大风险来自：`Content_JSON` 解析、高亮 UUID 校验、文章导航与返回结果页的关系。

---

### 20.4 `RandomAsk / RandomLearn / RandomAsk2 / RandomLearn2` 字段与后端

| 页面字段 | 来源模型字段 | 后端函数 | 数据库/查询来源 | 业务意义 | 风险 |
|---|---|---|---|---|---|
| `cardData` | `RandomAsk/RandomLearnModel.cardData` | `loadRandomAskCard()` / `loadRandomLearnCard()` / `previewRating()` | `Card` + `Note` + FSRS 计算 | 当前词卡完整显示 | Ask/Learn 之间存在预览/确认双阶段 |
| `progress` / `progressText` | `cardData.progressText` / 模型文本 | `getCurrentCardWithDetails()` / `getQuickLearnProgress()` | `StudySession.currentIndex/total` | 会话进度显示 | `1/100` 类文本容易被误读为页码 |
| `statusText` | `cardData.statusText` | `getCurrentCardWithDetails()` | `Card.Status` | 当前卡状态 | 需与 Ask/Learn/Review 模式一致 |
| `again/hard/good/easy` | 评级分布文本 | `getCurrentCardWithDetails()` / `previewRating()` | FSRS 计算 | 评级建议/风险 | 预览和确认两个阶段要防口径漂移 |
| `stability/retrievability` | `cardData.stability` / `retrievability` | 同上 | `Card.S` / `Card.R` | FSRS 核心指标 | 属于模型输出，展示要明确单位 |
| `showEtymology/showDefinition/showExample` | `RandomLearnPageModel` | `loadSettings()` | `User_Settings` | 控制显示内容 | 设置变更后刷新依赖多页面同步 |
| `isFavorite` | `RandomLearnPageModel.isFavorite` | `loadRandomLearnCard()` + `toggleFavorite()` | `Card.Favorite` | 收藏状态 | toggling 后需要同步刷新 |

#### 20.4.1 Ask/Learn 页面关键结论
- `Ask` 页面先 `previewRating()`，`Learn` 页面再 `confirmPendingRating()`，这是一个显式的“双阶段模型”。
- 这种设计是合理的，但要求 UI 必须非常清楚地告诉用户：**Ask 是预览，Learn 才是落盘。**
- `progress` 文本如果只显示 `1/100`，需要明确它是“当前会话进度”，不是“题目页码”。

## 21. 本轮最终补齐结论

### 21.1 字段级对照已经把大部分页面串起来了
现在可以看清楚：
- **首页**：聚合统计
- **报表页**：深度统计
- **结果页**：会话总结
- **收藏页**：收藏数据 + 学习状态
- **结构树**：树数据 + Note 回退
- **快速筛选**：会话 queue + Quick_Screen 状态
- **Loading**：初始化状态文本
- **专题目录**：Topic + Article 列表
- **专题阅读**：Article 内容 + 高亮 UUID + 导航
- **Ask/Learn**：Card + Note + FSRS 预览/确认

### 21.2 当前最重要的两个风险仍然没变
1. **口径不统一**：同一页面/相邻页面上的“已学、已标、完成度、总数”不是同一层含义。
2. **会话状态机分散**：多个页面都能结束会话、回到结果页、恢复上一个页面，边界仍不够硬。

### 21.3 当前审查已经可以给出更明确的发布判断
- 功能面：基本齐了
- 数据面：大部分字段都能对上
- 风险面：**语义口径、导航收口、空态/异常态仍需要进一步统一**

如果你继续，我下一步建议直接做一件最有价值的事：
**把 `result_page_model.dart`、`random_ask_page_model.dart`、`random_learn_page_model.dart`、`topic_reading_page1/2_model.dart` 的“会话流转图”整理出来，明确每一步谁创建 session、谁预览、谁确认、谁结算、谁回跳。**

---

## 22. 会话流转图与状态机收口（本轮新增）

### 22.1 `Random Ask -> Random Learn -> Result` 主链路

#### 流程
1. `RandomAskPageModel._loadData()`
   - 先 `loadRandomAskCard()` 读当前 session 的卡。
   - 如果没有 session，才按设置创建 `createLearnSession(limit, bookId)`。
2. `RandomAskPageModel.submitRating(rating)`
   - 调 `previewRating(rating)`，只计算、不落盘。
   - 把预览结果塞进 `pendingPreviewCard`。
   - 跳 `RandomLearnPage`。
3. `RandomLearnPageModel.submitRating(rating)`
   - 从 `session.pendingRating` 取预览评级。
   - 调 `confirmPendingRating(pendingRating)` 真正落盘。
   - 根据 session 来源决定回跳：
     - `favorite` -> `FavoritePage`
     - `quick_learn` -> `QuickLearnPage`
     - 专题阅读 -> `TopicReadingPage1`
     - 树学习 -> `TreePage`
     - 普通学习 -> 下一张 Ask 或 `ResultPage`
4. `ResultPageModel._loadData()`
   - 调 `endSession()` 结算统计。
   - 生成 `dailySummary`、`sessionSummary`、`learnedWords` 和统计字段。

#### 根因结论
- 这是一个**明确的双阶段学习状态机**，但目前状态分散在 Ask、Learn、Result 三个页面模型中。
- 真正的“单一真相源”是 `StudySessionManager._currentSession`，页面只是围绕它做拆分。
- 风险在于：任何一个页面跳转不对、重复进入、或者 `pendingPreviewCard` 没清掉，都会让链路口径变脆。

---

### 22.2 `TopicReading -> Ask/Learn -> 回流专题` 链路

#### 流程
1. `TopicReadingPage1Model.onWordTap(uuid)` / `TopicReadingPage2Model.onWordTap(uuid)`
   - 先检查 UUID 是否存在于词库（Page1 有 `checkConceptExists`，Page2 目前更依赖数据层过滤）。
   - 调 `visitTopicWord(uuid)` 记录专题阅读点击。
   - 调 `startTopicReadingWordSession(uuid, articleId, topicId)` 创建单卡学习会话。
   - 跳 `RandomAskPage`。
2. `RandomAskPageModel.submitRating(rating)`
   - 预览，不落盘。
   - 跳 `RandomLearnPage`。
3. `RandomLearnPageModel.submitRating(rating)`
   - `confirmPendingRating()` 落盘。
   - `markTopicWordRead(uuid)` 把卡标记为专题已读。
   - 回跳 `'/topicReadingPage1?articleId=...&topicId=...'`。

#### 根因结论
- 这是**专题阅读点词 -> 单卡学习 -> 回流原文章** 的闭环。
- 所有恢复信息都依赖 session 里保存的 `resumeArticleId/resumeTopicId`。
- 风险在于：`ResultPage` 不是这条链路的主出口，真正的出口是**回流专题页**。
- 如果会话为空却进了结果页，就会出现“空总结”的错觉。

---

### 22.3 `Tree -> Ask/Learn -> 回流树页` 链路

#### 流程
1. `TreePageModel.onWordTap()`（对应页面内词点击）
   - `startTreeLearnSession(conceptUuid, rootId)` 创建单卡学习会话。
   - 跳 `RandomAskPage`。
2. `RandomAskPageModel.submitRating(rating)`
   - 预览 -> 跳 Learn。
3. `RandomLearnPageModel.submitRating(rating)`
   - `confirmPendingRating()` 落盘。
   - 因 `treeResumeRootId != null`，回跳 `'/treePage?rootId=...'`。

#### 根因结论
- Tree 和 Topic Reading 一样，都是**单卡注入 + 回流原页面**。
- 它们和普通学习最大的区别不是页面，而是 session 里多了恢复上下文。
- 如果恢复上下文被清掉或覆盖，用户就会被送错页面。

---

### 22.4 `Favorite -> Ask/Learn -> 回流收藏页` 链路

#### 流程
1. `FavoritePageModel.onWordTap(conceptUuid)`
   - `startFavoriteWordSession(conceptUuid)` 创建单卡会话。
   - 跳 `RandomAskPage`。
2. `RandomAskPageModel.submitRating(rating)`
   - 预览 -> 跳 Learn。
3. `RandomLearnPageModel.submitRating(rating)`
   - `confirmPendingRating()` 落盘。
   - `markTopicWordRead(uuid)`。
   - 因 `resumeArticleId == 'favorite'`，回跳 `'/favoritePage'`。

#### 根因结论
- 收藏页的学习不是独立体系，而是专题学习的“收藏分支”式复用。
- 这里的关键是 `resumeArticleId == 'favorite'` 这个哨兵值。
- 这是一种可行但脆弱的约定：一旦字符串常量变化，回流逻辑就可能断。

---

### 22.5 `QuickLearn -> Ask/Learn -> 回流快速筛选页` 链路

#### 流程
1. `QuickLearnPageModel._loadData()`
   - `initQuickLearnSession(limit: 70)` 创建当前会话。
   - 读取 `getSessionCardsWithNote()` 生成展示列表。
2. 用户点词
   - `startQuickLearnWordSession(conceptUuid)` 创建单卡会话。
   - 跳 `RandomAskPage`。
3. `RandomAskPageModel.submitRating(rating)`
   - 预览 -> 跳 Learn。
4. `RandomLearnPageModel.submitRating(rating)`
   - `confirmPendingRating()`。
   - 因 `resumeArticleId == 'quick_learn'`，回跳 `'/quickLearnPage'`。

#### 根因结论
- 快速筛选页与收藏/树/专题一样，也通过单卡会话复用学习页。
- 区别是它的主列表并不真的分页，而是一个 queue 视图。
- 所谓 `1/100` 也是这个 queue 的完成度，不是页码。

---

### 22.6 `ResultPage` 其实是“普通学习 / 快速筛选 / 专题阅读 / 结构树 / 收藏”多入口的统一终点，但不是唯一终点

#### 入口分支
- `fromRandomLearn == true`：普通学习总结
- `fromQuickLearn == true`：快速筛选总结
- `fromSemanticReading == true`：专题阅读总结
- `fromTreeLearning == true`：树学习总结
- 默认分支：普通学习总结

#### 关键事实
- `ResultPageModel` 负责把多个不同来源统一成一张总结页。
- 但**专题阅读、树、收藏、快速筛选的单卡回流链路并不依赖 ResultPage**。
- `ResultPage` 更像“最终汇总页”，不是所有链路的出口页。

#### 风险
- 页面职责混合：展示、结算、回跳来源都放在一起。
- 如果用户通过特殊入口直接开了 ResultPage，而 session 已空，就会出现“有页面、没内容”的情况。

---

### 22.7 会话流转中的单一真相源和脆弱约定

#### 真相源
- `StudySessionManager._currentSession`
- `pendingRating`
- `pendingPreviewCard`
- `resumeArticleId`
- `resumeTopicId`
- `treeResumeRootId`

#### 脆弱约定
- `resumeArticleId == 'favorite'`
- `resumeArticleId == 'quick_learn'`
- 路由路径字符串 `/topicReadingPage1?...`、`/treePage?...`、`/favoritePage`、`/quickLearnPage`

#### 结论
- 这套系统能跑，是因为页面和后端都遵守了一套约定。
- 但它不是强类型状态机；它更像“约定驱动的流程网络”。
- 因此发布前最要防的是：**字符串常量、路由跳转、会话清理顺序**。

## 23. 本轮最终结论

现在已经可以把整个 app 的学习/阅读/筛选闭环概括为：

- **Ask** 负责预览
- **Learn** 负责确认落盘
- **Result** 负责汇总展示与结算
- **Topic/Tree/Favorite/QuickLearn** 负责把用户引入某个单卡上下文，再回流原页面
- **Loading** 负责启动态
- **TopicCatalog** 负责入口目录

### 最核心的结论
1. 页面已经不是“各自独立”，而是被一套 session 状态机串起来了。
2. 这套状态机的根在 `StudySessionManager`，页面只是在读写它。
3. 当前最大风险不在某个按钮，而在**会话状态、字符串哨兵值、页面回流路径**。

### 如果你继续
我下一步可以直接把这张会话流转图写成文档里的正式章节，并把每条链路对应到具体函数名和页面跳转路径，形成最终可交付的“全链路审查图”。
