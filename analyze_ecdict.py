#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ECDict CSV 分类体系深度分析
"""

import pandas as pd
import re
from collections import Counter
import warnings
warnings.filterwarnings('ignore')

# 定义语义领域关键词
DOMAINS = {
    'technology': ['technology', 'computer', 'software', 'hardware', 'internet', 'algorithm', 'data', 'digital', 'electronic', 'network', 'cyber', 'code', 'programming', 'database', 'system', 'process', 'machine', 'robot', 'automation', 'AI', 'artificial intelligence', 'machine learning', 'device', 'chip', 'semiconductor', 'cloud', 'wireless', 'broadband', 'satellite', 'interface', 'platform', 'encryption', 'server', 'browser', 'app', 'application'],
    'science': ['science', 'physics', 'chemistry', 'biology', 'genetics', 'evolution', 'species', 'organism', 'molecule', 'atom', 'experiment', 'hypothesis', 'research', 'cell', 'DNA', 'RNA', 'bacteria', 'virus', 'organ', 'tissue', 'theory', 'quantum', 'nuclear', 'particle', 'electron', 'gravity', 'energy', 'force', 'motion', 'thermodynamic', 'geology', 'astronomy', 'ecology', 'botany', 'zoology', 'microorganism'],
    'medicine_health': ['disease', 'patient', 'treatment', 'therapy', 'doctor', 'hospital', 'medicine', 'drug', 'symptom', 'diagnosis', 'cancer', 'virus', 'infection', 'immune', 'vaccine', 'surgery', 'health', 'body', 'brain', 'heart', 'lung', 'liver', 'kidney', 'blood', 'mental', 'psychology', 'depression', 'anxiety', 'obesity', 'diabetes', 'epidemic', 'pandemic', 'clinical', 'pharmaceutical', 'cardiovascular', 'neurological', 'dermatological', 'pediatric', 'geriatric', 'therapeutic', 'prognosis', 'syndrome'],
    'law_politics': ['law', 'legal', 'court', 'judge', 'lawyer', 'crime', 'justice', 'rights', 'legislation', 'statute', 'government', 'politics', 'election', 'president', 'minister', 'congress', 'parliament', 'policy', 'vote', 'democracy', 'republic', 'monarchy', 'treaty', 'diplomatic', 'ambassador', 'embassy', 'nation', 'state', 'citizen', 'immigration', 'constitution', 'judicial', 'legislative', 'executive', 'senate', 'chamber', 'bill', 'amendment', 'faction'],
    'military_defense': ['military', 'war', 'army', 'soldier', 'battle', 'weapon', 'navy', 'aircraft', 'missile', 'troop', 'combat', 'defense', 'security', 'terrorist', 'attack', 'conflict', 'invasion', 'occupation', 'strategic', 'intelligence', 'surveillance', 'nuclear weapon', 'ammunition', 'tank', 'fighter', 'submarine', 'siege', 'ceasefire', 'warfare', 'artillery', 'infantry', 'marine', 'airforce', 'coalition', 'guerilla', 'militant', 'radical'],
    'economics_trade': ['economy', 'economic', 'market', 'trade', 'business', 'company', 'investment', 'bank', 'finance', 'stock', 'profit', 'GDP', 'inflation', 'recession', 'unemployment', 'currency', 'dollar', 'euro', 'import', 'export', 'tariff', 'budget', 'fiscal', 'monetary', 'capital', 'wealth', 'corporate', 'enterprise', 'entrepreneur', 'consumer', 'retail', 'wholesale', 'commodity', 'transaction', 'contract', 'revenue', 'tax', 'insurance', 'bond', 'equity', 'derivative'],
    'environment_ecology': ['climate', 'environment', 'ecology', 'carbon', 'emission', 'green', 'renewable', 'sustainable', 'pollution', 'waste', 'recycling', 'biodiversity', 'species', 'forest', 'ocean', 'glacier', 'warming', 'greenhouse', 'fossil fuel', 'coal', 'petroleum', 'solar', 'wind energy', 'conservation', 'ecosystem', 'habitat', 'extinction', 'wildlife', 'rainforest', 'desertification', 'ozone', 'marine', 'wetland', 'endangered'],
    'culture_education': ['culture', 'cultural', 'art', 'literature', 'book', 'novel', 'poem', 'music', 'film', 'theater', 'theatre', 'museum', 'painting', 'sculpture', 'history', 'philosophy', 'religion', 'belief', 'Christian', 'Islamic', 'Buddhist', 'Christianity', 'Islam', 'Buddhism', 'tradition', 'heritage', 'language', 'grammar', 'vocabulary', 'education', 'school', 'university', 'student', 'teacher', 'curriculum', 'academic', 'scholar', 'lecture', 'exam', 'degree'],
    'daily_life': ['food', 'restaurant', 'travel', 'vacation', 'hotel', 'shopping', 'fashion', 'clothing', 'entertainment', 'sport', 'game', 'social media', 'friends', 'family', 'marriage', 'child', 'parent', 'home', 'housing', 'apartment', 'city', 'urban', 'rural', 'community', 'neighborhood', 'celebration', 'festival', 'holiday', 'recipe', 'cooking', 'diet', 'nutrition', 'grocery', 'kitchen', 'bedroom', 'bathroom', 'garden', 'pet', 'hobby'],
    'media_communication': ['media', 'journalism', 'news', 'newspaper', 'magazine', 'broadcast', 'television', 'journalist', 'reporter', 'information', 'communication', 'publishing', 'propaganda', 'censorship', 'freedom of speech', 'documentary', 'podcast', 'streaming', 'editorial', 'headline', 'coverage', 'interview', 'publicity', 'announcement', 'advertisement', 'campaign'],
    'international_relations': ['international', 'foreign', 'alliance', 'NATO', 'UN', 'United Nations', 'global', 'organization', 'summit', 'negotiation', 'conflict resolution', 'humanitarian', 'refugee', 'sanction', 'embargo', 'sovereignty', 'territory', 'border', 'multilateral', 'bilateral', 'diplomacy', 'cooperation', 'coalition', 'bloc', 'sanctions', 'truce']
}

def main():
    print("=" * 80)
    print("ECDict CSV 分类体系深度分析")
    print("=" * 80)
    
    # 读取CSV
    print("\n[1] 正在加载 ecdict.csv...")
    df = pd.read_csv(r'c:\Users\joss1\Desktop\goldene\assets\ecdict\ecdict.csv', 
                     quotechar="'", 
                     engine='python',
                     on_bad_lines='skip')
    
    print(f"    总单词数: {len(df):,}")
    print(f"    字段列表: {list(df.columns)}")
    
    # ===================== 1. 分析 tag 字段 =====================
    print("\n" + "=" * 80)
    print("[2] Tag 字段分析")
    print("=" * 80)
    
    # 收集所有非空的 tag 值
    all_tags = []
    for tag_str in df['tag'].dropna():
        if pd.notna(tag_str) and str(tag_str).strip():
            tags = [t.strip() for t in str(tag_str).split(',')]
            all_tags.extend(tags)
    
    tag_counter = Counter(all_tags)
    print(f"\nTag 唯一值总数: {len(tag_counter)}")
    print("\n所有 Tag 值及其出现次数（按频率排序）:")
    print("-" * 50)
    for tag, count in tag_counter.most_common():
        print(f"  {tag:30s} : {count:6,} 次")
    
    # 按类型分组展示
    print("\n\nTag 分组展示:")
    print("-" * 50)
    
    exam_tags = [t for t in tag_counter if any(x in t.lower() for x in ['cet', 'toefl', 'ielts', 'gre', 'ky', 'zk', 'gk', 'pet', 'grade', 'level'])]
    other_tags = [t for t in tag_counter if t not in exam_tags]
    
    print("\n【考试相关标签】")
    for t in sorted(exam_tags):
        print(f"  {t}: {tag_counter[t]:,}")
    
    print("\n【其他分类标签】")
    for t in sorted(other_tags):
        print(f"  {t}: {tag_counter[t]:,}")
    
    # ===================== 2. 分析各字段结构 =====================
    print("\n" + "=" * 80)
    print("[3] 字段结构分析")
    print("=" * 80)
    
    for col in ['word', 'phonetic', 'definition', 'translation', 'pos', 'collins', 'oxford', 'bnc', 'frq']:
        non_null = df[col].notna().sum()
        null_count = len(df) - non_null
        print(f"\n  {col:15s}: 非空 {non_null:>10,} ({100*non_null/len(df):5.1f}%)  |  空值 {null_count:>10,} ({100*null_count/len(df):5.1f}%)")
    
    # POS 分析
    print("\n\n词性 (pos) 分布:")
    print("-" * 50)
    pos_counter = Counter(df['pos'].dropna().astype(str))
    for pos, count in pos_counter.most_common(20):
        print(f"  {pos:15s} : {count:>10,} 次 ({100*count/len(df):5.2f}%)")
    
    # Collins 星级分析
    print("\n\nCollins 星级分布:")
    print("-" * 50)
    collins_counter = Counter(df['collins'].dropna().astype(int))
    for star, count in sorted(collins_counter.items()):
        print(f"  {star}星 : {count:>10,} 次")
    
    # Oxford 标记分析
    print("\n\nOxford 词典标记分布:")
    print("-" * 50)
    oxford_counter = Counter(df['oxford'].dropna().astype(int))
    for mark, count in oxford_counter.items():
        label = "是牛津词典词汇" if mark == 1 else "否"
        print(f"  {label}: {count:>10,} 次")
    
    # ===================== 3. 语义分类分析 =====================
    print("\n" + "=" * 80)
    print("[4] 语义分类分析")
    print("=" * 80)
    
    domain_words = {domain: [] for domain in DOMAINS}
    
    # 处理 definition 和 translation 字段
    for idx, row in df.iterrows():
        def_text = str(row.get('definition', '')).lower()
        trans_text = str(row.get('translation', '')).lower()
        word = str(row.get('word', ''))
        translation = str(row.get('translation', ''))
        
        # 跳过后缀词
        if word.startswith('-'):
            continue
        
        combined_text = def_text + ' ' + trans_text
        
        for domain, keywords in DOMAINS.items():
            for keyword in keywords:
                if keyword.lower() in combined_text:
                    domain_words[domain].append({
                        'word': word,
                        'translation': translation[:80] + '...' if len(translation) > 80 else translation,
                        'matched_keyword': keyword
                    })
                    break  # 每个词只匹配一次
    
    # 输出每个领域的统计
    domain_stats = []
    for domain, words in domain_words.items():
        domain_stats.append((domain, len(words)))
    
    # 按数量排序
    domain_stats.sort(key=lambda x: x[1], reverse=True)
    
    print("\n【语义领域单词数量排名】")
    print("-" * 60)
    for rank, (domain, count) in enumerate(domain_stats, 1):
        domain_cn = {
            'technology': '科技',
            'science': '科学',
            'medicine_health': '医疗健康',
            'law_politics': '法律政治',
            'military_defense': '军事国防',
            'economics_trade': '经济贸易',
            'environment_ecology': '环境生态',
            'culture_education': '文化教育',
            'daily_life': '日常生活',
            'media_communication': '媒体传播',
            'international_relations': '国际关系'
        }.get(domain, domain)
        print(f"  {rank:2d}. {domain_cn:15s} ({domain:20s}): {count:>6,} 个单词")
    
    # 输出每个领域的完整列表
    print("\n" + "=" * 80)
    print("[5] 各语义领域单词详细列表")
    print("=" * 80)
    
    domain_cn_map = {
        'technology': '科技 (technology)',
        'science': '科学 (science)',
        'medicine_health': '医疗健康 (medicine_health)',
        'law_politics': '法律政治 (law_politics)',
        'military_defense': '军事国防 (military_defense)',
        'economics_trade': '经济贸易 (economics_trade)',
        'environment_ecology': '环境生态 (environment_ecology)',
        'culture_education': '文化教育 (culture_education)',
        'daily_life': '日常生活 (daily_life)',
        'media_communication': '媒体传播 (media_communication)',
        'international_relations': '国际关系 (international_relations)'
    }
    
    for domain, words in sorted(domain_words.items(), key=lambda x: len(x[1]), reverse=True):
        if len(words) == 0:
            continue
            
        print(f"\n\n{'=' * 60}")
        print(f"【{domain_cn_map.get(domain, domain)}】")
        print(f"总数: {len(words)} 个单词")
        print("-" * 60)
        
        # 按单词字母排序
        words_sorted = sorted(words, key=lambda x: x['word'].lower())
        
        # 显示前50个
        display_words = words_sorted[:50]
        for w in display_words:
            trans = w['translation'].replace('\n', ' ')[:60]
            print(f"  {w['word']:25s} | {trans:60s} | 关键词: {w['matched_keyword']}")
        
        if len(words) > 50:
            print(f"\n  ... 还有 {len(words) - 50} 个单词未显示 ...")
    
    # ===================== 4. 词干词频率分析 =====================
    print("\n\n" + "=" * 80)
    print("[6] Definition 字段词干词频率分析 (Top 100)")
    print("=" * 80)
    
    # 提取所有单词
    all_words_in_defs = []
    for def_text in df['definition'].dropna():
        # 提取英文单词
        words = re.findall(r'[a-zA-Z]{4,}', str(def_text).lower())
        all_words_in_defs.extend(words)
    
    # 常见停用词
    stopwords = {
        'that', 'this', 'with', 'from', 'have', 'been', 'were', 'they',
        'which', 'when', 'where', 'whose', 'about', 'their', 'there',
        'would', 'could', 'should', 'into', 'also', 'more', 'such',
        'than', 'them', 'then', 'some', 'only', 'over', 'under',
        'between', 'through', 'during', 'before', 'after', 'against',
        'toward', 'towards', 'within', 'without', 'towards', 'another',
        'being', 'became', 'making', 'made', 'having', 'having', 'having',
        'often', 'usually', 'especially', 'particularly', 'generally',
        'including', 'according', 'following', 'certain', 'various',
        'different', 'similar', 'possible', 'actual', 'existing',
        'following', 'related', 'required', 'provided', 'given'
    }
    
    # 过滤停用词并统计
    filtered_words = [w for w in all_words_in_defs if w not in stopwords]
    word_freq = Counter(filtered_words)
    
    print("\nTop 100 高频词干词:")
    print("-" * 50)
    for i, (word, count) in enumerate(word_freq.most_common(100), 1):
        if i % 5 == 1:
            print()
        print(f"  {i:3d}. {word:20s} ({count:>8,})", end="")
        if i % 5 == 0:
            print()
    
    # ===================== 5. 分类建议 =====================
    print("\n\n" + "=" * 80)
    print("[7] 语义分类建议")
    print("=" * 80)
    
    print("""
