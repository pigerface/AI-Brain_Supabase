#!/usr/bin/env python3
"""
Supabase UV 環境使用範例

展示如何在 UV workspace 中使用 Supabase 客戶端。
執行方式：uv run supabase/uv-example.py
"""

import asyncio
import json
from pathlib import Path

# 從 supabase 套件導入
from supabase.client import create_client
# Note: SrcCategory and ResourceFileType enums removed, using string values directly


def main():
    """主範例函數"""
    print("🚀 Supabase UV 環境範例")
    print("=" * 50)
    
    # 創建客戶端
    print("\n📊 1. 建立 Supabase 客戶端")
    try:
        client = create_client()
        print("✅ 客戶端建立成功")
        
        # 顯示配置資訊
        config_info = client.get_config_info()
        print(f"   📍 資料庫: {config_info['database_url']}")
        print(f"   🌐 Supabase: {config_info['supabase_url']}")
        
    except Exception as e:
        print(f"❌ 客戶端建立失敗: {e}")
        return
    
    # 健康檢查
    print("\n🏥 2. 系統健康檢查")
    try:
        health = client.health_check()
        print(f"   狀態: {health['status']}")
        
        for service, status in health['connections'].items():
            status_icon = "✅" if status else "❌"
            print(f"   {status_icon} {service}")
            
    except Exception as e:
        print(f"❌ 健康檢查失敗: {e}")
    
    # 資料庫統計
    print("\n📈 3. 資料庫統計")
    try:
        stats = client.get_database_statistics()
        print(f"   📄 資源: {stats.get('resources_count', 0)} 筆")
        print(f"   📝 分塊: {stats.get('chunks_count', 0)} 筆")
        print(f"   🖼️  圖片: {stats.get('images_count', 0)} 筆")
        
        if stats.get('by_category'):
            print("   📊 分類統計:")
            for category, count in stats['by_category'].items():
                print(f"      - {category}: {count}")
                
    except Exception as e:
        print(f"❌ 統計查詢失敗: {e}")
    
    # 範例資源操作
    print("\n📄 4. 資源管理範例")
    try:
        # 檢查是否有範例資源
        example_url = "https://example.com/uv-test-article"
        existing_resource = client.get_resources_by_url(example_url)
        
        if existing_resource:
            print(f"   ♻️ 找到現有資源: {existing_resource.uuid}")
            resource = existing_resource
        else:
            # 創建範例資源
            resource = client.create_resource(
                remote_src_url=example_url,
                content_header="UV 環境測試文章",
                content_authors="Claude Code",
                src_name="UV Example",
                src_category="docs",
                file_type="html",
                need_parsed=True,
                lang="zh-TW"
            )
            print(f"   ✅ 創建新資源: {resource.uuid}")
        
        # 顯示資源資訊
        print(f"      標題: {resource.content_header}")
        print(f"      來源: {resource.src_name}")
        print(f"      分類: {resource.src_category}")
        print(f"      語言: {resource.lang}")
        
    except Exception as e:
        print(f"❌ 資源操作失敗: {e}")
    
    # 分塊操作範例
    print("\n📝 5. 文字分塊範例")
    try:
        if 'resource' in locals():
            # 檢查是否已有分塊
            existing_chunks = client.get_chunks_by_resource(resource.uuid)
            
            if existing_chunks:
                print(f"   ♻️ 找到現有分塊: {len(existing_chunks)} 個")
                chunk = existing_chunks[0]
            else:
                # 創建範例分塊
                chunk = client.create_chunk(
                    resource_uuid=resource.uuid,
                    chunk_order=1,
                    chunking_text="這是一個在 UV 環境中運行的 Supabase RAG 系統測試。我們正在示範如何使用 Python 客戶端來管理資源和文字分塊。",
                    description="UV 環境測試分塊",
                    token_size=50
                )
                print(f"   ✅ 創建新分塊: {chunk.uuid}")
            
            # 顯示分塊資訊
            print(f"      資源: {chunk.resource_uuid}")
            print(f"      順序: {chunk.chunk_order}")
            print(f"      描述: {chunk.description}")
            print(f"      內容: {chunk.chunking_text[:100]}...")
            
    except Exception as e:
        print(f"❌ 分塊操作失敗: {e}")
    
    # 搜索功能範例
    print("\n🔍 6. 搜索功能範例")
    try:
        # 全文搜索
        text_results = client.search_chunks_by_text("UV 環境", limit=3)
        print(f"   📝 全文搜索結果: {len(text_results)} 筆")
        
        for i, chunk in enumerate(text_results, 1):
            print(f"      {i}. {chunk.uuid} - {chunk.description or '無描述'}")
        
    except Exception as e:
        print(f"❌ 搜索失敗: {e}")
    
    # 認證功能範例 (可選)
    print("\n🔐 7. 認證系統 (可選)")
    try:
        # 嘗試取得當前用戶
        current_user = client.get_user()
        if current_user:
            print(f"   👤 當前用戶: {current_user.get('email', '未知')}")
        else:
            print("   🔓 未登入用戶")
            
    except Exception as e:
        print(f"❌ 認證檢查失敗: {e}")
    
    # 關閉客戶端
    print("\n🔄 8. 清理資源")
    try:
        client.close()
        print("   ✅ 客戶端已關閉")
    except Exception as e:
        print(f"❌ 關閉失敗: {e}")
    
    print("\n" + "=" * 50)
    print("✅ UV 環境範例完成!")
    print()
    print("💡 更多用法:")
    print("   cd supabase && uv run python -c \"from supabase.client import create_client; client = create_client()\"")
    print("   uv run supabase-cli health")
    print("   uv run supabase-cli resource list")
    print("   ./supabase.sh python")


if __name__ == "__main__":
    main()