# AI Brain Supabase

一個基於 Supabase CLI 的自托管智能大腦平台，提供完整的 RAG 系統架構與簡化的管理工具。

![Supabase Version](https://img.shields.io/badge/Supabase-CLI%202.39.2-green)
![Docker](https://img.shields.io/badge/Docker-Required-blue)
![Python](https://img.shields.io/badge/Python-3.12+-yellow)
![pgvector](https://img.shields.io/badge/pgvector-Enabled-purple)

---

## 🚀 快速開始

### 📋 系統要求
- **Docker** 和 Docker Compose
- **Linux/macOS** (推薦 Ubuntu 20.04+)
- **8GB+ RAM** 和 **20GB+ 磁盤空間**
- **Python 3.12+** (可選，用於客戶端庫)

### ⚡ 一鍵安裝部署

```bash
# 1. 克隆倉庫
git clone <your-repository-url>
cd AI-Brain_Supabase

# 2. 一鍵初始化 (自動安裝 CLI、初始化項目、創建遷移)
./scripts/setup.sh

# 3. 啟動服務 (自動檢查並初始化數據庫)
./scripts/start.sh
```

**就這麼簡單！** 所有 RAG 系統表格會自動創建並初始化完成。

### 🔗 服務訪問地址
啟動完成後，您可以通過以下地址訪問服務：

| 服務 | 地址 | 說明 |
|------|------|------|
| **🎛 Studio 管理界面** | http://127.0.0.1:54323 | 數據庫管理、API 測試、數據瀏覽 |
| **🔌 REST API** | http://127.0.0.1:54321 | 主要 API 端點與 GraphQL |
| **🗄 PostgreSQL 數據庫** | postgresql://postgres:postgres@127.0.0.1:54322/postgres | 直接數據庫連接 |
| **📧 Email 測試工具** | http://127.0.0.1:54324 | 本地郵件測試 (Inbucket) |

---

## 📁 項目結構與程式功能

```
AI-Brain_Supabase/
├── 📜 README.md                    # 項目主文檔與完整使用指南
├── 📋 CHANGELOG.md                 # 版本變更日誌與功能更新記錄
├── 📄 LICENSE                      # MIT 開源許可證
├── ⚙️ pyproject.toml               # Python 項目配置 (uv 包管理)
├── 🔒 uv.lock                      # 依賴版本鎖定文件
├── 🔧 .env.example                 # 環境變量範例配置
│
├── 🛠 scripts/                     # 自動化管理腳本集
│   ├── setup.sh                   # 🏗️ 一鍵環境安裝與初始化腳本
│   ├── start.sh                   # ▶️ 啟動服務與自動數據庫檢查
│   ├── stop.sh                    # ⏹️ 安全停止所有 Supabase 服務
│   ├── reset.sh                   # 🔄 數據庫完整重置與遷移應用
│   └── backup.sh                  # 💾 數據與配置完整備份工具
│
├── ⚙️ supabase/                    # Supabase CLI 配置與遷移
│   ├── config.toml                # Supabase 服務主配置文件
│   └── migrations/                # 📊 數據庫結構遷移文件
│       └── *_rag_system_init.sql  # RAG 系統完整數據庫架構
│
├── 🐍 client/                      # Python 客戶端庫套件
│   ├── README.md                  # 客戶端詳細使用說明
│   ├── __init__.py                # Python 套件初始化文件
│   ├── client.py                  # 🔌 統一 Supabase 客戶端接口
│   ├── cli.py                     # 💻 命令行工具與 CLI 介面
│   ├── config.py                  # ⚙️ 配置管理與環境讀取工具
│   └── database.py                # 🗄️ 數據庫 ORM 與查詢工具
│
└── 📊 sql/                         # 自定義 SQL 腳本庫
    └── simplified_rag_schema.sql  # 🧠 RAG 系統優化數據庫架構
```

---

## 🔧 核心腳本功能詳解

### **`scripts/setup.sh` - 環境安裝腳本**
**完整的項目初始化解決方案**
- ✅ **系統檢測**：自動檢測 Linux/macOS 系統與架構
- ✅ **Docker 驗證**：確保 Docker 已安裝並正在運行  
- ✅ **CLI 安裝**：自動下載並安裝最新 Supabase CLI 到 `~/bin/`
- ✅ **項目初始化**：初始化 Supabase 項目配置
- ✅ **智能遷移**：優先使用簡化版 RAG schema 創建遷移文件
- ✅ **環境配置**：創建 .env.example 範例配置文件
- ✅ **PATH 設定**：自動添加 CLI 到系統 PATH

### **`scripts/start.sh` - 服務啟動腳本**
**智能啟動與數據庫自動初始化**
- ✅ **服務檢查**：驗證 CLI、項目配置、Docker 狀態
- ✅ **優雅啟動**：啟動所有 Supabase 服務容器
- ✅ **數據庫等待**：智能等待數據庫就緒 (最多 60 秒)
- ✅ **Schema 檢測**：自動檢查核心表格是否存在
- ✅ **自動遷移**：如需要會自動應用 SQL 遷移文件
- ✅ **狀態報告**：顯示完整連接信息與開發提示

### **`scripts/reset.sh` - 數據庫重置腳本**
**安全的數據庫完整重置工具**
- ✅ **安全確認**：防止意外數據丟失 (支援 `--force` 跳過)
- ✅ **標準重置**：使用 `supabase db reset` 重建數據庫
- ✅ **容錯處理**：如失敗會自動使用手動重置方式
- ✅ **完整重建**：清除所有數據、重建 schema、應用遷移
- ✅ **狀態檢查**：重置後自動顯示服務狀態

### **`scripts/stop.sh` - 服務停止腳本**  
**安全的服務關閉工具**
- ✅ **優雅關閉**：安全停止所有 Supabase 容器服務
- ✅ **狀態檢查**：驗證服務是否已完全停止
- ✅ **清理選項**：可選 `--cleanup` 清理 Docker 資源
- ✅ **錯誤處理**：處理服務未運行等異常狀況

### **`scripts/backup.sh` - 數據備份腳本**
**完整的項目備份解決方案**
- ✅ **數據庫備份**：使用 pg_dump 備份完整數據庫
- ✅ **配置備份**：備份所有 Supabase 配置文件
- ✅ **代碼備份**：包含客戶端代碼與腳本
- ✅ **時間戳命名**：自動生成 `supabase_backup_YYYYMMDD_HHMMSS.tar.gz`
- ✅ **壓縮存儲**：tar.gz 格式節省磁盤空間

---

## 🐍 Python 客戶端庫詳解

### **`client/client.py` - 主要客戶端接口**
**統一的 Supabase 操作高級 API**
- 🔌 **連接管理**：自動處理數據庫連接、認證與重連
- 🧠 **RAG 支持**：針對向量搜索與文檔管理的專用方法  
- 📊 **資源管理**：完整的 resources、chunks、embeddings CRUD
- 🔍 **智能搜索**：支援全文搜索、向量搜索、混合搜索
- ⚡ **批次操作**：高效的批量數據處理與更新
- 🛡️ **錯誤處理**：完善的異常處理與自動重試機制

### **`client/cli.py` - 命令行工具**
**強大的 CLI 操作介面**
- 💻 **命令行集成**：提供完整的 CLI 命令支持
- 📊 **數據導入導出**：批量處理文檔與向量數據  
- 🔧 **管理工具**：數據庫維護、統計查詢、健康檢查
- 🚀 **腳本友好**：可與 Shell 腳本無縫集成自動化
- 📝 **詳細日誌**：完整的操作日誌與進度顯示

### **`client/config.py` - 配置管理**
**智能的環境配置管理**
- 🔧 **環境讀取**：自動讀取 .env、環境變量、Supabase 狀態
- ✅ **配置驗證**：檢查必要配置項完整性與有效性
- 🔄 **動態更新**：支持運行時配置更新與重載
- 🛡️ **安全處理**：敏感信息安全存儲與訪問控制
- 📋 **預設管理**：智能預設值與配置繼承

### **`client/database.py` - 數據庫 ORM**
**RAG 系統專用數據庫抽象層**
- 🗄️ **模型定義**：完整的 RAG 系統數據模型 (Resources, Chunks, etc.)
- 🔍 **高級查詢**：複雜查詢、聚合、統計分析工具  
- 🧠 **向量操作**：pgvector 向量搜索與相似度計算包裝器
- ⚡ **性能優化**：查詢優化、索引管理、連接池
- 🔄 **遷移支持**：數據庫 schema 變更與版本管理

---

## 🗄 RAG 數據庫架構

本項目實現了完整的 RAG (Retrieval-Augmented Generation) 系統數據庫架構：

### 核心表格結構
- **`media_sources`** - 媒體來源管理 (Bloomberg, Reuters, etc.)
- **`resources`** - 文檔資源主檔 (文章、PDF、網頁等)  
- **`parsed_artifacts`** - 解析產物管理 (不同解析策略結果)
- **`chunks`** - 文字分塊存儲 (支援全文搜索 + pgvector 向量搜索)
- **`images`** - 圖片資源管理與元數據
- **`chunk_embeddings`** - 多模型向量存儲 (支援不同 embedding 模型)
- **`parse_settings`** - 解析策略配置管理
- **`chunk_settings`** - 分塊策略配置管理

### 搜索功能
- **🔤 全文搜索**：基於 PostgreSQL tsvector 的高效全文搜索
- **🧠 向量搜索**：pgvector 支援的語意相似度搜索  
- **🔀 混合搜索**：結合全文與向量搜索的智能排序
- **🎯 條件過濾**：支援來源、時間、分類等多維度過濾

### 🛡️ 安全特性 (2025-09-01 更新)
- **函數安全強化**：所有數據庫函數使用 `SET search_path = ''` 防止注入攻擊
- **資源指紋識別**：使用 SHA256 fingerprint 進行業務唯一性檢查
- **高效能 UUID**：採用 `gen_random_uuid()` 提升主鍵生成效能
- **immutable 保證**：Generated columns 使用 `EXTRACT()` 確保 PostgreSQL 相容性
- **RLS 安全策略**：完整的行級安全策略保護敏感資料

---

## 🛠 可用命令

### 基本操作
```bash
# 🚀 完整初始化 (首次使用)
./scripts/setup.sh

# ▶️ 啟動所有服務
./scripts/start.sh

# ⏹️ 停止所有服務  
./scripts/stop.sh

# 🔄 完整重置數據庫 (會清空所有數據!)
./scripts/reset.sh

# 💾 創建完整備份
./scripts/backup.sh
```

### 服務管理
```bash
# 📊 查看服務狀態
export PATH="$HOME/bin:$PATH"
supabase status

# 📜 查看實時日誌
supabase logs -f

# 🔍 查看特定服務日誌
supabase logs -f db          # 數據庫日誌
supabase logs -f api         # API 日誌  
supabase logs -f auth        # 認證服務日誌
```

### Python 客戶端使用
```bash
# 安裝依賴 (使用 uv)
uv sync

# 使用客戶端
python -c "from client.client import create_client; client = create_client(); print('客戶端就緒')"

# CLI 工具
uv run python -m client.cli --help
```

### 數據庫直接操作
```bash
# 直接連接數據庫
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres

# 檢查表格
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "\\dt"

# 測試搜索功能
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "SELECT * FROM search_chunks_by_text('test', NULL, 5);"
```

---

## 🔧 配置說明

### Supabase 主配置
配置文件：`supabase/config.toml`

```toml
# 項目標識符
project_id = "ai-brain-supabase"

# API 配置
[api]
port = 54331
schemas = ["public", "graphql_public"]

# 數據庫配置  
[db]
port = 54332
major_version = 17

# Studio 管理界面
[studio]
port = 54333

# 存儲配置
[storage]
file_size_limit = "100MiB"
```

### 環境變量
Supabase CLI 自動管理的環境變量：
```bash
SUPABASE_URL=http://127.0.0.1:54331
SUPABASE_ANON_KEY=<auto-generated>
SUPABASE_SERVICE_ROLE_KEY=<auto-generated>
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54332/postgres
```

---

## 🚨 故障排除

### 常見問題與解決方案

#### 🔴 端口被占用
```bash
# 檢查端口使用
lsof -i :54331-54334

# 強制停止服務
./scripts/stop.sh

# 如仍有問題，重啟 Docker
sudo systemctl restart docker
./scripts/start.sh
```

#### 🔴 數據庫連接失敗
```bash
# 檢查服務狀態
export PATH="$HOME/bin:$PATH"
supabase status

# 查看數據庫日誌
supabase logs db

# 重置數據庫
./scripts/reset.sh --force
```

#### 🔴 遷移失敗
```bash
# 查看遷移狀態
supabase migration list

# 手動重置
./scripts/stop.sh
./scripts/start.sh
```

#### 🔴 Python 客戶端問題
```bash
# 重新安裝依賴
uv sync --reinstall

# 檢查數據庫連接
python -c "import psycopg2; psycopg2.connect('postgresql://postgres:postgres@127.0.0.1:54322/postgres')"
```

---

## 💾 備份和恢復

### 自動備份
```bash
# 創建時間戳備份
./scripts/backup.sh

# 備份文件位置
ls -la backups/
# supabase_backup_20250831_213000.tar.gz
```

### 手動備份與恢復
```bash
# 僅備份數據庫
pg_dump postgresql://postgres:postgres@127.0.0.1:54322/postgres > backup.sql

# 從備份恢復
./scripts/stop.sh
./scripts/start.sh
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres < backup.sql
```

---

## 🤝 貢獻指南

### 開發環境設置
```bash
# 1. Fork 項目並克隆
git clone <your-fork-url>
cd AI-Brain_Supabase

# 2. 設置開發環境
./scripts/setup.sh

# 3. 安裝 Python 依賴
uv sync

# 4. 開始開發
./scripts/start.sh
```

### 代碼規範
- 🐍 **Python**：使用 `black` 格式化，`ruff` 檢查
- 🛠 **Bash**：遵循 ShellCheck 建議  
- 📊 **SQL**：使用 PostgreSQL 標準格式
- 📝 **文檔**：使用 Markdown，保持繁體中文

---

## 📄 許可證

本項目採用 [MIT 許可證](LICENSE)。

---

## 🙏 致謝

- [Supabase](https://supabase.com/) - 優秀的開源 Firebase 替代方案
- [PostgreSQL](https://postgresql.org/) - 強大的開源關係數據庫
- [pgvector](https://github.com/pgvector/pgvector) - PostgreSQL 向量擴展
- [Docker](https://docker.com/) - 容器化平台

---

## 📚 更多資源

- 📖 [Supabase 官方文檔](https://supabase.com/docs)
- 🎓 [Supabase 大學](https://supabase.com/docs/guides/getting-started)
- 🛠 [Supabase CLI 參考](https://supabase.com/docs/reference/cli)
- 🐍 [Python 客戶端文檔](https://supabase.com/docs/reference/python/introduction)
- 🧠 [pgvector 文檔](https://github.com/pgvector/pgvector#readme)

---

<div align="center">

**⭐ 如果這個項目對您有幫助，請給我們一個 Star！**

Made with ❤️ by AI Brain Team

</div>