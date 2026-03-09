#!/usr/bin/env python3
"""
分析最近三天 src/ 和 tests/ 目录的有效代码行数变化并生成折线图（跨平台版）
支持 Windows 和 macOS，使用多线程并行处理提升性能
"""

import subprocess
import sys
from datetime import datetime
import json
import os
import platform
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

# 尝试导入 matplotlib
HAS_MATPLOTLIB = False
try:
    import matplotlib
    matplotlib.use('Agg')  # 非交互式后端
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    HAS_MATPLOTLIB = True
except ImportError:
    pass

# 全局缓存
cache_lock = threading.Lock()
_GIT_ROOT = None


def run_cmd(cmd, cwd=None):
    """执行命令并返回输出（跨平台兼容）"""
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='ignore'
        )
        return result.stdout.strip()
    except Exception:
        return ""


def get_git_root():
    """获取git仓库根目录（带缓存）"""
    global _GIT_ROOT
    with cache_lock:
        if _GIT_ROOT is None:
            _GIT_ROOT = run_cmd(['git', 'rev-parse', '--show-toplevel'])
        return _GIT_ROOT


def get_commits():
    """获取最近三天的所有提交（按时间正序）"""
    cmd = ['git', 'log', '--since=3 days ago', '--format=%H|%ci|%s', '--reverse']
    output = run_cmd(cmd)
    commits = []
    for line in output.split('\n'):
        line = line.strip()
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


def get_lua_effective_line_count(content):
    """统计 Lua 文件的有效代码行数"""
    if not content:
        return 0

    lines = content.split('\n')
    effective_line_count = 0
    in_block_comment = False

    for line in lines:
        current_line = line

        while True:
            if in_block_comment:
                end_idx = current_line.find(']]')
                if end_idx < 0:
                    current_line = ""
                    break
                current_line = current_line[end_idx + 2:]
                in_block_comment = False
                continue

            block_start_idx = current_line.find('--[[')
            line_comment_idx = current_line.find('--')

            if line_comment_idx < 0:
                break

            if block_start_idx >= 0 and block_start_idx == line_comment_idx:
                before_comment = current_line[:block_start_idx]
                block_end_idx = current_line.find(']]', block_start_idx + 4)

                if block_end_idx >= 0:
                    current_line = before_comment + current_line[block_end_idx + 2:]
                    continue

                current_line = before_comment
                in_block_comment = True
                break

            current_line = current_line[:line_comment_idx]
            break

        if current_line.strip():
            effective_line_count += 1

    return effective_line_count


def count_loc_for_dir(commit_hash, dir_name, git_root):
    """
    统计指定目录的LOC
    返回 (loc, file_count)
    """
    # 获取文件列表
    cmd = ['git', 'ls-tree', '-r', '--name-only', commit_hash, f'{dir_name}/']
    files_output = run_cmd(cmd, cwd=git_root)

    total_loc = 0
    file_count = 0

    if files_output:
        files = [f.strip() for f in files_output.split('\n') if f.strip()]
        lua_files = [f for f in files if f.endswith('.lua')]

        for file_path in lua_files:
            # 获取文件内容
            content_cmd = ['git', 'show', f'{commit_hash}:{file_path}']
            content = run_cmd(content_cmd, cwd=git_root)
            if content:
                total_loc += get_lua_effective_line_count(content)
                file_count += 1

    return total_loc, file_count


def count_loc_at_commit(commit_info, git_root):
    """
    统计单个提交的LOC
    返回字典包含统计结果
    """
    commit_hash = commit_info['full_hash']

    src_loc, src_files = count_loc_for_dir(commit_hash, 'src', git_root)
    tests_loc, tests_files = count_loc_for_dir(commit_hash, 'tests', git_root)

    return {
        'hash': commit_info['hash'],
        'date': commit_info['date'],
        'message': commit_info['message'],
        'src_loc': src_loc,
        'src_files': src_files,
        'tests_loc': tests_loc,
        'tests_files': tests_files,
        'total_loc': src_loc + tests_loc,
        'total_files': src_files + tests_files
    }


def parse_datetime(date_str):
    """解析git日期格式"""
    return datetime.strptime(date_str[:19], "%Y-%m-%d %H:%M:%S")


