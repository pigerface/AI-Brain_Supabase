# AI Brain Supabase - Python 客戶端庫

AI Brain Supabase 的 Python 客戶端庫套件，提供完整的 RAG 系統操作接口與工具。

![Python](https://img.shields.io/badge/Python-3.12+-yellow)
![Supabase](https://img.shields.io/badge/Supabase-Client-green)
![pgvector](https://img.shields.io/badge/pgvector-Support-purple)

---

## 📋 客戶端模組概覽

### 核心模組結構
```
client/
├── __init__.py                # Python 套件初始化與導出
├── client.py                  # 🔌 主要 Supabase 客戶端接口
├── cli.py                     # 💻 命令行工具與 CLI 介面
├── config.py                  # ⚙️ 配置管理與環境讀取工具
└── database.py                # 🗄️ 數據庫 ORM 與查詢工具
```

---

## 🔌 client.py - 主要客戶端接口

**統一的 Supabase 操作高級 API**

### 主要功能
- **🔗 連接管理**：自動處理數據庫連接、認證與重連
- **🧠 RAG 支持**：針對向量搜索與文檔管理的專用方法  
- **📊 資源管理**：完整的 resources、chunks、embeddings CRUD
- **🔍 智能搜索**：支援全文搜索、向量搜索、混合搜索
- **⚡ 批次操作**：高效的批量數據處理與更新
- **🛡️ 錯誤處理**：完善的異常處理與自動重試機制

### 核心類別與方法

#### **SupabaseClient 類別**
```python
class SupabaseClient:
    """
    AI Brain Supabase 統一客戶端接口
    
    提供 RAG 系統的所有核心功能：
    - 數據庫連接管理
    - 資源與分塊操作
    - 向量搜索與全文搜索
    - 批量數據處理
    """
    
    def __init__(self, config: Optional[Config] = None)
    def get_config_info(self) -> Dict[str, str]
    def health_check(self) -> Dict[str, Any]
    def get_database_statistics(self) -> Dict[str, int]
    def close(self) -> None
```

#### **資源管理方法**
```python
# 媒體來源管理
def create_media_source(self, id: str, name: str, description: str, **kwargs) -> MediaSource
def get_media_source(self, source_id: str) -> Optional[MediaSource]
def list_media_sources(self) -> List[MediaSource]

# 資源文檔管理
def create_resource(self, remote_src_url: str, content_header: str, source_id: str, **kwargs) -> Resource
def get_resource(self, resource_uuid: str) -> Optional[Resource]
def get_resources_by_url(self, remote_src_url: str) -> Optional[Resource]
def list_resources(self, source_id: Optional[str] = None, limit: int = 100) -> List[Resource]

# 文字分塊管理
def create_chunk(self, resource_uuid: str, chunk_order: int, chunking_text: str, **kwargs) -> Chunk
def get_chunk(self, chunk_uuid: str) -> Optional[Chunk]
def get_chunks_by_resource(self, resource_uuid: str) -> List[Chunk]
def update_chunk_embedding(self, chunk_uuid: str, embedding: List[float]) -> bool
```

#### **搜索與查詢方法**
```python
# 全文搜索
def search_chunks_by_text(self, query: str, source_id: Optional[str] = None, limit: int = 10) -> List[Chunk]

# 向量搜索 (如果 pgvector 可用)
def search_chunks_by_embedding(self, embedding: List[float], threshold: float = 0.8, limit: int = 10) -> List[Chunk]

# 混合搜索
def hybrid_search_chunks(self, text_query: str, embedding: List[float], text_weight: float = 0.5, vector_weight: float = 0.5, limit: int = 10) -> List[Chunk]

# 統計與分析
def get_resource_statistics(self, source_id: Optional[str] = None) -> Dict[str, int]
def get_chunk_statistics(self, resource_uuid: Optional[str] = None) -> Dict[str, int]
```

### 使用範例
```python
from client.client import create_client

# 創建客戶端
client = create_client()

# 健康檢查
status = client.health_check()
print(f"數據庫狀態: {status['status']}")

# 創建媒體來源
source = client.create_media_source(
    id="example_news",
    name="Example News",
    description="範例新聞來源",
    category="news",
    lang="zh-TW"
)

# 創建資源
resource = client.create_resource(
    remote_src_url="https://example.com/article-1",
    content_header="AI 技術發展趨勢",
    source_id="example_news",
    file_type="html",
    need_parsed=True
)

# 創建文字分塊
chunk = client.create_chunk(
    resource_uuid=resource.uuid,
    chunk_order=1,
    chunking_text="人工智慧技術正在快速發展，影響各個產業...",
    description="AI 發展概述"
)

# 全文搜索
results = client.search_chunks_by_text("人工智慧", limit=5)
for chunk in results:
    print(f"找到: {chunk.description}")

# 關閉連接
client.close()
```

---

## 💻 cli.py - 命令行工具

**強大的 CLI 操作介面**

### 主要功能
- **💻 命令行集成**：提供完整的 CLI 命令支持
- **📊 數據導入導出**：批量處理文檔與向量數據  
- **🔧 管理工具**：數據庫維護、統計查詢、健康檢查
- **🚀 腳本友好**：可與 Shell 腳本無縫集成自動化
- **📝 詳細日誌**：完整的操作日誌與進度顯示

### 核心 CLI 命令

#### **系統管理命令**
```python
class SystemCommands:
    """系統管理相關命令"""
    
    def health_check(self) -> None
        """執行系統健康檢查"""
        
    def show_status(self) -> None
        """顯示詳細系統狀態"""
        
    def database_stats(self) -> None
        """顯示數據庫統計信息"""
        
    def cleanup_database(self) -> None
        """清理數據庫無用數據"""
```

#### **資源管理命令**
```python
class ResourceCommands:
    """資源管理相關命令"""
    
    def list_sources(self) -> None
        """列出所有媒體來源"""
        
    def create_source(self, id: str, name: str, description: str) -> None
        """創建新的媒體來源"""
        
    def list_resources(self, source_id: Optional[str] = None) -> None
        """列出資源文檔"""
        
    def import_resources(self, file_path: str, source_id: str) -> None
        """批量導入資源文檔"""
        
    def export_resources(self, output_path: str, source_id: Optional[str] = None) -> None
        """導出資源文檔"""
```

#### **搜索與分析命令**
```python
class SearchCommands:
    """搜索與分析相關命令"""
    
    def search_text(self, query: str, limit: int = 10) -> None
        """執行全文搜索"""
        
    def search_similar(self, text: str, limit: int = 10) -> None
        """執行語意相似搜索"""
        
    def analyze_chunks(self, resource_uuid: Optional[str] = None) -> None
        """分析文字分塊統計"""
        
    def benchmark_search(self, queries_file: str) -> None
        """執行搜索性能基準測試"""
```

### CLI 使用範例
```bash
# 使用 Python 模組方式
python -m client.cli health-check
python -m client.cli list-sources
python -m client.cli search-text "AI 發展"
python -m client.cli import-resources articles.json example_news

# 使用 uv 運行
uv run python -m client.cli --help
uv run python -m client.cli database-stats
uv run python -m client.cli export-resources output.json --source example_news
```

---

## ⚙️ config.py - 配置管理

**智能的環境配置管理**

### 主要功能
- **🔧 環境讀取**：自動讀取 .env、環境變數、Supabase 狀態
- **✅ 配置驗證**：檢查必要配置項完整性與有效性
- **🔄 動態更新**：支持運行時配置更新與重載
- **🛡️ 安全處理**：敏感信息安全存儲與訪問控制
- **📋 預設管理**：智能預設值與配置繼承

### 核心配置類別

#### **Config 類別**
```python
class Config:
    """
    統一配置管理類別
    
    自動讀取並驗證所有必要的配置項：
    - Supabase 連接信息
    - 數據庫連接參數
    - API 密鑰與認證
    - 應用程式設定
    """
    
    # Supabase 配置
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    
    # 數據庫配置
    database_url: str
    database_host: str
    database_port: int
    database_name: str
    database_user: str
    database_password: str
    
    # 應用配置
    log_level: str = "INFO"
    max_retries: int = 3
    timeout: int = 30
    
    @classmethod
    def from_env(cls) -> 'Config'
    @classmethod
    def from_file(cls, file_path: str) -> 'Config'
    def validate(self) -> bool
    def to_dict(self) -> Dict[str, Any]
```

#### **配置讀取方法**
```python
# 環境變數讀取
def get_supabase_config() -> Dict[str, str]
    """從 Supabase CLI 狀態讀取配置"""

def get_database_config() -> Dict[str, str]
    """解析數據庫連接配置"""

def get_env_config(prefix: str = "SUPABASE_") -> Dict[str, str]
    """讀取指定前綴的環境變數"""

# 配置驗證
def validate_connection(config: Config) -> Tuple[bool, str]
    """驗證配置是否可用於連接"""

def check_required_config(config: Config) -> List[str]
    """檢查缺失的必要配置項"""
```

### 配置使用範例
```python
from client.config import Config, get_supabase_config

# 自動讀取配置
config = Config.from_env()

# 驗證配置
if config.validate():
    print("✅ 配置驗證成功")
else:
    print("❌ 配置驗證失敗")

# 手動配置
config = Config(
    supabase_url="http://localhost:54331",
    database_url="postgresql://postgres:postgres@localhost:54332/postgres",
    log_level="DEBUG"
)

# 從文件讀取
config = Config.from_file(".env.local")
```

---

## 🗄️ database.py - 數據庫 ORM

**RAG 系統專用數據庫抽象層**

### 主要功能
- **🗄️ 模型定義**：完整的 RAG 系統數據模型 (Resources, Chunks, etc.)
- **🔍 高級查詢**：複雜查詢、聚合、統計分析工具  
- **🧠 向量操作**：pgvector 向量搜索與相似度計算包裝器
- **⚡ 性能優化**：查詢優化、索引管理、連接池
- **🔄 遷移支持**：數據庫 schema 變更與版本管理

### 數據模型定義

#### **基礎模型類別**
```python
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, List, Dict, Any
from uuid import UUID

@dataclass
class MediaSource:
    """媒體來源模型"""
    id: str
    name: str
    description: str
    category: Optional[str] = None
    lang: Optional[str] = None
    config: Dict[str, Any] = None
    created_at: datetime = None

@dataclass  
class Resource:
    """資源文檔模型"""
    uuid: UUID
    local_src_url: Optional[str]
    remote_src_url: Optional[str]
    content_time: datetime
    content_header: str
    content_authors: Optional[List[str]]
    source_id: str
    file_type: Optional[str]
    need_parsed: bool = False
    crawl_completed: bool = False
    created_at: datetime = None
    updated_at: datetime = None
    content_sha256: Optional[bytes] = None

@dataclass
class Chunk:
    """文字分塊模型"""  
    uuid: UUID
    resource_uuid: UUID
    parsed_uuid: Optional[UUID]
    image_uuid: Optional[UUID]
    source_id: str
    page: Optional[int]
    chunk_order: int
    chunk_setting_id: Optional[int]
    token_size: Optional[int]
    chunking_text: str
    description: Optional[str]
    chunk_embedding: Optional[List[float]]
    description_embedding: Optional[List[float]]
    created_at: datetime = None
    updated_at: datetime = None
```

#### **查詢工具類別**
```python
class DatabaseQuery:
    """數據庫查詢工具集"""
    
    def __init__(self, connection_string: str)
    
    # 基礎 CRUD 操作
    def create(self, model: Any) -> Any
    def read(self, model_class: type, uuid: UUID) -> Optional[Any]
    def update(self, model: Any) -> bool
    def delete(self, model_class: type, uuid: UUID) -> bool
    
    # 批量操作
    def bulk_create(self, models: List[Any]) -> List[Any]
    def bulk_update(self, models: List[Any]) -> bool
    def bulk_delete(self, model_class: type, uuids: List[UUID]) -> int
    
    # 複雜查詢
    def query(self, sql: str, params: Dict[str, Any] = None) -> List[Dict[str, Any]]
    def aggregate(self, model_class: type, aggregations: Dict[str, str]) -> Dict[str, Any]
    def join_query(self, models: List[type], conditions: str) -> List[Dict[str, Any]]
```

#### **向量搜索工具**
```python
class VectorSearch:
    """pgvector 向量搜索包裝器"""
    
    def __init__(self, database_query: DatabaseQuery)
    
    # 向量操作
    def add_embedding(self, chunk_uuid: UUID, embedding: List[float], kind: str = "chunk") -> bool
    def update_embedding(self, chunk_uuid: UUID, embedding: List[float], kind: str = "chunk") -> bool
    def get_embedding(self, chunk_uuid: UUID, kind: str = "chunk") -> Optional[List[float]]
    
    # 相似度搜索
    def similarity_search(self, query_embedding: List[float], threshold: float = 0.8, limit: int = 10) -> List[Chunk]
    def cosine_similarity(self, embedding1: List[float], embedding2: List[float]) -> float
    def euclidean_distance(self, embedding1: List[float], embedding2: List[float]) -> float
    
    # 批量向量操作
    def batch_add_embeddings(self, embeddings: Dict[UUID, List[float]]) -> int
    def reindex_vectors(self, force: bool = False) -> bool
```

### 數據庫使用範例
```python
from client.database import DatabaseQuery, VectorSearch, Resource, Chunk
from client.config import Config

# 初始化數據庫連接
config = Config.from_env()
db = DatabaseQuery(config.database_url)

# 創建資源
resource = Resource(
    uuid=UUID("12345678-1234-5678-9012-123456789012"),
    remote_src_url="https://example.com/article",
    content_header="AI 發展趨勢",
    source_id="example_news",
    content_time=datetime.now()
)
created_resource = db.create(resource)

# 查詢資源
found_resource = db.read(Resource, resource.uuid)

# 複雜查詢
results = db.query(
    "SELECT * FROM resources WHERE source_id = %(source_id)s AND created_at > %(date)s",
    {"source_id": "example_news", "date": "2025-01-01"}
)

# 向量搜索
vector_search = VectorSearch(db)
embedding = [0.1, 0.2, 0.3, ...]  # 1536 維向量
similar_chunks = vector_search.similarity_search(embedding, threshold=0.85, limit=5)

# 統計查詢
stats = db.aggregate(Resource, {
    "total_count": "COUNT(*)",
    "avg_chunks": "AVG(chunk_count)",
    "latest_date": "MAX(created_at)"
})
```

---

## 🚀 快速開始

### 安裝與設定
```bash
# 確保 Supabase 服務運行
./scripts/start.sh

# 安裝 Python 依賴
uv sync

# 測試連接
python -c "from client.client import create_client; print('✅ 客戶端就緒')"
```

### 基本使用流程
```python
from client.client import create_client

# 1. 創建客戶端
client = create_client()

# 2. 檢查系統狀態
health = client.health_check()
print(f"系統狀態: {health['status']}")

# 3. 創建媒體來源
source = client.create_media_source(
    id="my_source",
    name="My Source",
    description="我的文檔來源"
)

# 4. 添加資源
resource = client.create_resource(
    remote_src_url="https://example.com/doc",
    content_header="重要文檔",
    source_id="my_source"
)

# 5. 創建文字分塊
chunk = client.create_chunk(
    resource_uuid=resource.uuid,
    chunk_order=1,
    chunking_text="這是文檔的重要內容..."
)

# 6. 搜索內容
results = client.search_chunks_by_text("重要")
for result in results:
    print(f"找到: {result.chunking_text[:50]}...")

# 7. 關閉連接
client.close()
```

---

## 🔧 開發與除錯

### 日誌配置
```python
import logging
from client.config import Config

# 設置日誌級別
config = Config.from_env()
config.log_level = "DEBUG"

logging.basicConfig(level=getattr(logging, config.log_level))
```

### 錯誤處理
```python
from client.client import create_client, SupabaseClientError

try:
    client = create_client()
    result = client.search_chunks_by_text("query")
except SupabaseClientError as e:
    print(f"客戶端錯誤: {e}")
except Exception as e:
    print(f"未預期錯誤: {e}")
```

### 性能優化
```python
# 使用批量操作
chunks_data = [...]  # 大量分塊數據
client.bulk_create_chunks(chunks_data)

# 連接池管理
client.configure_pool(min_connections=5, max_connections=20)

# 查詢優化
client.enable_query_cache(ttl=300)  # 5 分鐘緩存
```

---

## 📚 參考資源

- [Supabase Python 客戶端](https://supabase.com/docs/reference/python/introduction)
- [pgvector 文檔](https://github.com/pgvector/pgvector)
- [PostgreSQL Python 驅動](https://www.psycopg.org/psycopg3/)

---

**💡 提示**: 更多詳細範例和 API 參考，請參閱主項目 [README.md](../README.md)