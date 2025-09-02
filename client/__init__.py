"""極簡 Supabase 客戶端 - 專注業務邏輯"""

from .client import SupabaseClient
from .config import get_supabase_client
from .domain import ResourceService, SearchService

__all__ = [
    'SupabaseClient',
    'get_supabase_client', 
    'ResourceService',
    'SearchService'
]

__version__ = '3.0.0'