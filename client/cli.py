"""
Supabase CLI 工具

提供命令列介面來管理 Supabase 本地部署和 RAG 系統。
"""

import click
import json
import sys
from typing import Optional, List, Dict, Any
from pathlib import Path

from .supabase_client import create_client, SupabaseClient
from .config import SupabaseConfig
# Note: SrcCategory and ResourceFileType enums removed, using string values directly


@click.group()
@click.option('--env-file', type=click.Path(exists=True), help='環境變數檔案路徑')
@click.pass_context
def cli(ctx, env_file: Optional[str]):
    """Supabase 本地部署 CLI 工具"""
    ctx.ensure_object(dict)
    ctx.obj['env_file'] = env_file


@cli.command()
@click.pass_context
def health(ctx):
    """檢查系統健康狀態"""
    try:
        config = SupabaseConfig(ctx.obj.get('env_file'))
        client = create_client(config)
        
        health_info = client.health_check()
        
        click.echo(f"🏥 系統健康檢查")
        click.echo(f"狀態: {health_info['status']}")
        click.echo(f"時間戳: {health_info['timestamp']}")
        
        click.echo("\n📊 連線狀態:")
        for service, status in health_info['connections'].items():
            status_icon = "✅" if status else "❌"
            click.echo(f"  {status_icon} {service}: {'正常' if status else '異常'}")
        
        click.echo("\n📈 資料庫統計:")
        stats = health_info['statistics']
        click.echo(f"  📄 資源總數: {stats.get('resources_count', 0)}")
        click.echo(f"  📝 分塊總數: {stats.get('chunks_count', 0)}")
        click.echo(f"  🖼️  圖片總數: {stats.get('images_count', 0)}")
        
        if stats.get('by_category'):
            click.echo("  📊 分類統計:")
            for category, count in stats['by_category'].items():
                click.echo(f"    - {category}: {count}")
        
        client.close()
        
    except Exception as e:
        click.echo(f"❌ 健康檢查失敗: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.pass_context
def config_info(ctx):
    """顯示配置資訊"""
    try:
        config = SupabaseConfig(ctx.obj.get('env_file'))
        client = create_client(config)
        
        config_info = client.get_config_info()
        
        click.echo("⚙️ Supabase 配置資訊:")
        click.echo(f"  📍 資料庫 URL: {config_info['database_url']}")
        click.echo(f"  🌐 Supabase URL: {config_info['supabase_url']}")
        click.echo(f"  🔑 匿名金鑰: {'已設置' if config_info['has_anon_key'] else '未設置'}")
        click.echo(f"  🔐 服務金鑰: {'已設置' if config_info['has_service_key'] else '未設置'}")
        click.echo(f"  📁 環境檔案: {config_info.get('env_file', '未指定')}")
        click.echo(f"  🏊 連接池大小: {config_info['pool_size']}")
        click.echo(f"  📈 最大溢出: {config_info['max_overflow']}")
        
        if config_info.get('user'):
            click.echo(f"  👤 當前用戶: {config_info['user'].get('email', '未登入')}")
        
        client.close()
        
    except Exception as e:
        click.echo(f"❌ 取得配置失敗: {e}", err=True)
        sys.exit(1)


@cli.group()
def resource():
    """資源管理命令"""
    pass


@resource.command('list')
@click.option('--category', type=str, help='依分類篩選 (如: news, paper, blog, docs, web, internal, other)')
@click.option('--limit', default=10, help='限制結果數量')
@click.option('--format', 'output_format', type=click.Choice(['table', 'json']), default='table', help='輸出格式')
@click.pass_context
def list_resources(ctx, category: Optional[str], limit: int, output_format: str):
    """列出資源"""
    try:
        config = SupabaseConfig(ctx.obj.get('env_file'))
        client = create_client(config)
        
        if category:
            resources = client.get_resources_by_category(category, limit)
        else:
            # 取得所有資源（透過資料庫管理器）
            resources = client.db.session.query(client.db.__class__.Resource).limit(limit).all()
        
        if output_format == 'json':
            data = [resource.to_dict() for resource in resources]
            click.echo(json.dumps(data, indent=2, ensure_ascii=False))
        else:
            click.echo(f"📄 資源列表 (顯示前 {limit} 筆):")
            click.echo()
            for resource in resources:
                click.echo(f"🔹 {resource.uuid}")
                click.echo(f"   標題: {resource.content_header or '未設置'}")
                click.echo(f"   來源: {resource.src_name or '未知'}")
                click.echo(f"   分類: {resource.src_category if resource.src_category else '未分類'}")
                click.echo(f"   類型: {resource.file_type if resource.file_type else '未知'}")
                click.echo(f"   URL: {resource.remote_src_url or '未設置'}")
                click.echo(f"   建立時間: {resource.created_at}")
                click.echo()
        
        client.close()
        
    except Exception as e:
        click.echo(f"❌ 列出資源失敗: {e}", err=True)
        sys.exit(1)


@resource.command('create')
@click.option('--url', required=True, help='資源 URL')
@click.option('--title', help='資源標題')
@click.option('--source', help='來源名稱')
@click.option('--category', type=str, default='other', help='資源分類 (如: news, paper, blog, docs, web, internal, other)')
@click.option('--file-type', type=str, default='other', help='檔案類型 (如: pdf, html, txt, image, audio, video, other)')
@click.pass_context
def create_resource(ctx, url: str, title: Optional[str], source: Optional[str], 
                   category: str, file_type: str):
    """創建新資源"""
    try:
        config = SupabaseConfig(ctx.obj.get('env_file'))
        client = create_client(config)
        
        # 檢查 URL 是否已存在
        existing = client.get_resources_by_url(url)
        if existing:
            click.echo(f"⚠️ 資源已存在: {existing.uuid}")
            return
        
        resource = client.create_resource(
            remote_src_url=url,
            content_header=title,
            src_name=source,
            src_category=category,
            file_type=file_type
        )
        
        click.echo(f"✅ 資源創建成功!")
        click.echo(f"   UUID: {resource.uuid}")
        click.echo(f"   標題: {resource.content_header}")
        click.echo(f"   URL: {resource.remote_src_url}")
        
        client.close()
        
    except Exception as e:
        click.echo(f"❌ 創建資源失敗: {e}", err=True)
        sys.exit(1)


@cli.group()
def search():
    """搜索命令"""
    pass


@search.command('text')
@click.argument('query')
@click.option('--limit', default=5, help='限制結果數量')
@click.pass_context
def search_text(ctx, query: str, limit: int):
    """全文搜索分塊"""
    try:
        config = SupabaseConfig(ctx.obj.get('env_file'))
        client = create_client(config)
        
        results = client.search_chunks_by_text(query, limit)
        
        click.echo(f"🔍 全文搜索結果: '{query}' (找到 {len(results)} 筆)")
        click.echo()
        
        for i, chunk in enumerate(results, 1):
            click.echo(f"{i}. 📝 分塊 {chunk.uuid}")
            click.echo(f"   資源: {chunk.resource_uuid}")
            click.echo(f"   順序: {chunk.chunk_order}")
            if chunk.description:
                click.echo(f"   描述: {chunk.description}")
            
            # 顯示部分內容
            content = chunk.chunking_text
            if len(content) > 200:
                content = content[:200] + "..."
            click.echo(f"   內容: {content}")
            click.echo()
        
        client.close()
        
    except Exception as e:
        click.echo(f"❌ 搜索失敗: {e}", err=True)
        sys.exit(1)


@search.command('vector')
@click.argument('embedding_file', type=click.Path(exists=True))
@click.option('--threshold', default=0.8, help='相似度閾值')
@click.option('--limit', default=5, help='限制結果數量')
@click.pass_context
def search_vector(ctx, embedding_file: str, threshold: float, limit: int):
    """向量搜索分塊（從檔案讀取 embedding）"""
    try:
        config = SupabaseConfig(ctx.obj.get('env_file'))
        client = create_client(config)
        
        # 讀取 embedding 檔案
        with open(embedding_file, 'r') as f:
            embedding_data = json.load(f)
        
        if isinstance(embedding_data, list):
            embedding = embedding_data
        elif isinstance(embedding_data, dict) and 'embedding' in embedding_data:
            embedding = embedding_data['embedding']
        else:
            raise ValueError("無效的 embedding 格式")
        
        results = client.search_chunks_by_embedding(embedding, threshold, limit)
        
        click.echo(f"🎯 向量搜索結果 (相似度 > {threshold}, 找到 {len(results)} 筆)")
        click.echo()
        
        for i, result in enumerate(results, 1):
            click.echo(f"{i}. 📝 分塊 {result['chunk_uuid']}")
            click.echo(f"   資源: {result['resource_uuid']}")
            click.echo(f"   相似度: {result['similarity']:.4f}")
            if result.get('description'):
                click.echo(f"   描述: {result['description']}")
            
            # 顯示部分內容
            content = result['chunking_text']
            if len(content) > 200:
                content = content[:200] + "..."
            click.echo(f"   內容: {content}")
            click.echo()
        
        client.close()
        
    except Exception as e:
        click.echo(f"❌ 向量搜索失敗: {e}", err=True)
        sys.exit(1)


@cli.group()
def auth():
    """認證管理命令"""
    pass


@auth.command('register')
@click.option('--email', prompt=True, help='電子郵件')
@click.option('--password', prompt=True, hide_input=True, help='密碼')
@click.pass_context
def register(ctx, email: str, password: str):
    """用戶註冊"""
    try:
        config = SupabaseConfig(ctx.obj.get('env_file'))
        client = create_client(config)
        
        result = client.sign_up(email, password)
        
        click.echo("✅ 註冊成功!")
        if result.get('user'):
            click.echo(f"   用戶 ID: {result['user']['id']}")
            click.echo(f"   電子郵件: {result['user']['email']}")
            if not result['user'].get('email_confirmed_at'):
                click.echo("   ⚠️ 請檢查郵箱並確認註冊")
        
        client.close()
        
    except Exception as e:
        click.echo(f"❌ 註冊失敗: {e}", err=True)
        sys.exit(1)


@auth.command('login')
@click.option('--email', prompt=True, help='電子郵件')
@click.option('--password', prompt=True, hide_input=True, help='密碼')
@click.pass_context
def login(ctx, email: str, password: str):
    """用戶登入"""
    try:
        config = SupabaseConfig(ctx.obj.get('env_file'))
        client = create_client(config)
        
        result = client.sign_in(email, password)
        
        click.echo("✅ 登入成功!")
        if result.get('user'):
            click.echo(f"   用戶 ID: {result['user']['id']}")
            click.echo(f"   電子郵件: {result['user']['email']}")
            click.echo(f"   登入時間: {result['user']['last_sign_in_at']}")
        
        client.close()
        
    except Exception as e:
        click.echo(f"❌ 登入失敗: {e}", err=True)
        sys.exit(1)


def main():
    """主程式入口"""
    cli()


if __name__ == '__main__':
    main()