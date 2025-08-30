# Supabase 本地自託管 RAG 系統

一個功能完整的 Supabase 本地部署解決方案，專為 StatementDog RAG (Retrieval-Augmented Generation) 系統設計，整合了 PostgreSQL + pgvector 向量資料庫、全文搜索、即時通訊和檔案存儲。

[![Python](https://img.shields.io/badge/Python-3.11%2B-blue.svg)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15%2B-green.svg)](https://postgresql.org)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://docker.com)
[![UV](https://img.shields.io/badge/UV-Package%20Manager-purple.svg)](https://github.com/astral-sh/uv)

## 🌟 核心特色

### 🏠 完全本地化部署
- **零雲端依賴**：完整的自託管方案，無需外部服務
- **生產就緒**：包含認證、授權、存儲、即時功能
- **容器化部署**：使用 Docker Compose 一鍵啟動所有服務
- **數據主權**：完全控制您的數據和隱私

### 🧠 智能 RAG 架構
- **多種搜索模式**：向量搜索、全文搜索、混合搜索
- **pgvector 整合**：高效能向量相似度計算
- **彈性嵌入模型**：支援多種 AI 模型的嵌入向量
- **智能分塊**：文檔智能切分和索引

### 🛠 開發者友好
- **統一客戶端**：整合 SQLAlchemy ORM 和 Supabase SDK
- **UV Workspace**：現代化 Python 依賴管理
- **CLI 工具**：命令列管理和操作介面
- **型別安全**：完整的 TypeScript/Python 型別定義

### 📊 企業級功能
- **Row Level Security**：精細的權限控制
- **即時通訊**：WebSocket 支援實時數據同步
- **檔案存儲**：S3 相容的對象存儲
- **監控儀表板**：Supabase Studio 管理介面

## 🏗 系統架構

```mermaid
graph TB
    subgraph "Client Layer"
        CLI[CLI Tools]
        SDK[Python SDK]
        APP[Applications]
    end
    
    subgraph "API Gateway"
        KONG[Kong Gateway]
        REST[REST API]
        GRAPHQL[GraphQL]
        REALTIME[Realtime]
    end
    
    subgraph "Core Services"
        AUTH[GoTrue Auth]
        STORAGE[Storage API]
        FUNCTIONS[Edge Functions]
    end
    
    subgraph "Database Layer"
        PG[(PostgreSQL 15)]
        VECTOR[pgvector]
        FTS[Full-Text Search]
    end
    
    subgraph "Management"
        STUDIO[Supabase Studio]
        LOGS[Logflare Analytics]
    end
    
    CLI --> KONG
    SDK --> KONG
    APP --> KONG
    
    KONG --> REST
    KONG --> GRAPHQL
    KONG --> REALTIME
    
    REST --> PG
    GRAPHQL --> PG
    AUTH --> PG
    STORAGE --> PG
    
    PG --> VECTOR
    PG --> FTS
    
    STUDIO --> PG
    LOGS --> PG
```

## 📁 專案結構

```
supabase/
├── 📋 README.md                    # 本文檔
├── 🐳 docker-compose.yml           # 容器編排配置
├── 📄 pyproject.toml               # Python 專案配置 (UV)
├── 🔧 supabase.sh                  # 管理腳本
├── 📝 .env.example                 # 環境變數範本
├── 🎯 uv-example.py                # Python SDK 使用範例
│
├── 📂 client/                      # Python 客戶端套件
│   ├── __init__.py                 # 套件初始化
│   ├── 🔗 client.py                # 統一客戶端類別
│   ├── ⚙️  config.py               # 配置管理
│   ├── 🗄 database.py              # SQLAlchemy ORM 模型
│   └── 💻 cli.py                   # 命令列工具
│
├── 📂 sql/                         # 資料庫 Schema
│   └── init_schema.sql             # RAG 系統初始 Schema
│
├── 📂 volumes/                     # 持久化數據 (Docker 掛載)
│   ├── db/                         # PostgreSQL 數據目錄
│   ├── storage/                    # 檔案存儲目錄
│   ├── logs/                       # 日誌檔案
│   └── api/                        # API Gateway 配置
│
└── 📂 tests/                       # 單元測試 (可選)
    ├── test_client.py
    ├── test_database.py
    └── fixtures/
```

## 🚀 快速開始

### 前置條件

確保您的系統已安裝以下工具：

- **Docker** 20.10+ ([安裝指南](https://docs.docker.com/get-docker/))
- **Docker Compose** 2.0+ ([安裝指南](https://docs.docker.com/compose/install/))
- **UV** 0.1.0+ ([安裝指南](https://github.com/astral-sh/uv#installation))

```bash
# 快速安裝 UV (推薦)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 驗證安裝
docker --version
docker compose version
uv --version
```

### 1. 🔄 初始設置

```bash
# 1. 克隆專案 (如果尚未完成)
git clone <your-repo> statementdog
cd statementdog/supabase

# 2. 首次設置 - 自動創建目錄和配置檔案
./supabase.sh setup

# 3. 配置環境變數 (重要！)
cp .env.example .env
nano .env  # 或使用您偏好的編輯器

# 4. ⚠️ 必須修改的安全設定
# - POSTGRES_PASSWORD: 設置強密碼
# - JWT_SECRET: 32字符隨機字符串
# - ANON_KEY & SERVICE_ROLE_KEY: 使用 JWT_SECRET 生成
```

### 2. 🔐 安全配置

編輯 `.env` 檔案並修改以下關鍵設定：

```bash
# 🔑 資料庫安全 (必須修改)
POSTGRES_PASSWORD=your_super_secure_password_here

# 🔑 JWT 設定 (必須修改)
JWT_SECRET=your_32_character_random_secret_key

# 🔑 API 金鑰 (使用 JWT_SECRET 生成)
ANON_KEY=your_generated_anon_key
SERVICE_ROLE_KEY=your_generated_service_role_key

# 📧 郵件設定 (可選，用於認證)
SMTP_HOST=smtp.gmail.com
SMTP_USER=your-email@gmail.com  
SMTP_PASS=your-app-password

# 🌐 公開 URL (用於回調)
SUPABASE_PUBLIC_URL=http://localhost:8000
```

> 💡 **API 金鑰生成**：使用 [Supabase JWT 產生器](https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys) 或參考 Supabase 官方文檔。

### 3. 🌟 啟動服務

```bash
# 啟動所有 Supabase 服務
./supabase.sh start

# 查看服務狀態
./supabase.sh status

# 查看日誌 (可選)
./supabase.sh logs
```

### 4. ✅ 驗證部署

```bash
# 健康檢查
curl http://localhost:8000/health

# 使用 Python 客戶端測試
uv run python -c "
from client import create_client
client = create_client()
print('✅ 連接成功:', client.health_check())
"
```

### 5. 🎯 訪問服務

啟動成功後，您可以訪問：

| 服務 | URL | 描述 |
|------|-----|------|
| 🎛 **Supabase Studio** | http://localhost:8000 | 管理介面和資料庫瀏覽器 |
| 🚀 **REST API** | http://localhost:8000/rest/v1 | RESTful API 端點 |
| 📡 **GraphQL** | http://localhost:8000/graphql/v1 | GraphQL 查詢介面 |
| ⚡ **Realtime** | ws://localhost:8000/realtime/v1 | WebSocket 即時通訊 |
| 🗃 **PostgreSQL** | localhost:5432 | 直接資料庫連接 |

## 📊 RAG 資料庫架構

### 核心資料表

我們的 RAG 系統採用了優化的資料庫結構，支援大規模文檔處理和高效能搜索：

```mermaid
erDiagram
    RESOURCES {
        uuid uuid PK
        remote_src_url text UK
        local_src_url text
        content_time timestamptz
        content_header text
        content_authors text
        src_name text
        src_description text
        src_category text
        file_type text
        need_parsed boolean
        crawl_completed boolean
        created_at timestamptz
        updated_at timestamptz
        content_sha256 bytea
        lang text
    }
    
    PARSED_ARTIFACTS {
        uuid uuid PK
        resource_uuid uuid FK
        local_parsed_url text
        parse_setting integer
        created_at timestamptz
        updated_at timestamptz
    }
    
    CHUNKS {
        uuid uuid PK
        resource_uuid uuid FK
        parsed_uuid uuid FK
        image_uuid uuid FK
        page integer
        chunk_order integer
        chunk_setting integer
        token_size integer
        chunking_text text
        description text
        chunk_embedding vector_1536_
        description_embedding vector_1536_
        created_at timestamptz
        updated_at timestamptz
    }
    
    IMAGES {
        uuid uuid PK
        resource_uuid uuid FK
        local_image_url text
        remote_image_url text UK
        description text
        width integer
        height integer
        mime_type text
        created_at timestamptz
        updated_at timestamptz
        image_sha256 bytea
    }
    
    CHUNK_EMBEDDINGS {
        chunk_uuid uuid FK
        kind text
        model text
        dim integer
        embedding vector
        created_at timestamptz
    }
    
    RESOURCES ||--o{ PARSED_ARTIFACTS : "generates"
    RESOURCES ||--o{ IMAGES : "contains"
    RESOURCES ||--o{ CHUNKS : "split_into"
    PARSED_ARTIFACTS ||--o{ CHUNKS : "produces"
    IMAGES ||--o{ CHUNKS : "references"
    CHUNKS ||--o{ CHUNK_EMBEDDINGS : "embeds"
```

### 1. 📄 **resources** - 資源主表

存儲所有原始文檔和資源：

```sql
CREATE TABLE resources (
    uuid              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    remote_src_url    text UNIQUE,                    -- 原始 URL
    local_src_url     text,                           -- 本地存儲路徑
    content_time      timestamptz,                    -- 內容發布時間
    content_header    text,                           -- 標題
    content_authors   text,                           -- 作者
    src_name          text,                           -- 來源名稱 (如 "Bloomberg", "AYZ")
    src_description   text,                           -- 來源描述
    src_category      text,                           -- 分類 (news, paper, blog, docs, web, internal, other)
    file_type         text,                           -- 檔案類型 (pdf, html, txt, image, audio, video, other)
    need_parsed       boolean NOT NULL DEFAULT false, -- 是否需要解析
    crawl_completed   boolean NOT NULL DEFAULT false, -- 是否已完成爬取
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    content_sha256    bytea,                          -- 內容雜湊 (去重)
    lang              text                            -- 語言代碼 (zh-TW, en, etc.)
);
```

### 2. 📝 **chunks** - 文本分塊表

智能分塊後的文本內容，支援向量和全文搜索：

```sql
CREATE TABLE chunks (
    uuid                    uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource_uuid           uuid NOT NULL REFERENCES resources(uuid),
    parsed_uuid             uuid REFERENCES parsed_artifacts(uuid),
    image_uuid              uuid REFERENCES images(uuid),
    
    page                    integer CHECK (page >= 0),      -- 頁碼 (PDF)
    chunk_order             integer NOT NULL CHECK (chunk_order >= 0), -- 順序
    chunk_setting           integer,                         -- 分塊配置 ID
    token_size              integer CHECK (token_size >= 0), -- Token 數量
    
    chunking_text           text NOT NULL,                   -- 分塊文本
    description             text,                            -- 摘要/描述
    
    -- 自動生成的全文搜索向量
    chunking_text_tsv       tsvector GENERATED ALWAYS AS (to_tsvector('simple', chunking_text)) STORED,
    description_tsv         tsvector GENERATED ALWAYS AS (to_tsvector('simple', description)) STORED,
    
    -- 向量嵌入 (1536 維 - OpenAI text-embedding-3-large)
    chunk_embedding         vector(1536),
    description_embedding   vector(1536),
    
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now()
);
```

### 3. 🖼 **images** - 圖片資源表

存儲與文檔相關的圖片資源：

```sql
CREATE TABLE images (
    uuid              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource_uuid     uuid REFERENCES resources(uuid),
    local_image_url   text,                           -- 本地存儲路徑
    remote_image_url  text UNIQUE,                    -- 原始圖片 URL
    description       text,                           -- 圖片描述
    width             integer,                        -- 寬度
    height            integer,                        -- 高度
    mime_type         text,                           -- MIME 類型
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    image_sha256      bytea                           -- 圖片雜湊
);
```

### 4. 🔧 **parsed_artifacts** - 解析產物表

存儲文檔解析的中間結果：

```sql
CREATE TABLE parsed_artifacts (
    uuid              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource_uuid     uuid NOT NULL REFERENCES resources(uuid),
    local_parsed_url  text,                          -- 解析產物存儲路徑
    parse_setting     integer NOT NULL,              -- 解析配置 ID
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
```

### 5. 🧮 **chunk_embeddings** - 多模型嵌入表

支援多種嵌入模型的向量存儲：

```sql
CREATE TABLE chunk_embeddings (
    chunk_uuid    uuid NOT NULL REFERENCES chunks(uuid),
    kind          text NOT NULL CHECK (kind IN ('chunk','description')),
    model         text NOT NULL,                      -- 模型名稱 (如 'text-embedding-3-large@1536')
    dim           integer NOT NULL,                   -- 向量維度
    embedding     vector,                            -- 向量數據
    created_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (chunk_uuid, kind, model)
);
```

### 🔍 搜索功能

系統內建三種強大的搜索功能：

#### 1. 向量語義搜索

```sql
-- 使用預訓練嵌入模型進行語義搜索
SELECT * FROM search_chunks_by_embedding(
    query_embedding := '[0.1, 0.2, 0.3, ...]'::vector(1536),
    match_threshold := 0.8,
    match_count := 10
);
```

#### 2. PostgreSQL 全文搜索

```sql
-- 使用 PostgreSQL 原生全文搜索
SELECT * FROM search_chunks_by_text(
    search_query := 'AI 人工智慧 機器學習',
    match_count := 10
);
```

#### 3. 混合搜索 (推薦)

```sql
-- 結合向量搜索和全文搜索的混合模式
SELECT * FROM hybrid_search_chunks(
    search_query := 'AI 機器學習',
    query_embedding := '[0.1, 0.2, ...]'::vector(1536),
    text_weight := 0.5,
    vector_weight := 0.5,
    match_count := 10
);
```

### 📈 效能最佳化

系統已預設最佳化配置：

```sql
-- 向量索引 (IVFFlat - 適合大規模數據)
CREATE INDEX idx_chunks_chunk_emb_ivf ON chunks 
    USING ivfflat (chunk_embedding vector_cosine_ops) 
    WITH (lists = 100);

-- 全文搜索索引 (GIN)
CREATE INDEX idx_chunks_text_gin ON chunks USING GIN (chunking_text_tsv);

-- 查詢最佳化設定
SET ivfflat.probes = 10;  -- 向量查詢精度調整
```

## 🐍 Python 客戶端完整指南

### UV Workspace 整合

本專案採用 UV 作為現代化的 Python 依賴管理工具，提供快速、可靠的開發體驗：

```bash
# 🚀 UV 的優勢
# - 10-100倍快於 pip/pipenv
# - 統一的 workspace 管理
# - 精確的依賴解析
# - 生產就緒的鎖定檔案

# 安裝所有依賴
uv sync

# 安裝特定功能組
uv sync --extra ai          # AI/嵌入功能
uv sync --extra monitoring  # 監控工具
uv sync --extra dev         # 開發工具

# 執行程式
uv run python script.py
uv run supabase-cli health
```

### 基本使用

#### 1. 快速連接

```python
"""
最簡單的使用方式 - 自動配置
"""
from client import create_client

# 使用預設配置 (自動載入 .env 檔案)
client = create_client()

# 健康檢查
health = client.health_check()
print(f"✅ 連接狀態: {health}")

# Context manager 自動資源清理
with create_client() as client:
    resources = client.get_all_resources()
    print(f"📊 總資源數: {len(resources)}")
```

#### 2. 自定義配置

```python
"""
進階配置 - 自定義連接參數
"""
from client import create_client, SupabaseConfig

# 自定義配置檔案
config = SupabaseConfig(
    env_file='production.env',  # 使用特定環境檔案
    database_url='postgresql://user:pass@localhost:5432/db',
    supabase_url='http://localhost:8000',
    supabase_key='your_anon_key'
)

client = create_client(config)

# 或直接傳入參數
client = create_client(
    database_url='postgresql://user:pass@localhost:5432/custom_db',
    supabase_url='http://custom-host:8000'
)
```

### 資料庫操作

#### 1. 資源管理 (Resources)

```python
"""
資源 (Resources) 完整操作範例
"""
from datetime import datetime
from client import create_client

client = create_client()

# 📝 創建新資源
resource = client.create_resource(
    remote_src_url='https://example.com/article/ai-breakthrough',
    content_header='AI 技術的重大突破',
    content_authors='張三, 李四',
    src_name='TechNews',
    src_description='科技新聞媒體',
    src_category='news',           # 可彈性使用任何字符串
    file_type='html',              # 支援: html, pdf, txt, image, audio, video, other
    content_time=datetime.now(),
    need_parsed=True,
    lang='zh-TW'
)
print(f"✅ 創建資源: {resource.uuid}")

# 🔍 查詢資源
# 依 UUID 查詢
resource = client.get_resource(resource.uuid)

# 依 URL 查詢 (避免重複)
existing = client.get_resources_by_url('https://example.com/article/ai-breakthrough')

# 依分類查詢
news_resources = client.get_resources_by_category('news', limit=50)

# 取得所有資源 (分頁)
all_resources = client.get_all_resources(limit=100, offset=0)

# 🔄 更新資源
updated_resource = client.update_resource(
    resource.uuid,
    content_header='AI 技術的驚人突破 (更新版)',
    crawl_completed=True,
    file_type='pdf'  # 更新檔案類型
)

# 🗑 刪除資源 (級聯刪除相關數據)
# client.delete_resource(resource.uuid)  # 謹慎使用
```

#### 2. 文本分塊 (Chunks)

```python
"""
文本分塊 (Chunks) 完整操作範例
"""
import numpy as np

# 📝 創建文本分塊
chunk = client.create_chunk(
    resource_uuid=resource.uuid,
    chunk_order=1,                          # 在文檔中的順序
    chunking_text='''
    人工智慧 (AI) 技術在近年來發展迅速，特別是在自然語言處理領域。
    大型語言模型 (LLM) 如 ChatGPT、Claude 等，已經展現出驚人的能力。
    這些模型能夠理解複雜的語言結構，並產生高品質的文本內容。
    ''',
    description='AI 技術發展概述 - 重點介紹自然語言處理和大型語言模型',
    page=1,                                 # PDF 頁碼 (可選)
    chunk_setting=1,                        # 分塊配置 ID
    token_size=150,                         # Token 數量
    # 嵌入向量 (1536 維 - OpenAI text-embedding-3-large)
    chunk_embedding=np.random.rand(1536).tolist(),
    description_embedding=np.random.rand(1536).tolist()
)

# 🔍 查詢分塊
# 依資源查詢所有分塊
resource_chunks = client.get_chunks_by_resource(resource.uuid)

# 依順序查詢
ordered_chunks = client.get_chunks_by_resource(resource.uuid, order_by='chunk_order')

# 🔄 更新分塊
updated_chunk = client.update_chunk(
    chunk.uuid,
    description='更新後的描述',
    chunk_embedding=new_embedding_vector
)
```

#### 3. 圖片資源 (Images)

```python
"""
圖片資源 (Images) 操作範例
"""
# 📝 創建圖片記錄
image = client.create_image(
    resource_uuid=resource.uuid,
    remote_image_url='https://example.com/images/ai-chart.png',
    local_image_url='/storage/images/ai-chart-local.png',
    description='AI 技術發展趨勢圖表',
    width=1920,
    height=1080,
    mime_type='image/png'
)

# 🔍 查詢圖片
resource_images = client.get_images_by_resource(resource.uuid)

# 依 URL 查詢
image_by_url = client.get_images_by_url('https://example.com/images/ai-chart.png')
```

### 高級搜索功能

#### 1. 全文搜索

```python
"""
PostgreSQL 原生全文搜索
支援中文、英文和多語言搜索
"""
# 基本全文搜索
results = client.search_chunks_by_text(
    search_query='AI 人工智慧 機器學習',
    limit=20
)

for result in results:
    print(f"📄 {result['chunk_uuid']}")
    print(f"📝 內容: {result['chunking_text'][:100]}...")
    print(f"🎯 相關度: {result['rank']:.3f}")
    print("---")

# 使用 PostgreSQL 全文搜索操作符
advanced_results = client.search_chunks_by_text(
    # & = AND, | = OR, ! = NOT, <-> = 相鄰
    search_query='(AI | 人工智慧) & (機器學習 | 深度學習)',
    limit=10
)

# 搜索特定資源的分塊
resource_search = client.search_chunks_by_text(
    search_query='自然語言處理',
    resource_uuid=resource.uuid,  # 限定搜索範圍
    limit=10
)
```

#### 2. 向量語義搜索

```python
"""
使用嵌入向量進行語義搜索
適合語義相似性查詢
"""
import openai  # 範例使用 OpenAI

# 生成查詢嵌入向量
query_text = "深度學習在自然語言處理中的應用"
query_embedding = openai.Embedding.create(
    model="text-embedding-3-large",
    input=query_text
)['data'][0]['embedding']

# 向量搜索
vector_results = client.search_chunks_by_embedding(
    embedding=query_embedding,
    threshold=0.75,        # 相似度閾值 (0-1)
    limit=15
)

for result in vector_results:
    print(f"🧠 語義相似度: {result['similarity']:.3f}")
    print(f"📝 內容: {result['chunking_text'][:150]}...")
    print("---")

# 使用描述嵌入搜索 (通常更精確)
description_results = client.search_chunks_by_description_embedding(
    embedding=query_embedding,
    threshold=0.8,
    limit=10
)
```

#### 3. 混合搜索 (推薦)

```python
"""
混合搜索結合全文搜索和向量搜索的優點
提供最佳的搜索體驗
"""
# 混合搜索 - 平衡權重
hybrid_results = client.hybrid_search_chunks(
    text_query='AI 機器學習 深度學習',
    embedding=query_embedding,
    text_weight=0.4,      # 全文搜索權重
    vector_weight=0.6,    # 向量搜索權重
    limit=20
)

# 偏向關鍵字搜索的混合搜索
keyword_focused = client.hybrid_search_chunks(
    text_query='特定技術名詞 API 接口',
    embedding=query_embedding,
    text_weight=0.8,      # 更高的文本權重
    vector_weight=0.2,
    limit=15
)

# 偏向語義搜索的混合搜索
semantic_focused = client.hybrid_search_chunks(
    text_query='相關概念',
    embedding=query_embedding,
    text_weight=0.2,
    vector_weight=0.8,    # 更高的向量權重
    limit=15
)

# 處理搜索結果
for result in hybrid_results:
    print(f"🎯 綜合分數: {result['combined_score']:.3f}")
    print(f"📖 資源: {result['resource_uuid']}")
    print(f"📝 內容: {result['chunking_text'][:200]}...")
    if result['description']:
        print(f"📋 描述: {result['description']}")
    print("=" * 50)
```

### 認證與授權

```python
"""
用戶認證和權限管理
"""
# 用戶註冊
signup_result = client.sign_up(
    email='user@example.com',
    password='SecurePassword123!'
)
print(f"✅ 註冊成功: {signup_result.user.email}")

# 用戶登入
signin_result = client.sign_in(
    email='user@example.com', 
    password='SecurePassword123!'
)
print(f"🔑 登入成功: {signin_result.session.access_token}")

# 取得當前用戶
current_user = client.get_user()
if current_user:
    print(f"👤 當前用戶: {current_user.email}")

# 登出
client.sign_out()
print("👋 已登出")

# 重設密碼
client.reset_password('user@example.com')
```

### 檔案存儲

```python
"""
Supabase Storage - S3 相容的對象存儲
"""
# 創建存儲桶
bucket = client.create_bucket('documents')

# 上傳檔案
with open('document.pdf', 'rb') as file:
    upload_result = client.upload_file(
        bucket='documents',
        path='papers/ai-research.pdf',
        file_data=file.read(),
        content_type='application/pdf'
    )

# 下載檔案
file_data = client.download_file('documents', 'papers/ai-research.pdf')
with open('downloaded.pdf', 'wb') as file:
    file.write(file_data)

# 取得檔案公開 URL
public_url = client.get_file_url('documents', 'papers/ai-research.pdf')
print(f"🔗 公開連結: {public_url}")

# 刪除檔案
client.delete_file('documents', 'papers/ai-research.pdf')
```

### 即時通訊 (Realtime)

```python
"""
WebSocket 即時數據同步
"""
def handle_resource_changes(payload):
    """處理資源表變更事件"""
    event_type = payload['eventType']  # INSERT, UPDATE, DELETE
    record = payload['new'] if payload['new'] else payload['old']
    
    if event_type == 'INSERT':
        print(f"📄 新增資源: {record['content_header']}")
    elif event_type == 'UPDATE':
        print(f"🔄 更新資源: {record['content_header']}")
    elif event_type == 'DELETE':
        print(f"🗑 刪除資源: {record['uuid']}")

def handle_chunk_changes(payload):
    """處理文本分塊變更事件"""
    print(f"📝 文本分塊變更: {payload['eventType']}")

# 訂閱資源表變更
resource_channel = client.subscribe_to_changes(
    table='resources',
    callback=handle_resource_changes
)

# 訂閱文本分塊變更
chunk_channel = client.subscribe_to_changes(
    table='chunks', 
    callback=handle_chunk_changes,
    filter_column='resource_uuid',     # 可選：過濾特定資源
    filter_value=resource.uuid
)

# 保持連接
print("🔗 即時監聽已啟動，按 Ctrl+C 停止...")
try:
    import time
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    # 取消訂閱
    resource_channel.unsubscribe()
    chunk_channel.unsubscribe()
    print("👋 已停止監聽")
```

## 🖥 命令列工具 (CLI)

本系統提供了功能強大的 CLI 工具，方便管理和操作：

### 安裝與基本使用

```bash
# CLI 工具已隨套件安裝，可直接使用
uv run supabase-cli --help

# 或在 UV shell 中使用
uv shell
supabase-cli --help
```

### 系統管理

```bash
# 🔍 健康檢查
uv run supabase-cli health
# 輸出: ✅ 系統健康 - PostgreSQL: OK, Supabase: OK

# 📊 系統統計
uv run supabase-cli stats
# 顯示：資源數、分塊數、圖片數等統計資訊

# 🔧 資料庫連接測試
uv run supabase-cli db test-connection
```

### 資源管理

```bash
# 📋 列出資源
uv run supabase-cli resource list --limit 20
uv run supabase-cli resource list --category news
uv run supabase-cli resource list --format json

# ➕ 創建資源
uv run supabase-cli resource create \
    --url "https://example.com/article" \
    --title "AI 技術新突破" \
    --source "TechNews" \
    --category "news" \
    --file-type "html"

# 🔍 查詢特定資源
uv run supabase-cli resource get <uuid>
uv run supabase-cli resource get --url "https://example.com/article"

# 🔄 更新資源
uv run supabase-cli resource update <uuid> \
    --title "更新後的標題" \
    --completed true

# 🗑 刪除資源 (謹慎使用)
uv run supabase-cli resource delete <uuid> --confirm
```

### 搜索功能

```bash
# 🔍 全文搜索
uv run supabase-cli search text "AI 機器學習" --limit 10

# 🧠 向量搜索 (需要先準備嵌入向量)
uv run supabase-cli search vector \
    --embedding-file embeddings.json \
    --threshold 0.8 \
    --limit 15

# 🎯 混合搜索
uv run supabase-cli search hybrid \
    --query "深度學習" \
    --embedding-file embeddings.json \
    --text-weight 0.4 \
    --vector-weight 0.6
```

### 數據管理

```bash
# 📥 導入數據
uv run supabase-cli data import --file resources.json
uv run supabase-cli data import --csv resources.csv --table resources

# 📤 導出數據
uv run supabase-cli data export --table resources --format json
uv run supabase-cli data export --table chunks --limit 1000

# 🔄 資料遷移
uv run supabase-cli migration run --file sql/custom_migration.sql
```

## 🔧 系統管理腳本

`supabase.sh` 是系統的核心管理腳本，提供完整的生命週期管理：

### 基本操作

```bash
# 🚀 首次設置 (包含依賴安裝)
./supabase.sh setup

# ▶️ 啟動所有服務
./supabase.sh start

# ⏹ 停止所有服務
./supabase.sh stop

# 🔄 重啟服務
./supabase.sh restart

# 📊 查看服務狀態
./supabase.sh status

# 📋 查看所有可用命令
./supabase.sh help
```

### 開發工具

```bash
# 🐍 進入 Python 開發環境
./supabase.sh python

# 📦 安裝/更新依賴
./supabase.sh install

# 🧪 執行測試
./supabase.sh test

# 📏 程式碼品質檢查
./supabase.sh lint

# 🎨 程式碼格式化
./supabase.sh format

# 📊 型別檢查
./supabase.sh typecheck
```

### 數據管理

```bash
# 💾 備份資料庫
./supabase.sh backup
# 創建: backup_20241220_143022.sql.gz

# 🔄 從備份還原
./supabase.sh restore backup_20241220_143022.sql.gz

# 🗑 清理所有資料 (謹慎使用)
./supabase.sh clean --confirm

# 🧹 清理 Docker 資源
./supabase.sh cleanup
```

### 監控與除錯

```bash
# 📋 查看所有服務日誌
./supabase.sh logs

# 📋 查看特定服務日誌
./supabase.sh logs db        # 資料庫日誌
./supabase.sh logs auth      # 認證服務
./supabase.sh logs storage   # 存儲服務
./supabase.sh logs kong      # API Gateway
./supabase.sh logs studio    # 管理介面

# 🔍 即時監控日誌
./supabase.sh logs --follow

# 💻 進入 PostgreSQL CLI
./supabase.sh psql

# 🐳 進入容器 shell
./supabase.sh shell db       # 資料庫容器
./supabase.sh shell kong     # API Gateway 容器
```

### 維護與更新

```bash
# 🔄 更新到最新版本 (自動備份)
./supabase.sh update

# 🔧 重建所有容器
./supabase.sh rebuild

# 🩺 系統健康檢查
./supabase.sh health

# 📊 系統資源使用情況
./supabase.sh resources

# 🔍 檢查配置檔案
./supabase.sh validate-config
```

## 🔒 安全與權限管理

### Row Level Security (RLS)

系統預設啟用了 Row Level Security，提供精細的權限控制：

```sql
-- 檢視現有權限政策
SELECT schemaname, tablename, policyname, qual, with_check 
FROM pg_policies 
WHERE schemaname = 'public';

-- 自定義權限政策範例
-- 允許用戶只能查看自己創建的資源
CREATE POLICY "Users can view own resources" ON resources
    FOR SELECT USING (auth.uid() = created_by);

-- 允許特定角色管理所有資源
CREATE POLICY "Admins can manage all resources" ON resources
    FOR ALL USING (auth.jwt() ->> 'role' = 'admin');
```

### API 金鑰管理

```bash
# 生成新的 JWT 金鑰
openssl rand -base64 32

# 使用 Supabase CLI 生成 API 金鑰
npx supabase gen keys --project-ref YOUR_PROJECT_ID
```

### 環境變數安全檢查清單

確保生產環境中修改以下設定：

- [ ] `POSTGRES_PASSWORD` - 使用強密碼 (至少 16 字符)
- [ ] `JWT_SECRET` - 32 字符隨機字符串
- [ ] `ANON_KEY` - 使用 JWT_SECRET 生成
- [ ] `SERVICE_ROLE_KEY` - 使用 JWT_SECRET 生成
- [ ] `DASHBOARD_USERNAME` & `DASHBOARD_PASSWORD` - 管理介面認證
- [ ] 郵件設定 (如果使用認證功能)
- [ ] SSL 證書配置 (生產環境)

## 📊 效能最佳化與監控

### 資料庫效能調校

```sql
-- 1. 向量搜索最佳化
-- 調整 IVFFlat 索引參數
SET ivfflat.probes = 10;  -- 增加精確度 (預設: 1)

-- 重建向量索引 (數據量大時執行)
REINDEX INDEX CONCURRENTLY idx_chunks_chunk_emb_ivf;

-- 2. 全文搜索最佳化
-- 更新統計資訊
ANALYZE chunks;

-- 調整 PostgreSQL 全文搜索配置
SET default_text_search_config = 'simple';  -- 或 'english', 'chinese' 等

-- 3. 查詢效能分析
-- 分析慢查詢
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM search_chunks_by_embedding('[0.1,0.2,...]', 0.8, 10);

-- 檢視索引使用情況
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;
```

### 系統監控

```python
"""
系統監控和健康檢查
"""
from client import create_client

client = create_client()

# 取得系統統計資訊
stats = client.get_database_statistics()
print(f"📊 系統統計:")
print(f"   資源數: {stats['resources_count']:,}")
print(f"   分塊數: {stats['chunks_count']:,}")
print(f"   圖片數: {stats['images_count']:,}")
print(f"   分類統計: {stats['by_category']}")

# 檢查資料庫連接
health = client.health_check()
print(f"🔍 健康狀態: {health}")

# 監控搜索效能
import time
start_time = time.time()
results = client.search_chunks_by_text("測試查詢", limit=100)
search_time = time.time() - start_time
print(f"⚡ 搜索耗時: {search_time:.3f} 秒")
```

### Docker 資源限制

編輯 `docker-compose.yml` 設定資源限制：

```yaml
services:
  db:
    # 資料庫記憶體限制
    mem_limit: 2g
    memswap_limit: 2g
    
    # CPU 限制
    cpus: 2.0
    
    # 設定 PostgreSQL 參數
    environment:
      POSTGRES_INITDB_ARGS: "--data-checksums"
    command: |
      postgres 
      -c shared_preload_libraries=vector
      -c max_connections=200
      -c shared_buffers=512MB
      -c effective_cache_size=1536MB
      -c maintenance_work_mem=64MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100
```

## 🔄 備份與災難復原

### 自動備份策略

```bash
# 設定 cron 定期備份
crontab -e

# 每日凌晨 2 點備份
0 2 * * * /path/to/supabase/supabase.sh backup

# 每週日凌晨 3 點清理舊備份 (保留 30 天)
0 3 * * 0 find /path/to/supabase/backups -name "*.sql.gz" -mtime +30 -delete
```

### 災難復原流程

```bash
# 1. 停止服務
./supabase.sh stop

# 2. 清理現有資料 (謹慎!)
./supabase.sh clean --confirm

# 3. 重新設置
./supabase.sh setup

# 4. 從備份還原
./supabase.sh restore backup_20241220_143022.sql.gz

# 5. 驗證資料完整性
./supabase.sh psql -c "SELECT COUNT(*) FROM resources;"

# 6. 重啟服務
./supabase.sh start
```

### 跨環境遷移

```bash
# 源環境備份
./supabase.sh backup --full

# 目標環境還原
scp backup_20241220_143022.sql.gz target-server:/path/to/supabase/
ssh target-server "cd /path/to/supabase && ./supabase.sh restore backup_20241220_143022.sql.gz"
```

## 🐛 故障排除指南

### 常見問題與解決方案

#### 1. 🚫 無法啟動服務

**症狀**: `./supabase.sh start` 失敗

**診斷步驟**:
```bash
# 檢查 Docker 狀態
docker ps -a
docker compose logs

# 檢查端口佔用
netstat -tlnp | grep 8000
netstat -tlnp | grep 5432

# 檢查磁碟空間
df -h
```

**解決方案**:
```bash
# 停止衝突服務
sudo systemctl stop postgresql  # 如果本機有 PostgreSQL

# 清理 Docker 資源
docker system prune -f

# 重新啟動
./supabase.sh restart
```

#### 2. 🔍 向量搜索效能問題

**症狀**: 向量搜索回應緩慢

**診斷**:
```sql
-- 檢查索引是否存在
SELECT indexname FROM pg_indexes WHERE tablename = 'chunks';

-- 檢查數據量
SELECT COUNT(*) FROM chunks WHERE chunk_embedding IS NOT NULL;

-- 分析查詢計劃
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM chunks 
ORDER BY chunk_embedding <=> '[0.1,0.2,...]' 
LIMIT 10;
```

**解決方案**:
```sql
-- 如果缺少索引，重新創建
CREATE INDEX CONCURRENTLY idx_chunks_chunk_emb_ivf ON chunks 
    USING ivfflat (chunk_embedding vector_cosine_ops) 
    WITH (lists = 100);

-- 調整查詢參數
SET ivfflat.probes = 10;

-- 更新統計資訊
ANALYZE chunks;
```

#### 3. 🔑 認證問題

**症狀**: API 呼叫返回 401 Unauthorized

**檢查項目**:
```bash
# 檢查環境變數
cat .env | grep -E "(JWT_SECRET|ANON_KEY|SERVICE_ROLE_KEY)"

# 驗證 API 金鑰
curl -H "apikey: YOUR_ANON_KEY" http://localhost:8000/rest/v1/health
```

**解決方案**:
1. 重新生成 JWT secret 和 API 金鑰
2. 更新 `.env` 檔案
3. 重啟服務

#### 4. 💾 資料庫連接問題

**症狀**: Python 客戶端無法連接資料庫

**診斷**:
```python
# 測試資料庫連接
import psycopg2
try:
    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="postgres",
        user="postgres",
        password="YOUR_POSTGRES_PASSWORD"
    )
    print("✅ 資料庫連接成功")
except Exception as e:
    print(f"❌ 連接失敗: {e}")
```

**解決方案**:
```bash
# 檢查資料庫容器狀態
docker compose logs db

# 重啟資料庫
docker compose restart db

# 檢查資料庫初始化
./supabase.sh psql -c "\dt"
```

### 日誌分析

```bash
# 查看特定時間範圍的日誌
./supabase.sh logs --since="2024-12-20T10:00:00" --until="2024-12-20T11:00:00"

# 過濾錯誤日誌
./supabase.sh logs | grep -i error

# 監控即時日誌
./supabase.sh logs --follow | grep -i "error\|warning\|exception"

# 查看資料庫慢查詢
./supabase.sh psql -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
"
```

## 🔌 整合與擴展

### 整合到 StatementDog 爬蟲系統

```python
"""
在媒體來源爬蟲中使用 Supabase
範例：Bloomberg 爬蟲整合
"""
from supabase.client import create_client
from datetime import datetime

class BloombergCrawler:
    def __init__(self):
        self.supabase_client = create_client()
    
    def crawl_article(self, url: str):
        """爬取單篇文章並存入 Supabase"""
        
        # 檢查是否已存在
        existing = self.supabase_client.get_resources_by_url(url)
        if existing:
            print(f"📄 文章已存在: {url}")
            return existing
        
        # 爬取文章內容
        article_data = self.scrape_article(url)
        
        # 創建資源記錄
        resource = self.supabase_client.create_resource(
            remote_src_url=url,
            content_header=article_data['title'],
            content_authors=article_data['authors'],
            src_name='Bloomberg',
            src_description='財經新聞媒體',
            src_category='news',
            file_type='html',
            content_time=article_data['published_at'],
            need_parsed=True
        )
        
        # 處理圖片
        for img_url in article_data['images']:
            self.supabase_client.create_image(
                resource_uuid=resource.uuid,
                remote_image_url=img_url,
                description=f"Bloomberg 文章圖片: {article_data['title']}"
            )
        
        # 文本分塊和嵌入
        chunks = self.process_text_chunks(
            text=article_data['content'], 
            resource=resource
        )
        
        # 標記為已完成
        self.supabase_client.update_resource(
            resource.uuid,
            crawl_completed=True
        )
        
        return resource
    
    def process_text_chunks(self, text: str, resource):
        """處理文本分塊和嵌入向量"""
        import openai
        
        # 智能分塊 (範例)
        chunks = self.smart_chunking(text)
        
        created_chunks = []
        for i, chunk_text in enumerate(chunks):
            # 生成嵌入向量
            embedding = openai.Embedding.create(
                model="text-embedding-3-large",
                input=chunk_text
            )['data'][0]['embedding']
            
            # 創建分塊記錄
            chunk = self.supabase_client.create_chunk(
                resource_uuid=resource.uuid,
                chunk_order=i + 1,
                chunking_text=chunk_text,
                chunk_embedding=embedding,
                token_size=len(chunk_text.split())
            )
            created_chunks.append(chunk)
        
        return created_chunks
```

### API 整合範例

```python
"""
RESTful API 整合
"""
import requests

# 使用 Supabase REST API
def query_resources_api(supabase_url: str, api_key: str):
    """透過 REST API 查詢資源"""
    
    headers = {
        'apikey': api_key,
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }
    
    # 查詢最新 10 篇新聞
    response = requests.get(
        f"{supabase_url}/rest/v1/resources",
        headers=headers,
        params={
            'select': 'uuid,content_header,src_name,content_time',
            'src_category': 'eq.news',
            'order': 'content_time.desc',
            'limit': 10
        }
    )
    
    return response.json()

# GraphQL 查詢
def query_with_graphql(supabase_url: str, api_key: str):
    """使用 GraphQL 查詢"""
    
    query = """
    query GetResourcesWithChunks {
        resources(
            filter: { src_category: { eq: "news" } }
            orderBy: { content_time: DESC }
            first: 5
        ) {
            uuid
            content_header
            src_name
            chunks {
                uuid
                chunking_text
            }
        }
    }
    """
    
    response = requests.post(
        f"{supabase_url}/graphql/v1",
        headers={
            'apikey': api_key,
            'Content-Type': 'application/json'
        },
        json={'query': query}
    )
    
    return response.json()
```

### 自定義擴展

```python
"""
擴展客戶端功能
"""
from client import SupabaseClient

class CustomRAGClient(SupabaseClient):
    """自定義 RAG 客戶端 - 擴展功能"""
    
    def semantic_search_with_context(self, query: str, context_window: int = 3):
        """語義搜索並返回上下文分塊"""
        
        # 生成查詢嵌入
        query_embedding = self.generate_embedding(query)
        
        # 執行向量搜索
        results = self.search_chunks_by_embedding(
            embedding=query_embedding,
            threshold=0.7,
            limit=20
        )
        
        # 為每個結果添加上下文分塊
        enriched_results = []
        for result in results:
            # 取得相鄰分塊作為上下文
            context_chunks = self.get_context_chunks(
                resource_uuid=result['resource_uuid'],
                chunk_order=result['chunk_order'],
                window=context_window
            )
            
            result['context'] = context_chunks
            enriched_results.append(result)
        
        return enriched_results
    
    def get_context_chunks(self, resource_uuid: str, chunk_order: int, window: int):
        """取得上下文分塊"""
        
        min_order = max(1, chunk_order - window)
        max_order = chunk_order + window
        
        return self.db.session.query(self.db.Chunk).filter(
            self.db.Chunk.resource_uuid == resource_uuid,
            self.db.Chunk.chunk_order.between(min_order, max_order)
        ).order_by(self.db.Chunk.chunk_order).all()
    
    def generate_summary(self, resource_uuid: str):
        """使用 AI 生成資源摘要"""
        
        resource = self.get_resource(resource_uuid)
        chunks = self.get_chunks_by_resource(resource_uuid)
        
        # 組合所有分塊內容
        full_text = "\n".join([chunk.chunking_text for chunk in chunks])
        
        # 呼叫 AI API 生成摘要 (範例)
        summary = self.call_ai_summarization(full_text)
        
        # 更新資源描述
        self.update_resource(resource_uuid, src_description=summary)
        
        return summary
```

## 📚 進階配置

### 自定義 Docker 配置

#### 生產環境優化

```yaml
# docker-compose.prod.yml
version: "3.8"

services:
  db:
    image: postgres:15-alpine
    restart: always
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
    volumes:
      - ./volumes/db:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    # 生產環境資源限制
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
        reservations:
          memory: 2G
          cpus: '1.0'
    # PostgreSQL 效能調校
    command: |
      postgres
      -c shared_preload_libraries=vector
      -c max_connections=100
      -c shared_buffers=1GB
      -c effective_cache_size=3GB
      -c maintenance_work_mem=256MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100
      -c random_page_cost=1.1
      -c effective_io_concurrency=200

  # 反向代理 (生產環境)
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/ssl:ro
    depends_on:
      - kong
```

#### SSL 配置

```nginx
# nginx.conf
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /etc/ssl/cert.pem;
    ssl_certificate_key /etc/ssl/key.pem;
    
    location / {
        proxy_pass http://kong:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Schema 擴展

#### 添加自定義表格

```sql
-- sql/02_custom_extensions.sql
-- 文章評分表
CREATE TABLE IF NOT EXISTS article_ratings (
    id SERIAL PRIMARY KEY,
    resource_uuid uuid NOT NULL REFERENCES resources(uuid) ON DELETE CASCADE,
    user_id uuid,
    rating integer CHECK (rating >= 1 AND rating <= 5),
    comment text,
    created_at timestamptz NOT NULL DEFAULT now(),
    
    UNIQUE(resource_uuid, user_id)
);

-- 標籤系統
CREATE TABLE IF NOT EXISTS tags (
    id SERIAL PRIMARY KEY,
    name text UNIQUE NOT NULL,
    description text,
    color text DEFAULT '#blue',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS resource_tags (
    resource_uuid uuid NOT NULL REFERENCES resources(uuid) ON DELETE CASCADE,
    tag_id integer NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    
    PRIMARY KEY (resource_uuid, tag_id)
);

-- 搜索歷史
CREATE TABLE IF NOT EXISTS search_history (
    id SERIAL PRIMARY KEY,
    user_id uuid,
    query_text text,
    query_type text CHECK (query_type IN ('text', 'vector', 'hybrid')),
    results_count integer,
    search_time_ms integer,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- 創建索引
CREATE INDEX idx_article_ratings_resource ON article_ratings(resource_uuid);
CREATE INDEX idx_resource_tags_resource ON resource_tags(resource_uuid);
CREATE INDEX idx_resource_tags_tag ON resource_tags(tag_id);
CREATE INDEX idx_search_history_user ON search_history(user_id);
CREATE INDEX idx_search_history_created ON search_history(created_at);
```

#### 自定義搜索函數

```sql
-- sql/03_custom_functions.sql
-- 帶標籤過濾的搜索
CREATE OR REPLACE FUNCTION search_chunks_with_tags(
    search_query text,
    tag_names text[] DEFAULT NULL,
    match_count int DEFAULT 10
)
RETURNS TABLE (
    chunk_uuid uuid,
    resource_uuid uuid,
    chunking_text text,
    description text,
    rank float,
    tags text[]
)
LANGUAGE sql STABLE
AS $$
    WITH tagged_resources AS (
        SELECT DISTINCT r.uuid as resource_uuid,
               array_agg(t.name) as tags
        FROM resources r
        LEFT JOIN resource_tags rt ON r.uuid = rt.resource_uuid
        LEFT JOIN tags t ON rt.tag_id = t.id
        WHERE tag_names IS NULL 
           OR t.name = ANY(tag_names)
        GROUP BY r.uuid
    )
    SELECT 
        c.uuid,
        c.resource_uuid,
        c.chunking_text,
        c.description,
        ts_rank(c.chunking_text_tsv, websearch_to_tsquery('simple', search_query)) as rank,
        tr.tags
    FROM chunks c
    INNER JOIN tagged_resources tr ON c.resource_uuid = tr.resource_uuid
    WHERE c.chunking_text_tsv @@ websearch_to_tsquery('simple', search_query)
    ORDER BY rank DESC
    LIMIT match_count;
$$;

-- 熱門搜索統計
CREATE OR REPLACE FUNCTION get_popular_searches(
    days_back int DEFAULT 7,
    limit_count int DEFAULT 10
)
RETURNS TABLE (
    query_text text,
    search_count bigint,
    avg_results integer
)
LANGUAGE sql STABLE
AS $$
    SELECT 
        query_text,
        COUNT(*) as search_count,
        AVG(results_count)::integer as avg_results
    FROM search_history
    WHERE created_at >= now() - interval '1 day' * days_back
    GROUP BY query_text
    ORDER BY search_count DESC
    LIMIT limit_count;
$$;
```

## 🧪 測試與品質保證

### 單元測試

```python
"""
tests/test_client.py - 客戶端測試
"""
import pytest
from datetime import datetime
from client import create_client, SupabaseConfig

@pytest.fixture
def client():
    """測試客戶端 fixture"""
    config = SupabaseConfig(env_file='.env.test')
    return create_client(config)

@pytest.fixture
def sample_resource_data():
    """範例資源數據"""
    return {
        'remote_src_url': 'https://test.example.com/article/123',
        'content_header': 'Test Article Title',
        'content_authors': 'Test Author',
        'src_name': 'Test Source',
        'src_description': 'Test Description',
        'src_category': 'test',
        'file_type': 'html',
        'content_time': datetime.now(),
        'lang': 'en'
    }

class TestSupabaseClient:
    """Supabase 客戶端測試套件"""
    
    def test_health_check(self, client):
        """測試健康檢查"""
        health = client.health_check()
        assert health is not None
        assert 'database' in health
        assert 'supabase' in health
    
    def test_create_resource(self, client, sample_resource_data):
        """測試創建資源"""
        resource = client.create_resource(**sample_resource_data)
        
        assert resource is not None
        assert resource.uuid is not None
        assert resource.content_header == sample_resource_data['content_header']
        assert resource.src_category == sample_resource_data['src_category']
    
    def test_get_resource(self, client, sample_resource_data):
        """測試獲取資源"""
        # 創建測試資源
        created_resource = client.create_resource(**sample_resource_data)
        
        # 獲取資源
        retrieved_resource = client.get_resource(created_resource.uuid)
        
        assert retrieved_resource is not None
        assert retrieved_resource.uuid == created_resource.uuid
        assert retrieved_resource.content_header == sample_resource_data['content_header']
    
    def test_search_functionality(self, client):
        """測試搜索功能"""
        # 測試全文搜索
        text_results = client.search_chunks_by_text('test query', limit=5)
        assert isinstance(text_results, list)
        
        # 測試向量搜索
        dummy_embedding = [0.1] * 1536  # 1536 維向量
        vector_results = client.search_chunks_by_embedding(
            embedding=dummy_embedding,
            threshold=0.5,
            limit=5
        )
        assert isinstance(vector_results, list)
    
    def test_error_handling(self, client):
        """測試錯誤處理"""
        # 測試不存在的資源
        non_existent = client.get_resource('00000000-0000-0000-0000-000000000000')
        assert non_existent is None
        
        # 測試無效數據
        with pytest.raises(ValueError):
            client.create_resource(
                remote_src_url='invalid-url',
                content_header='',  # 空標題應該引發錯誤
            )

class TestDatabaseOperations:
    """資料庫操作測試"""
    
    def test_chunk_operations(self, client, sample_resource_data):
        """測試分塊操作"""
        # 創建資源
        resource = client.create_resource(**sample_resource_data)
        
        # 創建分塊
        chunk_data = {
            'resource_uuid': resource.uuid,
            'chunk_order': 1,
            'chunking_text': 'This is a test chunk content for testing purposes.',
            'description': 'Test chunk description',
            'token_size': 10
        }
        
        chunk = client.create_chunk(**chunk_data)
        
        assert chunk is not None
        assert chunk.resource_uuid == resource.uuid
        assert chunk.chunk_order == 1
        
        # 測試獲取資源的所有分塊
        resource_chunks = client.get_chunks_by_resource(resource.uuid)
        assert len(resource_chunks) >= 1
        assert any(c.uuid == chunk.uuid for c in resource_chunks)
```

### 整合測試

```python
"""
tests/test_integration.py - 整合測試
"""
import pytest
import time
from client import create_client

class TestIntegration:
    """整合測試套件"""
    
    def test_full_workflow(self, client):
        """測試完整工作流程"""
        # 1. 創建資源
        resource = client.create_resource(
            remote_src_url='https://integration-test.com/article',
            content_header='Integration Test Article',
            src_name='Integration Tests',
            src_category='test',
            file_type='html'
        )
        
        # 2. 添加圖片
        image = client.create_image(
            resource_uuid=resource.uuid,
            remote_image_url='https://integration-test.com/image.jpg',
            description='Test image'
        )
        
        # 3. 創建多個分塊
        chunks = []
        for i in range(3):
            chunk = client.create_chunk(
                resource_uuid=resource.uuid,
                chunk_order=i + 1,
                chunking_text=f'Chunk {i+1} content for testing integration workflow.',
                description=f'Chunk {i+1} description'
            )
            chunks.append(chunk)
        
        # 4. 測試搜索
        search_results = client.search_chunks_by_text('integration', limit=10)
        
        # 驗證結果
        assert len(chunks) == 3
        assert len(search_results) >= 1
        assert any('integration' in result['chunking_text'].lower() 
                  for result in search_results)
    
    def test_performance_benchmarks(self, client):
        """效能基準測試"""
        # 測試大量數據插入
        start_time = time.time()
        
        resources = []
        for i in range(100):
            resource = client.create_resource(
                remote_src_url=f'https://perf-test.com/article/{i}',
                content_header=f'Performance Test Article {i}',
                src_name='Performance Tests',
                src_category='benchmark'
            )
            resources.append(resource)
        
        insert_time = time.time() - start_time
        print(f"插入 100 個資源耗時: {insert_time:.2f} 秒")
        
        # 測試搜索效能
        start_time = time.time()
        results = client.search_chunks_by_text('Performance', limit=50)
        search_time = time.time() - start_time
        
        print(f"搜索耗時: {search_time:.3f} 秒")
        print(f"搜索結果數: {len(results)}")
        
        # 效能斷言
        assert insert_time < 30.0  # 插入應在 30 秒內完成
        assert search_time < 1.0   # 搜索應在 1 秒內完成
```

### 執行測試

```bash
# 設置測試環境
cp .env .env.test
# 編輯 .env.test，使用測試資料庫

# 執行所有測試
./supabase.sh test

# 執行特定測試檔案
uv run pytest tests/test_client.py -v

# 執行測試並生成覆蓋率報告
uv run pytest --cov=client --cov-report=html

# 效能測試
uv run pytest tests/test_integration.py::TestIntegration::test_performance_benchmarks -s
```

## 📈 版本更新與維護

### 版本管理

```bash
# 查看當前版本
./supabase.sh version

# 檢查更新
./supabase.sh check-updates

# 更新到最新版本 (自動備份)
./supabase.sh update

# 回滾到之前版本
./supabase.sh rollback --version 1.0.0
```

### 維護計劃

#### 每日維護任務

```bash
#!/bin/bash
# daily-maintenance.sh

# 健康檢查
./supabase.sh health

# 清理日誌 (保留 7 天)
find ./volumes/logs -name "*.log" -mtime +7 -delete

# 資料庫統計更新
./supabase.sh psql -c "ANALYZE;"

# 備份 (如果配置了自動備份)
./supabase.sh backup --quiet
```

#### 週間維護任務

```bash
#!/bin/bash
# weekly-maintenance.sh

# 檢查磁碟使用率
df -h ./volumes/

# 清理舊備份 (保留 4 週)
find ./backups -name "*.sql.gz" -mtime +28 -delete

# 重建向量索引 (如果需要)
./supabase.sh psql -c "REINDEX INDEX CONCURRENTLY idx_chunks_chunk_emb_ivf;"

# 更新依賴
uv sync --upgrade

# 執行完整測試套件
./supabase.sh test
```

## 🔗 相關資源與社群

### 官方文檔

- [Supabase 官方文檔](https://supabase.com/docs) - 完整的 Supabase 指南
- [pgvector GitHub](https://github.com/pgvector/pgvector) - PostgreSQL 向量擴展
- [PostgreSQL 官方文檔](https://www.postgresql.org/docs/) - PostgreSQL 數據庫文檔
- [UV 包管理器](https://github.com/astral-sh/uv) - 現代 Python 包管理

### 相關技術

- [LangChain](https://langchain.com/) - LLM 應用程式框架
- [Embeddings 模型比較](https://huggingface.co/spaces/mteb/leaderboard) - 向量嵌入模型性能比較
- [Docker Compose](https://docs.docker.com/compose/) - 容器編排文檔

### 社群與支援

- [StatementDog GitHub](https://github.com/your-org/statementdog) - 專案 GitHub 倉庫
- [Supabase Discord](https://discord.supabase.com/) - Supabase 官方社群
- [PostgreSQL 社群](https://www.postgresql.org/community/) - PostgreSQL 官方社群

## ❓ 常見問題 (FAQ)

### Q: 如何更換嵌入模型？

**A**: 修改 Python 代碼中的嵌入生成函數，並相應調整向量維度：

```python
# 範例：從 OpenAI 切換到 Sentence Transformers
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')  # 384 維
embedding = model.encode(text).tolist()

# 相應調整資料庫 schema
# ALTER TABLE chunks ALTER COLUMN chunk_embedding TYPE vector(384);
```

### Q: 如何處理大量數據導入？

**A**: 使用批量導入策略：

```python
def batch_import_resources(resources_data, batch_size=100):
    """批量導入資源"""
    for i in range(0, len(resources_data), batch_size):
        batch = resources_data[i:i+batch_size]
        
        # 使用事務處理
        with client.db.session.begin():
            for resource_data in batch:
                client.create_resource(**resource_data)
        
        print(f"已處理 {min(i+batch_size, len(resources_data))}/{len(resources_data)} 個資源")
```

### Q: 如何優化向量搜索性能？

**A**: 考慮以下優化策略：

1. **調整索引參數**：增加 `ivfflat.probes` 值提高精確度
2. **使用 HNSW 索引**：對於高維數據，HNSW 可能更快
3. **預計算常用查詢**：將熱門搜索結果緩存
4. **分層搜索**：先粗篩再精搜

### Q: 如何實現多租戶架構？

**A**: 使用 Row Level Security (RLS) 實現：

```sql
-- 添加租戶欄位
ALTER TABLE resources ADD COLUMN tenant_id uuid;

-- 創建租戶隔離政策
CREATE POLICY "tenant_isolation" ON resources
    FOR ALL USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

### Q: 如何監控系統性能？

**A**: 使用內建的監控工具：

```python
# 系統監控腳本
def monitor_system():
    client = create_client()
    
    # 檢查資料庫連接
    health = client.health_check()
    
    # 檢查搜索性能
    start = time.time()
    client.search_chunks_by_text("test", limit=1)
    search_time = time.time() - start
    
    # 檢查磁碟使用率
    disk_usage = shutil.disk_usage('./volumes/')
    
    return {
        'health': health,
        'search_time': search_time,
        'disk_free_gb': disk_usage.free / (1024**3)
    }
```

---

## 🚀 開始使用

準備好了嗎？讓我們開始：

```bash
# 1. 進入專案目錄
cd statementdog/supabase

# 2. 首次設置
./supabase.sh setup

# 3. 配置環境變數
nano .env  # 修改密碼和金鑰

# 4. 啟動服務
./supabase.sh start

# 5. 驗證部署
uv run python -c "from client import create_client; print('✅ 成功:', create_client().health_check())"

# 6. 開始開發！
uv run supabase/uv-example.py
```

🎉 **恭喜！您的 Supabase RAG 系統已就緒！**

訪問 [http://localhost:8000](http://localhost:8000) 開始使用 Supabase Studio 管理您的數據。

---

**需要協助？** 查看故障排除章節或提交 [GitHub Issue](https://github.com/your-org/statementdog/issues)。

**© 2024 StatementDog RAG System. All rights reserved.**