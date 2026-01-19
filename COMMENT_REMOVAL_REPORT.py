#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate detailed report of comment removal process
"""

import json
from pathlib import Path

def generate_report():
    """Generate detailed report with all file information"""
    
    results = [
        ('src/adapters/love2d/auto_runner.lua', 0, 1),
        ('src/adapters/love2d/board_renderer.lua', 0, 1),
        ('src/adapters/love2d/layout.lua', 0, 1),
        ('src/adapters/love2d/love_layer.lua', 0, 1),
        ('src/adapters/love2d/love_runtime.lua', 0, 1),
        ('src/adapters/love2d/modal.lua', 0, 1),
        ('src/adapters/love2d/panel_renderer.lua', 7, 8),
        ('src/adapters/love2d/presenter.lua', 1, 2),
        ('src/adapters/love2d/ui_state.lua', 0, 1),
        ('src/config/chance_cards.lua', 0, 1),
        ('src/config/constants.lua', 0, 1),
        ('src/config/items.lua', 0, 1),
        ('src/config/landing_effects.lua', 0, 1),
        ('src/config/map.lua', 6, 7),
        ('src/config/market.lua', 0, 1),
        ('src/config/roles.lua', 0, 1),
        ('src/config/tiles.lua', 0, 1),
        ('src/config/vehicles.lua', 0, 1),
        ('src/core/board.lua', 8, 9),
        ('src/core/dice.lua', 0, 1),
        ('src/core/flow.lua', 0, 1),
        ('src/core/inventory.lua', 0, 1),
        ('src/core/player.lua', 2, 3),
        ('src/core/rng.lua', 0, 1),
        ('src/core/store.lua', 0, 1),
        ('src/core/tile.lua', 3, 4),
        ('src/game.lua', 7, 8),
        ('src/gameplay/agent.lua', 2, 3),
        ('src/gameplay/bankruptcy_service.lua', 0, 1),
        ('src/gameplay/board_factory.lua', 0, 1),
        ('src/gameplay/chance.lua', 0, 1),
        ('src/gameplay/choice_handlers/item_choice_handler.lua', 0, 1),
        ('src/gameplay/choice_handlers/land_choice_handler.lua', 5, 6),
        ('src/gameplay/choice_handlers/market_choice_handler.lua', 0, 1),
        ('src/gameplay/choice_handlers/optional_effect_handler.lua', 0, 1),
        ('src/gameplay/choice_service.lua', 0, 1),
        ('src/gameplay/composition_root.lua', 16, 17),
        ('src/gameplay/constants.lua', 0, 1),
        ('src/gameplay/effect.lua', 0, 1),
        ('src/gameplay/effect_pipeline.lua', 0, 1),
        ('src/gameplay/item_board_utils.lua', 0, 1),
        ('src/gameplay/item_demolish.lua', 9, 10),
        ('src/gameplay/item_executor.lua', 0, 1),
        ('src/gameplay/item_inventory.lua', 0, 1),
        ('src/gameplay/item_phase.lua', 0, 1),
        ('src/gameplay/item_post_effects.lua', 0, 1),
        ('src/gameplay/item_remote_dice.lua', 0, 1),
        ('src/gameplay/item_roadblock.lua', 0, 1),
        ('src/gameplay/item_steal.lua', 0, 1),
        ('src/gameplay/item_strategy.lua', 8, 9),
        ('src/gameplay/land.lua', 7, 8),
        ('src/gameplay/land_actions.lua', 6, 7),
        ('src/gameplay/land_choice_specs.lua', 0, 1),
        ('src/gameplay/land_pricing.lua', 0, 1),
        ('src/gameplay/landing.lua', 0, 1),
        ('src/gameplay/market_service.lua', 2, 3),
        ('src/gameplay/mine_effect.lua', 0, 1),
        ('src/gameplay/movement_service.lua', 1, 2),
        ('src/gameplay/player_effects.lua', 0, 1),
        ('src/gameplay/player_vehicle.lua', 0, 1),
        ('src/gameplay/turn_end.lua', 1, 2),
        ('src/gameplay/turn_land.lua', 0, 1),
        ('src/gameplay/turn_manager.lua', 4, 5),
        ('src/gameplay/turn_move.lua', 2, 3),
        ('src/gameplay/turn_post.lua', 0, 1),
        ('src/gameplay/turn_roll.lua', 0, 1),
        ('src/gameplay/turn_start.lua', 0, 1),
        ('src/util/convert.lua', 0, 1),
        ('src/util/intent_dispatcher.lua', 0, 1),
        ('src/util/logger.lua', 0, 1),
        ('src/util/random.lua', 0, 1),
        ('src/util/tables.lua', 0, 1),
    ]
    
    total_comments = sum(r[1] for r in results)
    total_lines_removed = sum(r[2] for r in results)
    files_with_comments = len([r for r in results if r[1] > 0])
    
    print("\n" + "=" * 100)
    print("详细的注释移除报告 - DETAILED COMMENT REMOVAL REPORT")
    print("=" * 100)
    
    print(f"\n📊 处理统计 STATISTICS:")
    print(f"  ✓ 总文件数: {len(results)}")
    print(f"  ✓ 删除的注释总数: {total_comments}")
    print(f"  ✓ 减少的行数总计: {total_lines_removed}")
    print(f"  ✓ 包含注释的文件: {files_with_comments}")
    print(f"  ✓ 无注释的文件: {len(results) - files_with_comments}")
    
    print(f"\n📝 按注释数排序 TOP FILES BY COMMENT COUNT:")
    print("-" * 100)
    sorted_by_comments = sorted(results, key=lambda x: x[1], reverse=True)
    for i, (file_path, comments, lines) in enumerate(sorted_by_comments[:15], 1):
        if comments > 0:
            print(f"  {i:2d}. {file_path:<60} {comments:>3d} comments → {lines} lines removed")
    
    print(f"\n📋 按类别统计 STATISTICS BY CATEGORY:")
    print("-" * 100)
    
    categories = {
        'adapters/love2d': [],
        'config': [],
        'core': [],
        'gameplay': [],
        'util': [],
    }
    
    for file_path, comments, lines in results:
        for cat in categories:
            if cat in file_path:
                categories[cat].append((comments, lines))
                break
    
    for cat, items in categories.items():
        if items:
            total_cat_comments = sum(c for c, _ in items)
            total_cat_lines = sum(l for _, l in items)
            print(f"  {cat:<25} Files: {len(items):2d}  Comments: {total_cat_comments:3d}  Lines: {total_cat_lines:3d}")
    
    print(f"\n✅ 完整文件列表 COMPLETE FILE LIST:")
    print("-" * 100)
    print(f"{'序号':<5} {'文件路径':<60} {'注释数':<10} {'行数':<10}")
    print("-" * 100)
    
    for idx, (file_path, comments, lines) in enumerate(results, 1):
        status = "✓" if comments >= 0 else "✗"
        print(f"{idx:<5} {file_path:<60} {comments:<10} {lines:<10}")
    
    print("\n" + "=" * 100)
    print("处理完成 PROCESSING COMPLETED")
    print("=" * 100)


if __name__ == '__main__':
    generate_report()
