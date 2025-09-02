"""資源管理服務 - 專注於 RAG 系統的業務邏輯"""

from typing import List, Optional, Dict, Any
from supabase import Client


class ResourceService:
    """資源管理的核心業務邏輯"""
    
    def __init__(self, client: Client):
        self.client = client
        
    def get_by_source(self, source: str, limit: int = 100) -> List[Dict[str, Any]]:
        """按媒體源獲取資源"""
        response = self.client.table('resources').select('*').eq('source', source).limit(limit).execute()
        return response.data
        
    def get_by_url(self, url: str) -> Optional[Dict[str, Any]]:
        """按 URL 獲取資源（去重用）"""
        response = self.client.table('resources').select('*').eq('url', url).execute()
        return response.data[0] if response.data else None
        
    def mark_processed(self, resource_id: str, processed_at: str = None) -> bool:
        """標記資源為已處理"""
        update_data = {'processed': True}
        if processed_at:
            update_data['processed_at'] = processed_at
            
        response = self.client.table('resources').update(update_data).eq('id', resource_id).execute()
        return len(response.data) > 0
        
    def get_unprocessed(self, source: Optional[str] = None, limit: int = 50) -> List[Dict[str, Any]]:
        """獲取未處理的資源"""
        query = self.client.table('resources').select('*').eq('processed', False)
        if source:
            query = query.eq('source', source)
        response = query.limit(limit).execute()
        return response.data