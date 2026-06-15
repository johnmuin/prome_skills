#!/usr/bin/env python3
"""
mpa2levels_standalone.py
把 kreport2mpa / combine_mpa 输出的 mpa 表按层级拆成 L1.txt ~ L8.txt
- 行为与原 R 版 mpa2levels.R 完全一致
- 跳过 0 行: 输入来自 kreport2mpa.py --display-header, 首行 "#Classification\t<sample>"
- 跳过 1 行: 输入来自 combine_mpa.py, 首行 "Classification\tS1\tS2\t..."
- 无 R 依赖

用法: python mpa2levels_standalone.py <input.mpa> <out_dir>
"""

import os
import sys


def main():
    if len(sys.argv) < 3:
        print("Usage: python mpa2levels_standalone.py <input.mpa> <out_dir>",
              file=sys.stderr)
        sys.exit(1)

    mpa_file = sys.argv[1]
    out_dir = sys.argv[2]

    os.makedirs(out_dir, exist_ok=True)

    with open(mpa_file) as f:
        lines = [l.rstrip('\n') for l in f if l.strip()]

    if not lines:
        print(f"[FATAL] 空 mpa 文件: {mpa_file}", file=sys.stderr)
        sys.exit(1)

    # 检测首行是否是 header
    # kreport2mpa --display-header: "#Classification\tSAMPLE"
    # combine_mpa:               "Classification\tS1\tS2\t..."
    # 无 header (直接 kreport2mpa): 首行以 k__/d__ 开头
    first = lines[0]
    if first.startswith('k__') or first.startswith('d__'):
        col_names = ["value"]
        data_lines = lines
    else:
        header_parts = first.split('\t')
        if len(header_parts) >= 2:
            # 把第一列 "Classification"/"#Classification" 之外的全取作样本名
            col_names = [h.lstrip('#').strip() for h in header_parts[1:]]
        else:
            col_names = ["value"]
        data_lines = lines[1:]

    # 解析数据: 每行 "<lineage>\t<c1>\t<c2>\t..."
    rows = []
    for line in data_lines:
        parts = line.split('\t')
        if len(parts) < 2:
            continue
        lineage = parts[0]
        try:
            counts = [float(p) for p in parts[1:]]
        except ValueError:
            continue
        # 把 | 换成 ;  (与 R 版 gsub('[|]',';',...) 一致)
        lineage_fmt = lineage.replace('|', ';')
        rows.append((lineage_fmt, counts))

    # 按层级拆分, 沿用 R 版的 level 顺序
    levels = ['p__', 'c__', 'o__', 'f__', 'g__', 's__', 't__']

    for i, level in enumerate(levels, start=1):
        with_level = [r for r in rows if level in r[0]]
        without_level = [r for r in rows if level not in r[0]]
        out_path = os.path.join(out_dir, f"L{i}.txt")
        with open(out_path, 'w') as fo:
            fo.write("FeatureID\t" + "\t".join(col_names) + "\n")
            for lineage, counts in without_level:
                fo.write(lineage + "\t" + "\t".join(str(c) for c in counts) + "\n")
        rows = with_level

    # L{len(levels)+1}.txt: 含 t__ 的行 (亚种/株级)
    out_path = os.path.join(out_dir, f"L{len(levels) + 1}.txt")
    with open(out_path, 'w') as fo:
        fo.write("FeatureID\t" + "\t".join(col_names) + "\n")
        for lineage, counts in rows:
            fo.write(lineage + "\t" + "\t".join(str(c) for c in counts) + "\n")

    print(f"[mpa2levels] done -> {out_dir}", file=sys.stderr)


if __name__ == "__main__":
    main()
