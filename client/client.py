"""
Supabase 統一客戶端

整合 SQLAlchemy 資料庫操作和 Supabase SDK 功能，提供統一的介面。
"""

from typing import Optional, List, Dict, Any, Union, BinaryIO
from supabase import Client
from sqlalchemy.orm import Session
from .config import SupabaseConfig, get_config
from .database import DatabaseManager, create_database_manager, Resource, Chunk
import uuid
import json
import logging

logger = logging.getLogger(__name__)


class SupabaseClient:
    """Supabase 統一客戶端"""
    
    def __init__(self, config: Optional[SupabaseConfig] = None):
        """
        初始化客戶端
        
        Args:
            config: 配置實例，如果為 None 則使用預設配置
        """
        self.config = config or get_config()
        self._supabase_client: Optional[Client] = None
        self._service_client: Optional[Client] = None
        self._db_session: Optional[Session] = None
        self._db_manager: Optional[DatabaseManager] = None
    
    @property
    def supabase(self) -> Client:
        """取得 Supabase API 客戶端（匿名金鑰）"""
        if self._supabase_client is None:
            self._supabase_client = self.config.supabase_client
        return self._supabase_client
    
    @property
    def service_client(self) -> Client:
        """取得 Supabase Service 客戶端（管理權限）"""
        if self._service_client is None:
            self._service_client = self.config.create_service_client()
        return self._service_client
    
    @property
    def db_session(self) -> Session:
        """取得資料庫 Session"""
        if self._db_session is None:
            self._db_session = self.config.create_session()
        return self._db_session
    
    @property
    def db(self) -> DatabaseManager:
        """取得資料庫管理器"""
        if self._db_manager is None:
            self._db_manager = create_database_manager(self.db_session)
        return self._db_manager
    
    # ========== 認證功能 ==========
    
    def sign_up(self, email: str, password: str, **kwargs) -> Dict[str, Any]:
        """用戶註冊"""
        try:
            response = self.supabase.auth.sign_up({
                "email": email, 
                "password": password,
                **kwargs
            })
            logger.info(f"User signed up: {email}")
            return response.dict()
        except Exception as e:
            logger.error(f"Sign up failed: {e}")
            raise
    
    def sign_in(self, email: str, password: str) -> Dict[str, Any]:
        """用戶登入"""
        try:
            response = self.supabase.auth.sign_in_with_password({
                "email": email, 
                "password": password
            })
            logger.info(f"User signed in: {email}")
            return response.dict()
        except Exception as e:
            logger.error(f"Sign in failed: {e}")
            raise
    
    def sign_out(self) -> Dict[str, Any]:
        """用戶登出"""
        try:
            response = self.supabase.auth.sign_out()
            logger.info("User signed out")
            return response.dict()
        except Exception as e:
            logger.error(f"Sign out failed: {e}")
            raise
    
    def get_user(self) -> Optional[Dict[str, Any]]:
        """取得當前用戶資訊"""
        try:
            user = self.supabase.auth.get_user()
            if user and user.user:
                return user.user.dict()
            return None
        except Exception as e:
            logger.error(f"Get user failed: {e}")
            return None
    
    def reset_password(self, email: str) -> Dict[str, Any]:
        """重設密碼"""
        try:
            response = self.supabase.auth.reset_password_email(email)
            logger.info(f"Password reset email sent to: {email}")
            return response.dict()
        except Exception as e:
            logger.error(f"Reset password failed: {e}")
            raise
    
    # ========== 儲存功能 ==========
    
    def create_bucket(self, bucket_name: str, public: bool = False) -> Dict[str, Any]:
        """創建儲存桶"""
        try:
            response = self.service_client.storage.create_bucket(
                bucket_name, 
                {"public": public}
            )
            logger.info(f"Bucket created: {bucket_name}")
            return response
        except Exception as e:
            logger.error(f"Create bucket failed: {e}")
            raise
    
    def upload_file(self, bucket: str, path: str, file: Union[str, bytes, BinaryIO],
                   content_type: Optional[str] = None) -> Dict[str, Any]:
        """上傳檔案"""
        try:
            options = {}
            if content_type:
                options['content_type'] = content_type
            
            response = self.supabase.storage.from_(bucket).upload(
                path, file, options
            )
            logger.info(f"File uploaded: {bucket}/{path}")
            return response
        except Exception as e:
            logger.error(f"Upload file failed: {e}")
            raise
    
    def download_file(self, bucket: str, path: str) -> bytes:
        """下載檔案"""
        try:
            response = self.supabase.storage.from_(bucket).download(path)
            logger.info(f"File downloaded: {bucket}/{path}")
            return response
        except Exception as e:
            logger.error(f"Download file failed: {e}")
            raise
    
    def delete_file(self, bucket: str, paths: Union[str, List[str]]) -> Dict[str, Any]:
        """刪除檔案"""
        try:
            if isinstance(paths, str):
                paths = [paths]
            
            response = self.supabase.storage.from_(bucket).remove(paths)
            logger.info(f"Files deleted from {bucket}: {paths}")
            return response
        except Exception as e:
            logger.error(f"Delete file failed: {e}")
            raise
    
    def list_files(self, bucket: str, path: str = "") -> List[Dict[str, Any]]:
        """列出檔案"""
        try:
            response = self.supabase.storage.from_(bucket).list(path)
            return response
        except Exception as e:
            logger.error(f"List files failed: {e}")
            raise
    
    def get_file_url(self, bucket: str, path: str, expires_in: int = 3600) -> str:
        """取得檔案 URL"""
        try:
            response = self.supabase.storage.from_(bucket).create_signed_url(
                path, expires_in
            )
            return response.get('signedURL', '')
        except Exception as e:
            logger.error(f"Get file URL failed: {e}")
            raise
    
    # ========== 資料庫功能（RAG 專用） ==========
    
    def create_resource(self, **kwargs) -> Resource:
        """創建資源"""
        return self.db.create_resource(**kwargs)
    
    def get_resource(self, resource_uuid: Union[str, uuid.UUID]) -> Optional[Resource]:
        """取得資源"""
        return self.db.get_resource(resource_uuid)
    
    def get_resources_by_url(self, remote_url: str) -> Optional[Resource]:
        """根據 URL 取得資源"""
        return self.db.get_resources_by_url(remote_url)
    
    def get_resources_by_category(self, category: str, limit: int = 100) -> List[Resource]:
        """根據分類取得資源"""
        return self.db.get_resources_by_category(category, limit)
    
    def update_resource(self, resource_uuid: Union[str, uuid.UUID], **kwargs) -> Optional[Resource]:
        """更新資源"""
        return self.db.update_resource(resource_uuid, **kwargs)
    
    def create_chunk(self, **kwargs) -> Chunk:
        """創建分塊"""
        return self.db.create_chunk(**kwargs)
    
    def get_chunks_by_resource(self, resource_uuid: Union[str, uuid.UUID], 
                              limit: int = 100) -> List[Chunk]:
        """取得資源的所有分塊"""
        return self.db.get_chunks_by_resource(resource_uuid, limit)
    
    def search_chunks_by_text(self, query: str, limit: int = 10) -> List[Chunk]:
        """全文搜索分塊"""
        return self.db.search_chunks_by_text(query, limit)
    
    def search_chunks_by_embedding(self, embedding: List[float], 
                                  threshold: float = 0.8, limit: int = 10) -> List[Dict[str, Any]]:
        """向量搜索分塊"""
        return self.db.search_chunks_by_embedding(embedding, threshold, limit)
    
    def hybrid_search_chunks(self, text_query: str, embedding: List[float],
                           text_weight: float = 0.5, vector_weight: float = 0.5,
                           limit: int = 10) -> List[Dict[str, Any]]:
        """混合搜索（全文 + 向量）"""
        return self.db.hybrid_search_chunks(
            text_query, embedding, text_weight, vector_weight, limit
        )
    
    # ========== 即時功能 ==========
    
    def subscribe_to_changes(self, table: str, callback, **kwargs):
        """訂閱資料變更"""
        try:
            channel = self.supabase.channel(f"{table}_changes")
            
            channel.on_postgres_changes(
                event='*',
                schema='public',
                table=table,
                callback=callback,
                **kwargs
            ).subscribe()
            
            logger.info(f"Subscribed to changes on table: {table}")
            return channel
        except Exception as e:
            logger.error(f"Subscribe failed: {e}")
            raise
    
    def unsubscribe_all(self):
        """取消所有訂閱"""
        try:
            self.supabase.remove_all_channels()
            logger.info("All subscriptions removed")
        except Exception as e:
            logger.error(f"Unsubscribe all failed: {e}")
            raise
    
    # ========== RPC 功能 ==========
    
    def call_function(self, function_name: str, parameters: Dict[str, Any] = None) -> Any:
        """調用資料庫函數"""
        try:
            response = self.supabase.rpc(function_name, parameters or {})
            logger.info(f"Function called: {function_name}")
            return response.data
        except Exception as e:
            logger.error(f"Function call failed: {e}")
            raise
    
    def search_chunks_rpc(self, query_embedding: List[float], 
                         match_threshold: float = 0.8, 
                         match_count: int = 10) -> List[Dict[str, Any]]:
        """使用 RPC 進行向量搜索"""
        return self.call_function('search_chunks_by_embedding', {
            'query_embedding': query_embedding,
            'match_threshold': match_threshold,
            'match_count': match_count
        })
    
    def search_chunks_text_rpc(self, search_query: str, 
                              match_count: int = 10) -> List[Dict[str, Any]]:
        """使用 RPC 進行全文搜索"""
        return self.call_function('search_chunks_by_text', {
            'search_query': search_query,
            'match_count': match_count
        })
    
    def hybrid_search_rpc(self, search_query: str, query_embedding: List[float],
                         text_weight: float = 0.5, vector_weight: float = 0.5,
                         match_count: int = 10) -> List[Dict[str, Any]]:
        """使用 RPC 進行混合搜索"""
        return self.call_function('hybrid_search_chunks', {
            'search_query': search_query,
            'query_embedding': query_embedding,
            'text_weight': text_weight,
            'vector_weight': vector_weight,
            'match_count': match_count
        })
    
    # ========== 工具方法 ==========
    
    def get_database_statistics(self) -> Dict[str, Any]:
        """取得資料庫統計資訊"""
        return self.db.get_statistics()
    
    def test_connections(self) -> Dict[str, bool]:
        """測試所有連線"""
        return self.config.test_connections()
    
    def get_config_info(self) -> Dict[str, Any]:
        """取得配置資訊"""
        config_info = self.config.get_config_info()
        config_info['user'] = self.get_user()
        return config_info
    
    def health_check(self) -> Dict[str, Any]:
        """健康檢查"""
        health = {
            'timestamp': str(uuid.uuid4()),
            'status': 'healthy',
            'connections': self.test_connections(),
            'statistics': self.get_database_statistics()
        }
        
        # 檢查是否所有連線都正常
        if not all(health['connections'].values()):
            health['status'] = 'unhealthy'
        
        return health
    
    def close(self):
        """關閉所有連線"""
        if self._db_manager:
            self._db_manager.close()
            self._db_manager = None
        
        if self._db_session:
            self._db_session.close()
            self._db_session = None
        
        # 取消所有即時訂閱
        try:
            self.unsubscribe_all()
        except:
            pass
        
        logger.info("Supabase client closed")
    
    def __enter__(self):
        """支援 context manager"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """支援 context manager"""
        self.close()


# 便利函數
def create_client(config: Optional[SupabaseConfig] = None) -> SupabaseClient:
    """創建 Supabase 客戶端"""
    return SupabaseClient(config)

def create_service_client(config: Optional[SupabaseConfig] = None) -> SupabaseClient:
    """創建具有服務權限的客戶端"""
    client = SupabaseClient(config)
    # 強制使用 service client
    client._supabase_client = client.service_client
    return client