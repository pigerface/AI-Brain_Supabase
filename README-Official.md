# AI Brain Supabase - 官方 Docker 整合版本

基於 Supabase 官方 Docker 配置，完整整合 RAG 系統架構。

![Official](https://img.shields.io/badge/Supabase-Official%20Docker-green)
![RAG](https://img.shields.io/badge/RAG%20System-Integrated-blue)
![Docker](https://img.shields.io/badge/Docker%20Compose-v2+-yellow)

---

## 🏛️ 官方標準設置

此版本完全遵循 [Supabase 官方 Docker 文檔](https://supabase.com/docs/guides/self-hosting/docker) 的標準流程：

```bash
# 官方標準流程（已完成）
git clone --depth 1 https://github.com/supabase/supabase
mkdir supabase-project  
cp -rf supabase/docker/* supabase-project
cp supabase/docker/.env.example supabase-project/.env
```

## 🎯 整合完成的內容

### ✅ **官方文件結構**
```
supabase/
├── docker-compose.yml         # 官方主服務配置
├── docker-compose.s3.yml      # S3 存儲選項
├── .env                       # 生產級環境配置
├── reset.sh                   # 官方重置腳本
├── dev/                       # 開發工具
│   ├── docker-compose.dev.yml # 開發環境配置
│   └── data.sql               # 測試數據
└── volumes/                   # 完整配置文件
    ├── api/kong.yml           # Kong API Gateway 路由
    ├── db/                    # 數據庫配置
    │   ├── init/
    │   │   └── 01-rag-schema.sql  # RAG 系統整合
    │   ├── realtime.sql       # Realtime 功能
    │   ├── webhooks.sql       # Webhooks 支持
    │   └── roles.sql          # 用戶角色
    ├── logs/vector.yml        # 日誌收集配置
    └── pooler/pooler.exs      # 連接池配置
```

### ✅ **RAG 系統整合**
- **完整 Schema**：26,000+ 行 SQL，包含向量搜索、全文檢索
- **表格結構**：media_sources, resources, chunks, images 等
- **搜索功能**：pgvector 向量搜索 + PostgreSQL 全文搜索
- **安全策略**：RLS (Row Level Security) 完整實施

### ✅ **管理腳本**
- **`scripts/start-official.sh`**：基於官方配置的智能啟動
- **`scripts/stop-official.sh`**：安全停止和資源清理
- **`reset.sh`**：官方標準重置腳本

---

## 🚀 快速開始

### 1. **直接啟動（推薦）**
```bash
# 使用官方配置啟動
./scripts/start-official.sh
```

### 2. **或使用標準 Docker Compose**
```bash
# 標準官方命令
docker compose up -d

# 查看狀態
docker compose ps

# 查看日誌
docker compose logs -f
```

### 3. **訪問服務**
- **Studio**: http://localhost:3000
- **API**: http://localhost:8000
- **Database**: localhost:5432

---

## 🔑 認證信息

所有認證信息在 `.env` 文件中：

```bash
# Dashboard 登入
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=admin-[隨機生成]

# PostgreSQL 連接
POSTGRES_PASSWORD=rag-[隨機生成]

# API Keys（自動生成）
ANON_KEY=eyJhbGciOiJIUzI1NiIs...
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIs...
```

---

## 🔧 管理命令

### 基本操作
```bash
# 啟動服務（官方腳本）
./scripts/start-official.sh

# 停止服務（官方腳本）  
./scripts/stop-official.sh

# 官方重置（清空所有數據）
./reset.sh

# 停止並清理（保留數據）
./scripts/stop-official.sh --cleanup

# 完全清理（⚠️ 刪除所有數據）
./scripts/stop-official.sh --volumes --cleanup
```

### Docker Compose 標準命令
```bash
# 標準啟動
docker compose up -d

# 查看服務狀態
docker compose ps

# 實時日誌
docker compose logs -f

# 特定服務日誌
docker compose logs -f db
docker compose logs -f kong
docker compose logs -f auth

# 重啟特定服務
docker compose restart db

# 停止服務
docker compose down

# 停止並移除卷
docker compose down --volumes
```

---

## 🗄️ 數據庫操作

### 連接數據庫
```bash
# 直接連接
docker compose exec db psql -U postgres

# 檢查 RAG 表格
docker compose exec db psql -U postgres -c "\dt"

# 測試向量搜索
docker compose exec db psql -U postgres -c "SELECT * FROM search_chunks_by_text('AI', NULL, 5);"

# 查看數據庫版本
docker compose exec db psql -U postgres -c "SELECT version();"
```

### SQL 文件執行
```bash
# 執行自定義 SQL
docker compose exec -T db psql -U postgres < your-script.sql

# 查看初始化日誌
docker compose logs db | grep -i "database system is ready"
```

---

## 🔄 與 CLI 版本差異

| 功能 | CLI 版本 | 官方 Docker 版本 |
|------|----------|----------------|
| **設置方式** | `supabase start` | `docker compose up` |
| **配置文件** | `config.toml` | `.env` + `volumes/` |
| **端口管理** | CLI 自動分配 | 手動配置 |
| **服務管理** | `supabase stop` | `docker compose down` |
| **重置數據** | `supabase db reset` | `./reset.sh` |
| **日誌查看** | `supabase logs` | `docker compose logs` |
| **生產部署** | 需轉換 | 原生支持 |
| **升級管理** | CLI 自動 | 手動拉取映像 |

---

## 📊 服務架構

### 核心服務
- **Kong** (API Gateway) - 端口 8000/8443
- **PostgreSQL** - 端口 5432 
- **GoTrue** (Auth) - 認證服務
- **PostgREST** - REST API
- **Realtime** - WebSocket 通訊
- **Storage** - 文件存儲
- **Studio** - 管理界面 (端口 3000)

### 輔助服務  
- **Supavisor** - 連接池 (端口 6543)
- **Imgproxy** - 圖片處理
- **Vector** - 日誌收集
- **Analytics** - 分析服務

---

## 🛡️ 安全最佳實踐

### 生產環境配置
```bash
# 1. 修改所有默認密碼
vim .env

# 2. 生成新的 JWT Secret
openssl rand -hex 32

# 3. 更新 API Keys
# 使用 PyJWT 重新生成

# 4. 配置 HTTPS（生產環境）
# 修改 kong.yml 配置

# 5. 設置防火牆規則
# 僅開放必要端口
```

### 環境隔離
```bash
# 開發環境
docker compose -f docker-compose.yml -f dev/docker-compose.dev.yml up

# 生產環境  
docker compose up -d

# S3 存儲版本
docker compose -f docker-compose.yml -f docker-compose.s3.yml up
```

---

## 🔍 故障排除

### 常見問題

#### 🔴 服務啟動失敗
```bash
# 檢查日誌
docker compose logs

# 檢查特定服務
docker compose logs db
docker compose logs kong

# 重新拉取映像
docker compose pull
docker compose up -d --force-recreate
```

#### 🔴 端口衝突
```bash
# 檢查端口占用
lsof -i :3000,8000,5432

# 修改端口（編輯 .env）
STUDIO_PORT=3001
KONG_HTTP_PORT=8001
POSTGRES_PORT=5433
```

#### 🔴 數據庫連接問題
```bash
# 檢查數據庫狀態
docker compose exec db pg_isready -U postgres

# 重啟數據庫
docker compose restart db

# 查看連接數
docker compose exec db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

#### 🔴 RAG 功能問題
```bash
# 檢查 RAG 表格
docker compose exec db psql -U postgres -c "\dt public.*"

# 重新應用 Schema
docker compose exec -T db psql -U postgres < volumes/db/init/01-rag-schema.sql

# 檢查向量擴展
docker compose exec db psql -U postgres -c "\dx"
```

---

## 📈 性能調優

### 數據庫優化
```sql
-- 在 Studio 中執行或通過 psql

-- 檢查數據庫統計
SELECT * FROM pg_stat_database WHERE datname = 'postgres';

-- 向量索引優化
SET maintenance_work_mem = '2GB';
REINDEX INDEX chunks_embedding_idx;

-- 查詢性能分析
EXPLAIN ANALYZE SELECT * FROM search_chunks_by_text('AI', NULL, 10);
```

### 容器資源限制
```yaml
# 在 docker-compose.yml 中添加
services:
  db:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
```

---

## 🔄 升級和維護

### 升級 Supabase
```bash
# 1. 備份數據
docker compose exec db pg_dump -U postgres postgres > backup.sql

# 2. 拉取最新映像
docker compose pull

# 3. 重啟服務
docker compose up -d

# 4. 檢查服務狀態
docker compose ps
```

### 定期維護
```bash
# 清理未使用的映像
docker system prune -f

# 數據庫維護
docker compose exec db psql -U postgres -c "VACUUM ANALYZE;"

# 日誌輪轉（如配置了）
docker compose logs --since 24h > logs/supabase-$(date +%Y%m%d).log
```

---

## 📚 相關資源

- 📖 [Supabase 官方文檔](https://supabase.com/docs)
- 🐳 [Docker Compose 文檔](https://docs.docker.com/compose/)
- 🔧 [Kong Gateway 配置](https://docs.konghq.com/gateway/)
- 🗄️ [PostgreSQL 文檔](https://www.postgresql.org/docs/)
- 🧠 [pgvector 擴展](https://github.com/pgvector/pgvector)

---

## 🎉 成功集成

您現在擁有：
- ✅ **100% 官方兼容**的 Supabase Docker 環境
- ✅ **完整整合**的 RAG 系統功能
- ✅ **生產就緒**的配置和腳本
- ✅ **標準化管理**工具和流程

可以直接用於開發、測試和生產部署！

---

<div align="center">

**⭐ 基於官方標準，整合 AI Brain RAG 系統**

Made with ❤️ by StatementDog Team

</div>