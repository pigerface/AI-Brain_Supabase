"""
Supabase Local Client Package

提供 Supabase 本地部署的 Python 客戶端封裝，包含：
- SQLAlchemy 資料庫連接
- Supabase SDK 封裝
- 配置管理
"""

from .config import SupabaseConfig
from .database import DatabaseManager, get_db_session
from .client import SupabaseClient

__all__ = [
    'SupabaseConfig',
    'DatabaseManager',
    'get_db_session',
    'SupabaseClient'
]

__version__ = '1.0.0'