基于以上分析，提出以下分类建议：

1. 【tag 字段优化建议】
   - 现有标签以考试分类为主（cet4/cet6/toefl/ielts/gre/ky/zk/gk等）
   - 建议增加领域分类标签，如：academic, business, legal, medical, technical
   
2. 【高频领域词干词】
   - scientific, political, economic, social, cultural, historical
   - psychological, biological, chemical, physical, mathematical
   - medical, legal, commercial, industrial, agricultural
   
3. 【领域交叉词】
   很多单词同时属于多个领域，建议：
   - 建立多标签分类体系
   - 使用权重区分主次领域
   - 考虑词义上下文
   
4. 【细分领域建议】
   在现有大类基础上，可细分为：
   - 法律 → 民法/刑法/商法/国际法
   - 医学 → 内科/外科/儿科/精神病学
   - 经济 → 宏观经济/微观经济/国际贸易/金融
   - 科技 → 人工智能/网络安全/数据分析/云计算
""")
    
    # ===================== 6. 保存结果 =====================
    print("\n" + "=" * 80)
    print("[8] 保存详细结果")
    print("=" * 80)
    
    # 保存语义分类结果到文件
    with open(r'c:\Users\joss1\Desktop\goldene\analysis_results.txt', 'w', encoding='utf-8') as f:
        f.write("ECDict 语义分类详细结果\n")
        f.write("=" * 80 + "\n\n")
        
        for domain, words in sorted(domain_words.items(), key=lambda x: len(x[1]), reverse=True):
            if len(words) == 0:
                continue
            
            f.write(f"\n【{domain_cn_map.get(domain, domain)}】\n")
            f.write(f"总数: {len(words)} 个单词\n")
            f.write("-" * 60 + "\n")
            
            words_sorted = sorted(words, key=lambda x: x['word'].lower())
            for w in words_sorted:
                f.write(f"  {w['word']} | {w['translation']}\n")
            
            f.write("\n")
    
    print("  已保存到: c:\\Users\\joss1\\Desktop\\goldene\\analysis_results.txt")
    
    # 保存 tag 分析结果
    with open(r'c:\Users\joss1\Desktop\goldene\tag_analysis.txt', 'w', encoding='utf-8') as f:
        f.write("ECDict Tag 字段分析\n")
        f.write("=" * 80 + "\n\n")
        f.write(f"Tag 唯一值总数: {len(tag_counter)}\n\n")
        f.write("所有 Tag 值及其出现次数（按频率排序）:\n")
        f.write("-" * 50 + "\n")
        for tag, count in tag_counter.most_common():
            f.write(f"  {tag:30s} : {count:6,} 次\n")
    
    print("  已保存到: c:\\Users\\joss1\\Desktop\\goldene\\tag_analysis.txt")
    
    # 保存词干词频率
    with open(r'c:\Users\joss1\Desktop\goldene\word_stem_freq.txt', 'w', encoding='utf-8') as f:
        f.write("ECDict Definition 字段词干词频率分析\n")
        f.write("=" * 80 + "\n\n")
        f.write("Top 200 高频词干词:\n")
        f.write("-" * 50 + "\n")
        for i, (word, count) in enumerate(word_freq.most_common(200), 1):
            f.write(f"  {i:4d}. {word:25s} ({count:>10,} 次)\n")
    
    print("  已保存到: c:\\Users\\joss1\\Desktop\\goldene\\word_stem_freq.txt")
    
    print("\n分析完成！")
    print("=" * 80)

if __name__ == "__main__":
    main()
