# 数据库设计审查报告

> 生成时间：2026-04-05
> 对应代码：`lib/backend/database.dart`

---

## 一、现状总览

### ROM 数据库（只读，随安装包下发）

| 表名 | 主键 | 索引 | 外键索引 | 备注 |
|------|------|------|---------|------|
| Note | Concept_UUID ✓ | 无 | 无（Concept_UUID 仅被引用） | |
| Tree_Root | Root_ID ✓ | 无 | 无 | |
| Tree_Word | Tree_Word_ID (自增) | 无 | Root_ID 无，Concept_UUID 无 | Sort_Order 默认 0，无序 |
| Topic | Topic_ID ✓ | 无 | 无 | |
| Article | Article_ID ✓ | 无 | Topic_ID 无索引 | |

### Hot 数据库（读写，用户私有目录）

| 表名 | 主键 | UNIQUE | 索引 | 备注 |
|------|------|--------|------|------|
| Card | Card_ID (自增) | Concept_UUID ✓ | `(Next_Review_Date, Status&0x0F)` ✓、`uuid` ✓、`favorite` ✓、`random` ✓ | 核心调度表 |
| Review_Log | Log_ID (自增) | 无 | `Log_Date` ✓、`Local_Date_Str` ✓ | 无 UNIQUE |
| Quick_Screen | Screen_ID (自增) | Concept_UUID ✓ | `uuid` ✓ | Screen_Date 无索引 |
| User_Settings | Key ✓ | — | — | 键值对，无额外索引 |

---

## 二、缺失索引分析

### 高优先级

#### 1. `Review_Log(Concept_UUID, Log_Date)` — 月/年汇总查询加速

**背景**：`ReportsPageModel` 按月/年聚合 `Review_Log` 的 `reviewCount`、`goodRate`，当前查询需要对全表扫描后排序。

**建议**：
```sql
CREATE INDEX idx_review_log_card_date ON Review_Log(Concept_UUID, Log_Date DESC);
```

#### 2. `Tree_Word(Root_ID)` — 结构树加载加速

**背景**：`TreeManager.getWordsByRoot(rootId)` 按 Root_ID 查询词，同一词根下的词数量少但查询频繁。

**建议**：
```sql
CREATE INDEX idx_tree_word_root ON Tree_Word(Root_ID, Sort_Order ASC);
```

#### 3. `Article(Topic_ID)` — 主题阅读加载加速

**背景**：`topic_catelog_model.dart` 加载每个主题的 articleIds，`getArticlesByTopic` 按 Topic_ID 查 Article 表。

**建议**：
```sql
CREATE INDEX idx_article_topic ON Article(Topic_ID);
```

### 中优先级

#### 4. `Review_Log(Local_Date_Str, Rating)` — 月度正确率聚合

**背景**：月汇总需按 `Local_Date_Str` 过滤并按 `Rating` 分组统计，`idx_review_log_local_date` 仅覆盖 `Local_Date_Str`，Rating 列仍需回表。

**建议**（未来用户量增长后添加）：
```sql
CREATE INDEX idx_review_log_monthly ON Review_Log(Local_Date_Str, Rating);
```

#### 5. `Card(Status, Next_Review_Date)` — 待复习卡精准筛选

**背景**：现有 `idx_card_schedule` 用 `(Next_Review_Date, Status & 0x0F)` 筛选待复习卡，但 `Status & 0x0F` 表达式无法利用覆盖索引前导列优势。若后续扩展状态位，可考虑：

```sql
CREATE INDEX idx_card_due ON Card(Status, Next_Review_Date ASC);
```

#### 6. `Quick_Screen(Screen_Date)` — 每日快速刷词查询

**背景**：`QuickScreenManager` 可能按日期查今日待刷词。

```sql
CREATE INDEX idx_quick_screen_date ON Quick_Screen(Screen_Date);
```

---

## 三、迁移方案

### 热库索引添加（`wordmemory_hot.db`）

```sql
-- 在 openHotDatabase 的 onUpgrade 中执行，或发布 v2 时迁移
ALTER TABLE Review_Log ADD COLUMN _stub INTEGER DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_review_log_card_date ON Review_Log(Concept_UUID, Log_Date DESC);
ALTER TABLE Tree_Word ADD COLUMN _stub2 INTEGER DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_tree_word_root ON Tree_Word(Root_ID, Sort_Order ASC);
ALTER TABLE Article ADD COLUMN _stub3 INTEGER DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_article_topic ON Article(Topic_ID);
```

> SQLite 的 `CREATE INDEX IF NOT EXISTS` 可安全重复执行，不影响已有数据。

---

## 四、架构建议

### 4.1 ROM 预计算词根聚合数据

当前 `TreeRootModel` 仅有 `rootGroup`，若前端展示每个词根的"词数"（如 `re//` 下有多少词），每次需要 `COUNT(*)` 在 `Tree_Word` 上扫描。建议在 ROM 数据库初始化时，将词根词数写入 `Tree_Root` 表的额外列：

```sql
ALTER TABLE Tree_Root ADD COLUMN Word_Count INTEGER DEFAULT 0;
```

### 4.2 热库压缩/归档策略

`Review_Log` 随时间线性增长，建议：
- 当 `Log_ID` 超过 10 万时，将最早的 30 天数据归档到 `Review_Log_Archive` 表
- 仅保留最近 30 天用于日常 UI 查询，长期数据用于年度报表（批量计算）

### 4.3 Card 表组合索引验证

当前 `idx_card_schedule` 为 `(Next_Review_Date, (Status & 0x0F))`，SQLite 对表达式列建立索引的能力有限。建议在实际性能测试中验证此索引是否生效，若效果不佳，改为显式 `Status` 列：

```sql
-- 在 Card 表添加 Status 列（若当前 Status 存储方式支持）
CREATE INDEX idx_card_due ON Card(Status, Next_Review_Date ASC);
```

---

## 五、总结

| 项目 | 现状 | 建议 |
|------|------|------|
| Card 索引 | 较完善 | 验证 `idx_card_schedule` 表达式索引有效性 |
| Review_Log 索引 | 基础索引存在 | **添加** `(Concept_UUID, Log_Date)` 索引，加速月/年汇总 |
| Tree_Word 索引 | 完全缺失 | **添加** `(Root_ID, Sort_Order)` 索引，加速结构树加载 |
| Article 索引 | 完全缺失 | **添加** `(Topic_ID)` 索引，加速主题阅读加载 |
| ROM 预计算 | 无 | 考虑在 ROM 初始化时预计算词根词数 |
| 热库归档 | 无 | 考虑 Review_Log 超量后归档策略 |

> 以上建议仅提供方案，不实际修改数据库。可根据实际数据量和查询频率决定优先级。
