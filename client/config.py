"""極簡配置 - 僅環境變數管理"""

import os
from supabase import create_client, Client


def get_supabase_client() -> Client:
    """創建 Supabase 客戶端"""
    url = os.getenv('SUPABASE_URL', 'http://localhost:8000')
    key = os.getenv('SUPABASE_ANON_KEY', '')
    
    if not key:
        raise ValueError("SUPABASE_ANON_KEY environment variable is required")
    
    return create_client(url, key)