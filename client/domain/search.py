"""搜索服務 - 整合 PostgreSQL 與 pgvector 的搜索功能"""

from typing import List, Dict, Any, Optional
from supabase import Client


class SearchService:
    """RAG 系統搜索的核心業務邏輯"""
    
    def __init__(self, client: Client):
        self.client = client
        
    def semantic_search(self, query_embedding: List[float], table: str = 'chunks', 
                       limit: int = 10, threshold: float = 0.7) -> List[Dict[str, Any]]:
        """語義搜索 - 使用 pgvector 相似度搜索"""
        # 使用 RPC 調用自定義的相似度搜索函數
        response = self.client.rpc('semantic_search', {
            'query_embedding': query_embedding,
            'match_threshold': threshold,
            'match_count': limit,
            'table_name': table
        }).execute()
        return response.data
        
    def hybrid_search(self, text_query: str, embedding: List[float], 
                     source: Optional[str] = None, limit: int = 10) -> List[Dict[str, Any]]:
        """混合搜索 - 結合文本搜索和語義搜索"""
        params = {
            'text_query': text_query,
            'query_embedding': embedding,
            'match_count': limit
        }
        if source:
            params['source_filter'] = source
            
        response = self.client.rpc('hybrid_search', params).execute()
        return response.data
        
    def search_by_metadata(self, metadata_filters: Dict[str, Any], 
                          table: str = 'resources') -> List[Dict[str, Any]]:
        """按元數據搜索資源"""
        query = self.client.table(table).select('*')
        
        for key, value in metadata_filters.items():
            if isinstance(value, list):
                query = query.in_(key, value)
            else:
                query = query.eq(key, value)
                
        response = query.execute()
        return response.data