#!/usr/bin/env python3
"""
分析最近两天src/目录的有效代码行数变化并生成折线图（优化版）
使用多进程并行处理提升性能
"""

import subprocess
import re
from datetime import datetime
import json
import os
import matplotlib
matplotlib.use('Agg')  # 非交互式后端，避免GUI开销
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from concurrent.futures import ProcessPoolExecutor, as_completed
from functools import partial
import multiprocessing

# 全局缓存git根目录
_GIT_ROOT = None

def run_cmd(cmd, check=True):
    """执行shell命令并返回输出"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        return ""
    return result.stdout.strip()

def get_git_root():
    """获取git仓库根目录（带缓存）"""
    global _GIT_ROOT
    if _GIT_ROOT is None:
        _GIT_ROOT = run_cmd('git rev-parse --show-toplevel', check=False)
    return _GIT_ROOT

def get_commits():
    """获取最近两天的所有提交（按时间正序）"""
    cmd = 'git log --since="2 days ago" --format="%H|%ci|%s" --reverse'
    output = run_cmd(cmd)
    commits = []
    for line in output.split('\n'):
        if '|' in line:
            parts = line.split('|', 2)
            if len(parts) == 3:
                commits.append({
                    'hash': parts[0][:8],
                    'full_hash': parts[0],
                    'date': parts[1],
                    'message': parts[2]
                })
    return commits

def count_loc_at_commit_optimized(commit_info):
    """
    优化的LOC计算 - 使用shell pipeline批量处理
    返回 (commit_info, loc, file_count)
    """
    commit_hash = commit_info['full_hash']

    # 使用单个命令获取所有代码文件的LOC统计
    # 1. 获取文件列表 2. 对每个文件统计有效行数（排除空行和注释行）
    cmd = f'''
    git ls-tree -r --name-only {commit_hash} 2>/dev/null | grep "^src/" | grep -E "\\.(lua|ts|js|tsx|jsx|py)$" | while read f; do
        git show {commit_hash}:"$f" 2>/dev/null | \
        grep -v '^[[:space:]]*$' | \
        grep -v '^[[:space:]]*--' | \
        grep -v '^[[:space:]]*//' | \
        grep -v '^[[:space:]]*#' | \
        wc -l
    done | awk '{{sum+=$1; count++}} END {{print sum, count}}'
    '''

    result = run_cmd(cmd, check=False)

    if result:
        parts = result.split()
        if len(parts) == 2:
            try:
                total_loc = int(parts[0])
                file_count = int(parts[1])
                return (commit_info, total_loc, file_count)
            except ValueError:
                pass

    # 如果失败，回退到逐个文件处理
    return _count_loc_fallback(commit_info)

def _count_loc_fallback(commit_info):
    """回退方法：逐个文件处理"""
    commit_hash = commit_info['full_hash']
    cmd = f'git ls-tree -r --name-only {commit_hash} | grep "^src/" | grep -E "\\.(lua|ts|js|tsx|jsx|py)$"'
    output = run_cmd(cmd, check=False)

    if not output:
        return (commit_info, 0, 0)

    total_loc = 0
    file_count = 0

    for filepath in output.split('\n'):
        if not filepath:
            continue

        content_cmd = f'git show {commit_hash}:"{filepath}" 2>/dev/null'
        content = run_cmd(content_cmd, check=False)

        if not content:
            continue

        # 简化的LOC计算
        loc = 0
        in_multiline_comment = False

        for line in content.split('\n'):
            line = line.strip()
            if not line:
                continue

            # 处理Lua多行注释
            if '--[[' in line:
                if ']]--' in line or ']]' in line:
                    comment_start = line.index('--[[')
                    comment_end = line.find(']]--', comment_start)
                    if comment_end == -1:
                        comment_end = line.find(']]', comment_start)
                    if comment_end != -1:
                        line = line[:comment_start] + line[comment_end+2:]
                        line = line.strip()
                        if not line:
                            continue
                else:
                    in_multiline_comment = True
                    if line.startswith('--[['):
                        continue
                    line = line[:line.index('--[[')].strip()
                    if not line:
                        continue

            if in_multiline_comment:
                if ']]--' in line:
                    in_multiline_comment = False
                    line = line[line.index(']]--')+4:].strip()
                    if not line:
                        continue
                elif ']]' in line:
                    in_multiline_comment = False
                    line = line[line.index(']]')+2:].strip()
                    if not line:
                        continue
                else:
                    continue

            if line.startswith('--') or line.startswith('//') or line.startswith('#'):
                continue

            loc += 1

        total_loc += loc
        file_count += 1

    return (commit_info, total_loc, file_count)

def parse_datetime(date_str):
    """解析git日期格式"""
    return datetime.strptime(date_str[:19], "%Y-%m-%d %H:%M:%S")

def generate_chart(data, output_path='loc_trend.png'):
    """生成折线图"""
    # 设置支持中文的字体
    chinese_fonts = ['SimHei', 'Microsoft YaHei', 'PingFang SC', 'Heiti SC', 'Arial Unicode MS', 'WenQuanYi Micro Hei']
    for font in chinese_fonts:
        try:
            plt.rcParams['font.sans-serif'] = [font] + plt.rcParams['font.sans-serif']
            plt.rcParams['axes.unicode_minus'] = False
            break
        except:
            continue

    dates = [parse_datetime(d['date']) for d in data]
    locs = [d['loc'] for d in data]

    fig, ax = plt.subplots(figsize=(16, 8))
    ax.plot(dates, locs, marker='o', markersize=4, linewidth=1.5, color='#2E86AB')
    ax.fill_between(dates, locs, alpha=0.3, color='#2E86AB')

    ax.set_title('src/ Directory LOC Trend (Last 2 Days)', fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel('Commit Time', fontsize=12)
    ax.set_ylabel('Lines of Code (LOC)', fontsize=12)

    ax.xaxis.set_major_formatter(mdates.DateFormatter('%m-%d %H:%M'))
    ax.xaxis.set_major_locator(mdates.HourLocator(interval=3))
    plt.xticks(rotation=45, ha='right')
    ax.grid(True, linestyle='--', alpha=0.7)

    if locs:
        min_loc = min(locs)
        max_loc = max(locs)
        margin = (max_loc - min_loc) * 0.1
        ax.set_ylim(bottom=min_loc - margin, top=max_loc + margin)

        start_loc = locs[0]
        end_loc = locs[-1]
        change = end_loc - start_loc

        stats_text = f"Start: {start_loc:,} lines\n"
        stats_text += f"End: {end_loc:,} lines\n"
        stats_text += f"Change: {change:+,} ({change/start_loc*100:.1f}%)\n"
        stats_text += f"Max: {max_loc:,} lines\n"
        stats_text += f"Min: {min_loc:,} lines\n"
        stats_text += f"Commits: {len(data)}"

        ax.text(0.02, 0.98, stats_text, transform=ax.transAxes,
                fontsize=10, verticalalignment='top',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"图表已保存到: {os.path.abspath(output_path)}")
    plt.close(fig)

def main():
    import time
    start_time = time.time()

    print("=" * 60)
    print("src/目录有效代码行数变化分析（优化版）")
    print("=" * 60)

    print("\n正在获取最近两天的提交...")
    commits = get_commits()
    total = len(commits)
    print(f"共找到 {total} 个提交")

    if total == 0:
        print("没有找到最近两天的提交！")
        return

    print(f"\n开始并行分析每个提交的代码行数（使用 {min(8, multiprocessing.cpu_count())} 个进程）...")
    print("-" * 60)

    # 使用进程池并行处理
    data = []
    processed = 0

    with ProcessPoolExecutor(max_workers=min(8, multiprocessing.cpu_count())) as executor:
        future_to_commit = {
            executor.submit(count_loc_at_commit_optimized, commit): commit
            for commit in commits
        }

        for future in as_completed(future_to_commit):
            commit_info, loc, file_count = future.result()
            processed += 1

            data.append({
                'hash': commit_info['hash'],
                'date': commit_info['date'],
                'message': commit_info['message'],
                'loc': loc,
                'files': file_count
            })

            print(f"[{processed:3d}/{total:3d}] {commit_info['hash']} | "
                  f"LOC: {loc:5d} | Files: {file_count:3d} | {commit_info['message'][:40]}")

    # 按原始顺序排序
    data.sort(key=lambda x: next(i for i, c in enumerate(commits) if c['hash'] == x['hash']))

    print("-" * 60)

    # 输出到脚本所在目录
    output_dir = os.path.dirname(os.path.abspath(__file__))

    # 保存JSON数据
    json_path = os.path.join(output_dir, 'loc_data.json')
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"\n数据已保存到: {json_path}")

    # 生成折线图到根目录
    print("\n正在生成折线图...")
    chart_path = os.path.join(output_dir, 'loc_trend.png')
    generate_chart(data, chart_path)

    elapsed = time.time() - start_time

    # 输出摘要
    print("\n" + "=" * 60)
    print("Analysis Summary")
    print("=" * 60)
    if data:
        start = data[0]
        end = data[-1]
        change = end['loc'] - start['loc']
        print(f"Period: {start['date'][:10]} ~ {end['date'][:10]}")
        print(f"Start LOC: {start['loc']:,} lines")
        print(f"End LOC: {end['loc']:,} lines")
        print(f"Net Change: {change:+,} lines ({change/start['loc']*100:.1f}%)")
        print(f"Commits Analyzed: {len(data)}")
    print(f"Elapsed Time: {elapsed:.1f}s")

if __name__ == '__main__':
    main()
