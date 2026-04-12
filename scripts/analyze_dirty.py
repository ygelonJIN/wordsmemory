#!/usr/bin/env python3
import csv

CSV_PATH = r"C:\Users\joss1\Desktop\ECDICT-master\ecdict.csv"

patterns = {
    'starts_dash': [],
    'starts_quote': [],
    'has_space': [],
    'no_alpha': [],
    'starts_digit': [],
    'underscore_in_word': [],
    'only_punct': [],
}

short_no_freq = []
short_valid = []

with open(CSV_PATH, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        word = row.get('word', '').strip()
        if not word:
            continue
        bnc = row.get('bnc', '0').strip() or '0'
        frq = row.get('frq', '0').strip() or '0'
        tag = row.get('tag', '').strip()
        has_alpha = any(c.isalpha() for c in word)

        if word.startswith('-'):
            patterns['starts_dash'].append(word)
        elif word.startswith("'"):
            patterns['starts_quote'].append(word)
        elif ' ' in word:
            patterns['has_space'].append(word)
        elif not has_alpha:
            patterns['no_alpha'].append(word)
        elif word[0].isdigit():
            patterns['starts_digit'].append(word)
        elif '_' in word:
            patterns['underscore_in_word'].append(word)
        elif all(not c.isalnum() for c in word):
            patterns['only_punct'].append(word)

        if len(word) <= 3 and has_alpha and not word.startswith('-') and not word.startswith("'"):
            if bnc == '0' and frq == '0' and tag == '':
                short_no_freq.append(word)
            else:
                short_valid.append(word)

for k, v in patterns.items():
    print(f'{k}: {len(v)}')
    for ex in v[:3]:
        print(f'  {repr(ex)}')
    if len(v) > 3:
        print('  ...')

print()
print(f'short_no_freq: {len(short_no_freq)}')
for ex in short_no_freq[:30]:
    print(f'  {repr(ex)}')

print()
print(f'short_valid: {len(short_valid)}')
for ex in short_valid[:30]:
    print(f'  {repr(ex)}')