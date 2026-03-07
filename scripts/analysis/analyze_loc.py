#!/usr/bin/env python3
"""
分析最近两天 src/ 和 tests/ 目录的有效代码行数变化并生成折线图（优化版）
使用多进程并行处理提升性能，src/ 和 tests/ 分开统计和展示
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

def count_loc_for_dir(commit_hash, dir_name):
    """
    统计指定目录的LOC
    返回 (loc, file_count)
    """
    cmd = f'npx cloc --json {commit_hash} --match-d={dir_name} 2>/dev/null'
    result = run_cmd(cmd, check=False)

    total_loc = 0
    file_count = 0

    if result:
        try:
            json_start = result.find('{')
            if json_start != -1:
                json_str = result[json_start:]
                data = json.loads(json_str)
                if 'SUM' in data:
                    total_loc = data['SUM']['code']
                    file_count = data['SUM']['nFiles']
        except Exception:
            pass

    return total_loc, file_count


def count_loc_at_commit_optimized(commit_info):
    """
    优化的LOC计算 - 分别统计src/和tests/目录
    返回 (commit_info, src_loc, src_files, tests_loc, tests_files)
    """
    commit_hash = commit_info['full_hash']

    src_loc, src_files = count_loc_for_dir(commit_hash, 'src')
    tests_loc, tests_files = count_loc_for_dir(commit_hash, 'tests')

    return (commit_info, src_loc, src_files, tests_loc, tests_files)

def parse_datetime(date_str):
    """解析git日期格式"""
    return datetime.strptime(date_str[:19], "%Y-%m-%d %H:%M:%S")

def generate_chart(data, output_path='loc_trend.png'):
    """生成折线图 - 分别展示src/和tests/"""
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
    src_locs = [d['src_loc'] for d in data]
    tests_locs = [d['tests_loc'] for d in data]

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(16, 12))

    # src/ 目录图表
    ax1.plot(dates, src_locs, marker='o', markersize=4, linewidth=1.5, color='#2E86AB', label='src/')
    ax1.fill_between(dates, src_locs, alpha=0.3, color='#2E86AB')
    ax1.set_title('src/ Directory LOC Trend (Last 2 Days)', fontsize=14, fontweight='bold', pad=15)
    ax1.set_ylabel('Lines of Code (LOC)', fontsize=11)
    ax1.xaxis.set_major_formatter(mdates.DateFormatter('%m-%d %H:%M'))
    ax1.xaxis.set_major_locator(mdates.HourLocator(interval=3))
    ax1.tick_params(axis='x', rotation=45)
    ax1.grid(True, linestyle='--', alpha=0.7)
    ax1.legend(loc='upper left')

    if src_locs:
        min_loc = min(src_locs)
        max_loc = max(src_locs)
        start_loc = src_locs[0]
        end_loc = src_locs[-1]
        change = end_loc - start_loc
        margin = (max_loc - min_loc) * 0.1 if max_loc != min_loc else end_loc * 0.1
        ax1.set_ylim(bottom=max(0, min_loc - margin), top=max_loc + margin)

        stats_text = f"Start: {start_loc:,} | End: {end_loc:,} | Change: {change:+,} ({change/start_loc*100:.1f}%)"
        ax1.text(0.02, 0.98, stats_text, transform=ax1.transAxes,
                fontsize=9, verticalalignment='top',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    # tests/ 目录图表
    ax2.plot(dates, tests_locs, marker='s', markersize=4, linewidth=1.5, color='#A23B72', label='tests/')
    ax2.fill_between(dates, tests_locs, alpha=0.3, color='#A23B72')
    ax2.set_title('tests/ Directory LOC Trend (Last 2 Days)', fontsize=14, fontweight='bold', pad=15)
    ax2.set_xlabel('Commit Time', fontsize=11)
    ax2.set_ylabel('Lines of Code (LOC)', fontsize=11)
    ax2.xaxis.set_major_formatter(mdates.DateFormatter('%m-%d %H:%M'))
    ax2.xaxis.set_major_locator(mdates.HourLocator(interval=3))
    ax2.tick_params(axis='x', rotation=45)
    ax2.grid(True, linestyle='--', alpha=0.7)
    ax2.legend(loc='upper left')

    if tests_locs:
        min_loc = min(tests_locs)
        max_loc = max(tests_locs)
        start_loc = tests_locs[0]
        end_loc = tests_locs[-1]
        change = end_loc - start_loc
        margin = (max_loc - min_loc) * 0.1 if max_loc != min_loc else end_loc * 0.1
        ax2.set_ylim(bottom=max(0, min_loc - margin), top=max_loc + margin)

        stats_text = f"Start: {start_loc:,} | End: {end_loc:,} | Change: {change:+,} ({change/start_loc*100:.1f}%)"
        ax2.text(0.02, 0.98, stats_text, transform=ax2.transAxes,
                fontsize=9, verticalalignment='top',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"图表已保存到: {os.path.abspath(output_path)}")
    plt.close(fig)

def main():
    import time
    start_time = time.time()

    print("=" * 60)
    print("src/ 和 tests/ 目录有效代码行数变化分析（优化版）")
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
            commit_info, src_loc, src_files, tests_loc, tests_files = future.result()
            processed += 1

            data.append({
                'hash': commit_info['hash'],
                'date': commit_info['date'],
                'message': commit_info['message'],
                'src_loc': src_loc,
                'src_files': src_files,
                'tests_loc': tests_loc,
                'tests_files': tests_files,
                'total_loc': src_loc + tests_loc,
                'total_files': src_files + tests_files
            })

            print(f"[{processed:3d}/{total:3d}] {commit_info['hash']} | "
                  f"src: {src_loc:5d} lines/{src_files:3d} files | "
                  f"tests: {tests_loc:5d} lines/{tests_files:3d} files | "
                  f"{commit_info['message'][:30]}")

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
        print(f"Period: {start['date'][:10]} ~ {end['date'][:10]}")
        print(f"Commits Analyzed: {len(data)}")
        print("")
        print("src/ Directory:")
        src_change = end['src_loc'] - start['src_loc']
        print(f"  Start: {start['src_loc']:,} lines  |  End: {end['src_loc']:,} lines")
        print(f"  Change: {src_change:+,} lines ({src_change/start['src_loc']*100:.1f}%)")
        print("")
        print("tests/ Directory:")
        tests_change = end['tests_loc'] - start['tests_loc']
        print(f"  Start: {start['tests_loc']:,} lines  |  End: {end['tests_loc']:,} lines")
        if start['tests_loc'] > 0:
            print(f"  Change: {tests_change:+,} lines ({tests_change/start['tests_loc']*100:.1f}%)")
        else:
            print(f"  Change: {tests_change:+,} lines")
        print("")
        print(f"Total (src + tests): {end['total_loc']:,} lines")
    print(f"Elapsed Time: {elapsed:.1f}s")

if __name__ == '__main__':
    main()
