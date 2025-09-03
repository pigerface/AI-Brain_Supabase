"""
極簡 Supabase 客戶端

直接使用官方 SDK，只添加必要的業務邏輯服務。
"""

from supabase import create_client
from .domain import ResourceService, SearchService


class SupabaseClient:
    """
    極簡 Supabase 客戶端
    
    直接暴露官方 SDK 的所有功能，同時提供業務領域服務。
    """
    
    def __init__(self, url: str, key: str):
        """
        初始化客戶端
        
        Args:
            url: Supabase 項目 URL
            key: API 金鑰
        """
        # 直接使用官方客戶端
        self.client = create_client(url, key)
        
        # 添加業務領域服務
        self.resources = ResourceService(self.client)
        self.search = SearchService(self.client)
    
    def __getattr__(self, name):
        """
        代理所有其他屬性到官方客戶端
        
        這讓我們可以直接使用 client.auth, client.storage, client.table 等
        """
        return getattr(self.client, name)