"""
Supabase 配置管理

統一管理 Supabase 本地部署的連線配置，支援環境變數和配置檔案。
"""

import os
from typing import Optional, Dict, Any
from sqlalchemy import create_engine, Engine
from sqlalchemy.orm import sessionmaker, Session
from supabase import create_client, Client
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

class SupabaseConfig:
    """Supabase 配置管理器"""
    
    def __init__(self, env_file: Optional[str] = None):
        """
        初始化配置
        
        Args:
            env_file: .env 檔案路徑，默認為項目根目錄的 .env
        """
        self.env_file = env_file or self._find_env_file()
        self._load_env_file()
        
        # 資料庫配置
        self.database_url = self._get_env('DATABASE_URL', 
            'postgresql://postgres:postgres@localhost:5432/postgres')
        
        # Supabase API 配置
        self.supabase_url = self._get_env('SUPABASE_URL', 'http://localhost:8000')
        self.supabase_anon_key = self._get_env('SUPABASE_ANON_KEY', '')
        self.supabase_service_key = self._get_env('SUPABASE_SERVICE_KEY', '')
        
        # 連接池配置
        self.pool_size = int(self._get_env('DB_POOL_SIZE', '5'))
        self.max_overflow = int(self._get_env('DB_MAX_OVERFLOW', '10'))
        self.pool_pre_ping = self._get_env('DB_POOL_PRE_PING', 'true').lower() == 'true'
        
        # SQLAlchemy 引擎
        self._engine: Optional[Engine] = None
        self._session_factory: Optional[sessionmaker] = None
        
        # Supabase 客戶端
        self._supabase_client: Optional[Client] = None
        
    def _find_env_file(self) -> Optional[str]:
        """尋找 .env 檔案"""
        current_dir = Path(__file__).parent
        
        # 依序查找 .env 檔案
        search_paths = [
            current_dir / '.env',
            current_dir.parent / '.env',
            current_dir.parent.parent / '.env',
            Path.cwd() / '.env'
        ]
        
        for path in search_paths:
            if path.exists():
                return str(path)
        
        return None
    
    def _load_env_file(self):
        """載入 .env 檔案"""
        if not self.env_file or not os.path.exists(self.env_file):
            logger.warning(f"No .env file found at {self.env_file}")
            return
        
        try:
            with open(self.env_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip().strip('"\'')
                        
                        # 只有當環境變數不存在時才設定
                        if key not in os.environ:
                            os.environ[key] = value
        except Exception as e:
            logger.error(f"Error loading .env file: {e}")
    
    def _get_env(self, key: str, default: str = '') -> str:
        """取得環境變數"""
        return os.getenv(key, default)
    
    @property
    def engine(self) -> Engine:
        """取得 SQLAlchemy 引擎"""
        if self._engine is None:
            connect_args = {}
            
            # PostgreSQL 專用設定
            if 'postgresql' in self.database_url:
                connect_args['options'] = '-c timezone=Asia/Taipei'
            
            self._engine = create_engine(
                self.database_url,
                pool_size=self.pool_size,
                max_overflow=self.max_overflow,
                pool_pre_ping=self.pool_pre_ping,
                connect_args=connect_args,
                echo=self._get_env('DB_ECHO', 'false').lower() == 'true'
            )
            
            logger.info(f"Created database engine for {self.database_url}")
        
        return self._engine
    
    @property
    def session_factory(self) -> sessionmaker:
        """取得 Session 工廠"""
        if self._session_factory is None:
            self._session_factory = sessionmaker(
                bind=self.engine,
                autocommit=False,
                autoflush=False
            )
        
        return self._session_factory
    
    def create_session(self) -> Session:
        """創建新的資料庫 Session"""
        return self.session_factory()
    
    @property
    def supabase_client(self) -> Client:
        """取得 Supabase 客戶端"""
        if self._supabase_client is None:
            if not self.supabase_anon_key:
                raise ValueError("SUPABASE_ANON_KEY is required")
            
            self._supabase_client = create_client(
                self.supabase_url,
                self.supabase_anon_key
            )
            
            logger.info(f"Created Supabase client for {self.supabase_url}")
        
        return self._supabase_client
    
    def create_service_client(self) -> Client:
        """創建 Service Role 客戶端（管理權限）"""
        if not self.supabase_service_key:
            raise ValueError("SUPABASE_SERVICE_KEY is required for service client")
        
        return create_client(
            self.supabase_url,
            self.supabase_service_key
        )
    
    def get_config_info(self) -> Dict[str, Any]:
        """取得配置資訊（除了敏感資料）"""
        return {
            'database_url': self.database_url.replace(
                self.database_url.split('@')[0].split('//')[-1], 
                '***:***'
            ) if '@' in self.database_url else self.database_url,
            'supabase_url': self.supabase_url,
            'pool_size': self.pool_size,
            'max_overflow': self.max_overflow,
            'pool_pre_ping': self.pool_pre_ping,
            'env_file': self.env_file,
            'has_anon_key': bool(self.supabase_anon_key),
            'has_service_key': bool(self.supabase_service_key)
        }
    
    def test_connections(self) -> Dict[str, bool]:
        """測試所有連線"""
        results = {}
        
        # 測試資料庫連線
        try:
            with self.engine.connect() as conn:
                conn.execute('SELECT 1')
            results['database'] = True
            logger.info("Database connection successful")
        except Exception as e:
            results['database'] = False
            logger.error(f"Database connection failed: {e}")
        
        # 測試 Supabase API 連線
        try:
            # 簡單的健康檢查
            response = self.supabase_client.table('resources').select('count').limit(1).execute()
            results['supabase_api'] = True
            logger.info("Supabase API connection successful")
        except Exception as e:
            results['supabase_api'] = False
            logger.error(f"Supabase API connection failed: {e}")
        
        return results


# 全域配置實例
_config: Optional[SupabaseConfig] = None

def get_config(env_file: Optional[str] = None) -> SupabaseConfig:
    """取得全域配置實例"""
    global _config
    
    if _config is None or env_file is not None:
        _config = SupabaseConfig(env_file)
    
    return _config

def get_db_engine() -> Engine:
    """取得資料庫引擎"""
    return get_config().engine

def get_db_session() -> Session:
    """取得資料庫 Session"""
    return get_config().create_session()

def get_supabase_client() -> Client:
    """取得 Supabase 客戶端"""
    return get_config().supabase_client