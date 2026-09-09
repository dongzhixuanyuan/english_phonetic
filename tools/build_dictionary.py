#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_dictionary.py
从开源词典 ECDICT (https://github.com/skywind3000/ECDICT) 编译生成用于移动端的高性能 SQLite 词典数据库。
特性：
1. 提取所有具备音标的词汇以及全部核心大纲/考试/词频词汇（约 26 万条）。
2. 解析 exchange 字段（0:lemma 词元关系），为变体形态词（如复数、过去式）自动继承词元音标。
3. 音标标准化：将 ASCII 引号（' 和 ,）转换为标准国际音标重音符号（ˈ 和 ˌ），统一包裹 /.../。
4. 释义格式化：清洗多余换行与生僻学术标记，适配移动端气泡展示。
5. 生成包含 word 主键索引（COLLATE NOCASE）的 SQLite 数据库。
"""

import csv
import sqlite3
import os
import sys
import urllib.request
import re

ECDICT_CSV_URL = "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv"

def download_if_needed(csv_path):
    if os.path.exists(csv_path) and os.path.getsize(csv_path) > 10 * 1024 * 1024:
        print(f"📖 使用现有的 CSV 文件: {csv_path} ({os.path.getsize(csv_path)/1024/1024:.1f} MB)")
        return
    print(f"⬇️ 正在下载 ecdict.csv 至 {csv_path} ...")
    req = urllib.request.Request(ECDICT_CSV_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp, open(csv_path, "wb") as out:
        total = int(resp.headers.get("Content-Length", 0))
        downloaded = 0
        while True:
            chunk = resp.read(1024 * 1024)
            if not chunk:
                break
            out.write(chunk)
            downloaded += len(chunk)
            if total:
                print(f"\r进度: {downloaded/1024/1024:.1f} MB / {total/1024/1024:.1f} MB ({downloaded*100/total:.1f}%)", end="")
            else:
                print(f"\r已下载: {downloaded/1024/1024:.1f} MB", end="")
    print("\n✅ 下载完成！")

def normalize_phonetic(p):
    if not p:
        return ""
    p = p.strip()
    if p.startswith("/") and p.endswith("/"):
        p = p[1:-1]
    res = []
    for ch in p:
        if ch == "'":
            res.append("ˈ")
        elif ch == ",":
            res.append("ˌ")
        else:
            res.append(ch)
    return f"/{''.join(res)}/"

def clean_meaning(trans):
    if not trans:
        return ""
    # 1. 拆分换行（ECDICT CSV 中换行通常直接代表不同词性）
    trans = trans.replace("\\r", "").replace("\r", "")
    raw_lines = [l.strip() for l in trans.split("\\n") if l.strip()]
    
    # 过滤掉次要学科/网络专业标签行（如 [网络]、[计]、[医] 等），若无其它释义则保留
    main_lines = [l for l in raw_lines if not re.match(r"^\[(网络|计|医|化|法|经|机|电|生|数|物|地)\]", l)]
    lines = main_lines if main_lines else raw_lines
    
    # 2. 如果单行内通过分号分隔了不同词性（如 "a. 快速的；adv. 很快地；n. 绝食"），进一步按词性标记拆分
    pos_split_pattern = re.compile(r"[；;]\s*(?=[a-zA-Z]+\.\s+|pl\.\s+|aux\.\s+|abbr\.\s+)")
    split_lines = []
    for line in lines:
        for part in pos_split_pattern.split(line):
            part = part.strip()
            if part:
                split_lines.append(part)
                
    # 3. 对每个词性行进行精简修剪
    cleaned_lines = []
    for l in split_lines:
        l = l.strip("；; \t")
        if not l:
            continue
        if len(l) > 42:
            l = l[:40] + "..."
        cleaned_lines.append(l)
        
    # 最多保留 4 个主要词性行，避免气泡过长
    if len(cleaned_lines) > 4:
        cleaned_lines = cleaned_lines[:4]
        
    return "\n".join(cleaned_lines)

def build_database(csv_path, output_db_path):
    print(f"🚀 开始编译词典数据库: {output_db_path}")
    if os.path.exists(output_db_path):
        os.remove(output_db_path)

    os.makedirs(os.path.dirname(os.path.abspath(output_db_path)), exist_ok=True)

    # 1. 扫描阶段：收集音标和 lemma 映射
    print("🔍 阶段 1/3: 扫描词典收集音标与词元映射 (Lemmas)...")
    ecdict_phonetics = {}
    ecdict_lemmas = {}

    with open(csv_path, "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            w = row["word"].strip().lower()
            p = row["phonetic"].strip()
            ex = row["exchange"].strip()
            if p:
                ecdict_phonetics[w] = p
            if ex and "0:" in ex:
                for part in ex.split("/"):
                    if part.startswith("0:"):
                        ecdict_lemmas[w] = part[2:].strip().lower()
                        break

    print(f"   已收录直标音标词: {len(ecdict_phonetics)} 个，词元派生关系: {len(ecdict_lemmas)} 个")

    # 2. 数据库构建阶段
    print("💾 阶段 2/3: 筛选高频大纲词汇并注入 SQLite...")
    conn = sqlite3.connect(output_db_path)
    cur = conn.cursor()
    cur.execute("PRAGMA page_size = 4096")
    cur.execute("PRAGMA journal_mode = OFF")
    cur.execute("PRAGMA synchronous = OFF")
    cur.execute("""
    CREATE TABLE dictionary (
        word TEXT PRIMARY KEY COLLATE NOCASE,
        phonetic TEXT,
        meaning TEXT
    )
    """)

    inserted = set()
    batch = []
    recovered_phonetic_count = 0

    with open(csv_path, "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            w = row["word"].strip()
            key = w.lower()
            if not key or key in inserted:
                continue

            p = row["phonetic"].strip()
            t = row["translation"].strip()
            col = int(row["collins"]) if row["collins"].isdigit() else 0
            ox = int(row["oxford"]) if row["oxford"].isdigit() else 0
            tag = row["tag"].strip()
            frq = int(row["frq"]) if row["frq"].isdigit() else 0
            bnc = int(row["bnc"]) if row["bnc"].isdigit() else 0
            has_lemma = key in ecdict_lemmas

            # 若变体词自身缺失音标，从原型（lemma）补全
            if not p and has_lemma:
                lemma = ecdict_lemmas[key]
                if lemma in ecdict_phonetics:
                    p = ecdict_phonetics[lemma]
                    recovered_phonetic_count += 1

            # 筛选：有音标 或 位于考试标签/牛津/柯林斯/常用词频/派生词
            keep = bool(p) or col > 0 or ox > 0 or bool(tag) or (frq > 0 and frq < 120000) or (bnc > 0 and bnc < 120000) or has_lemma
            if not keep:
                continue

            norm_p = normalize_phonetic(p)
            clean_m = clean_meaning(t)
            if not norm_p and not clean_m:
                continue

            batch.append((key, norm_p, clean_m))
            inserted.add(key)

            if len(batch) >= 10000:
                cur.executemany("INSERT OR IGNORE INTO dictionary VALUES (?, ?, ?)", batch)
                batch = []

    if batch:
        cur.executemany("INSERT OR IGNORE INTO dictionary VALUES (?, ?, ?)", batch)

    print("⚡ 阶段 3/3: 提交事务与执行 VACUUM 优化压缩...")
    conn.commit()
    cur.execute("VACUUM")
    conn.close()

    size_mb = os.path.getsize(output_db_path) / (1024 * 1024)
    print(f"🎉 编译完成！")
    print(f"   入库总词条数: {len(inserted):,} 条")
    print(f"   变体补齐音标数: {recovered_phonetic_count:,} 条")
    print(f"   数据库文件体积: {size_mb:.2f} MB")
    print(f"   输出路径: {output_db_path}")

def main():
    default_csv = "/tmp/ecdict.csv"
    default_output = os.path.join(os.path.dirname(__file__), "../ios/EnglishPhoneticApp/Resources/phonetic_dictionary.db")
    
    csv_path = sys.argv[1] if len(sys.argv) > 1 else default_csv
    output_path = sys.argv[2] if len(sys.argv) > 2 else default_output

    download_if_needed(csv_path)
    build_database(csv_path, output_path)

if __name__ == "__main__":
    main()