def generate_chart(data, output_path):
    """生成折线图 - 分别展示src/和tests/"""
    if not HAS_MATPLOTLIB:
        print("⚠ 未安装 matplotlib，跳过图表生成")
        print("  安装命令: pip install matplotlib")
        return

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
    ax1.set_title('src/ Directory LOC Trend (Last 3 Days)', fontsize=14, fontweight='bold', pad=15)
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
        margin = (max_loc - min_loc) * 0.1 if max_loc != min_loc else max(end_loc * 0.1, 100)
        ax1.set_ylim(bottom=max(0, min_loc - margin), top=max_loc + margin)

        if start_loc > 0:
            pct = change / start_loc * 100
            stats_text = f"Start: {start_loc:,} | End: {end_loc:,} | Change: {change:+,} ({pct:.1f}%)"
        else:
            stats_text = f"Start: {start_loc:,} | End: {end_loc:,} | Change: {change:+,}"
        ax1.text(0.02, 0.98, stats_text, transform=ax1.transAxes,
                fontsize=9, verticalalignment='top',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    # tests/ 目录图表
    ax2.plot(dates, tests_locs, marker='s', markersize=4, linewidth=1.5, color='#A23B72', label='tests/')
    ax2.fill_between(dates, tests_locs, alpha=0.3, color='#A23B72')
    ax2.set_title('tests/ Directory LOC Trend (Last 3 Days)', fontsize=14, fontweight='bold', pad=15)
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
        margin = (max_loc - min_loc) * 0.1 if max_loc != min_loc else max(end_loc * 0.1, 100)
        ax2.set_ylim(bottom=max(0, min_loc - margin), top=max_loc + margin)

        if start_loc > 0:
            pct = change / start_loc * 100
            stats_text = f"Start: {start_loc:,} | End: {end_loc:,} | Change: {change:+,} ({pct:.1f}%)"
        else:
            stats_text = f"Start: {start_loc:,} | End: {end_loc:,} | Change: {change:+,}"
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

    # 设置输出编码（Windows 兼容）
    if platform.system() == 'Windows':
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='ignore')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='ignore')

    print("=" * 60)
    print("src/ 和 tests/ 目录有效代码行数变化分析（跨平台版）")
    print(f"平台: {platform.system()} | Python: {platform.python_version()}")
    print("=" * 60)

    # 检查 git 是否可用
    git_version = run_cmd(['git', '--version'])
    if not git_version:
        print("✗ 未找到 git 命令，请确保已安装 git 并添加到 PATH")
        sys.exit(1)
    print(f"Git: {git_version}")
    print()

    print("正在获取最近10条提交...")
    commits = get_commits()
    total = len(commits)
    print(f"共找到 {total} 个提交")

    if total == 0:
        print("没有找到最近两天的提交！")
        return

    git_root = get_git_root()
    if not git_root:
        print("✗ 无法获取 git 仓库根目录")
        sys.exit(1)

    # 确定线程数（使用线程池而非进程池，避免 Windows fork 问题）
    max_workers = min(8, (os.cpu_count() or 4))
    print(f"\n开始并行分析每个提交的代码行数（使用 {max_workers} 个线程）...")
    print("-" * 60)

    # 使用线程池并行处理（比进程池更跨平台兼容）
    data = []
    processed = 0

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_commit = {
            executor.submit(count_loc_at_commit, commit, git_root): commit
            for commit in commits
        }

        for future in as_completed(future_to_commit):
            result = future.result()
            processed += 1
            data.append(result)

            print(f"[{processed:3d}/{total:3d}] {result['hash']} | "
                  f"src: {result['src_loc']:5d} lines/{result['src_files']:3d} files | "
                  f"tests: {result['tests_loc']:5d} lines/{result['tests_files']:3d} files | "
                  f"{result['message'][:30]}")

    # 按原始顺序排序
    commit_order = {c['hash']: i for i, c in enumerate(commits)}
    data.sort(key=lambda x: commit_order.get(x['hash'], 0))

    print("-" * 60)

    # 输出到脚本所在目录
    output_dir = os.path.dirname(os.path.abspath(__file__))

    # 保存JSON数据
    json_path = os.path.join(output_dir, 'loc_data.json')
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"\n数据已保存到: {json_path}")

    # 生成折线图
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
        print()
        print("src/ Directory:")
        src_change = end['src_loc'] - start['src_loc']
        print(f"  Start: {start['src_loc']:,} lines  |  End: {end['src_loc']:,} lines")
        if start['src_loc'] > 0:
            print(f"  Change: {src_change:+,} lines ({src_change/start['src_loc']*100:.1f}%)")
        else:
            print(f"  Change: {src_change:+,} lines")
        print()
        print("tests/ Directory:")
        tests_change = end['tests_loc'] - start['tests_loc']
        print(f"  Start: {start['tests_loc']:,} lines  |  End: {end['tests_loc']:,} lines")
        if start['tests_loc'] > 0:
            print(f"  Change: {tests_change:+,} lines ({tests_change/start['tests_loc']*100:.1f}%)")
        else:
            print(f"  Change: {tests_change:+,} lines")
        print()
        print(f"Total (src + tests): {end['total_loc']:,} lines")
    print(f"Elapsed Time: {elapsed:.1f}s")


if __name__ == '__main__':
    main()
