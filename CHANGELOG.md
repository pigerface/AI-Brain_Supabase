# 變更日誌 (CHANGELOG)

本文件記錄 AI Brain Supabase 項目的所有重要變更。

格式基於 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.0.0/)，
版本號遵循 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

---

## [2.1.0] - 2025-08-31

### 🧹 系統清理與優化 (Cleanup & Optimization)
- **文件清理**: 移除不再需要的程式和文件
  - 刪除 `uv-example.py` - 不再需要的示例腳本
  - 清理 `client/__pycache__/` - Python 快取目錄
  - 移除 `sql/init_schema.sql` - 有語法問題的原始 schema
  - 刪除 `QUICKSTART.md` - 與 README.md 重複的文檔
  - 移除 `supabase/seed.sql` - 不必要的種子檔案

### 📚 文檔全面更新 (Documentation Overhaul)
- **README.md 完全重寫**:
  - 添加專案概述與核心功能說明
  - 詳細的快速開始指南
  - 完整的腳本功能說明
  - RAG 系統資料庫架構文檔
  - 全面的故障排除指南

- **client/README.md 全新創建**:
  - Python 客戶端庫完整文檔
  - 各模組詳細功能說明
  - API 方法與使用範例
  - 完整的使用指南

- **腳本註解增強**:
  - 為每個 shell 腳本添加詳細標頭註解
  - 包含功能說明、操作步驟、安全特性
  - 添加使用範例和相關腳本參考

### 🔧 自動化改進 (Automation Improvements)
- **SQL 初始化集成**:
  - 修改 `scripts/setup.sh` 自動整合 RAG schema
  - 更新 `scripts/start.sh` 添加資料庫檢查功能
  - 改進 `scripts/reset.sh` 容錯處理機制

- **pgvector 相容性修復**:
  - 建立 `sql/simplified_rag_schema.sql` 替代有問題的原始 schema
  - 修復擴展命名問題 (`pgvector` → `vector`)
  - 改善與 Supabase CLI 的相容性

### 📋 開發體驗優化 (Developer Experience)
- **完全腳本化操作**: 所有操作現在都可以透過腳本完成
- **智能錯誤處理**: 改善所有腳本的錯誤處理和狀態檢查
- **自動資料庫初始化**: 服務啟動時自動檢查和初始化資料表
- **容錯機制**: 多種備援方案確保系統穩定運行

### 🐛 問題修復 (Bug Fixes)
- 修復資料表無法自動建立的問題
- 解決 pgvector 擴展安裝問題
- 修正 SQL 語法錯誤導致的遷移失敗
- 改善腳本間的相依性處理

---

## [2.0.0] - 2025-08-31

### 🚀 重大變更 (BREAKING CHANGES)
- **完全重構**: 從手動 Docker Compose 遷移到 Supabase CLI 自動化部署
- **端口變更**: 
  - API: 8000 → 54331
  - 數據庫: 5435 → 54332  
  - Studio: 8000 → 54333
  - Email 測試: 新增 → 54334

### ✨ 新增功能 (Added)
- **自動化腳本套件**:
  - `scripts/setup.sh` - 環境自動安裝
  - `scripts/start.sh` - 服務啟動腳本
  - `scripts/stop.sh` - 服務停止腳本
  - `scripts/reset.sh` - 數據庫重置腳本
  - `scripts/backup.sh` - 完整備份腳本

- **Supabase CLI 集成**:
  - 官方 CLI 工具自動管理
  - 自動生成 JWT 密鑰和 API 密鑰
  - 內建健康檢查和服務依賴管理
  - 標準化的數據庫遷移系統

- **開發工具**:
  - Studio 管理界面 (http://localhost:54333)
  - Email 測試工具 (Mailpit)
  - 實時日誌監控
  - 自動化備份系統

- **文檔系統**:
  - 全新 README.md (中文版，詳細指南)
  - QUICKSTART.md (快速開始指南)
  - CHANGELOG.md (變更日誌)
  - 內嵌使用示例和故障排除指南

### 🔧 改進 (Changed)
- **配置管理**: 從手動 .env 文件改為 `supabase/config.toml`
- **數據庫管理**: 使用版本化遷移替代手動 SQL 腳本
- **安全性**: 自動生成強密鑰，不再使用 demo 密鑰
- **可維護性**: 標準化工具鏈，遵循官方最佳實踐

### 🗑 移除 (Removed)
- **舊配置系統**:
  - `docker-compose.yml` → 備份為 `docker-compose.yml.backup`
  - `.env` → 備份為 `.env.backup`
  - `volumes/` → 備份為 `volumes.backup/`

### 🔒 安全改進 (Security)
- 移除硬編碼的 demo API 密鑰
- 實施自動密鑰輪換機制
- 加強數據庫用戶權限管理
- JWT 密鑰自動生成和管理

### 🐛 修復 (Fixed)
- 解決數據庫用戶密碼缺失問題
- 修復服務依賴啟動順序問題
- 解決端口衝突問題
- 修復 Kong API 網關配置問題

### 📊 技術債務 (Technical Debt)
- 重構複雜的手動配置為自動化管理
- 簡化部署流程從多步驟到一鍵部署
- 統一日誌和監控系統
- 標準化錯誤處理和恢復機制

---

## [1.0.0] - 2025-08-23

### ✨ 初始版本 (Initial Release)
- **基礎功能**:
  - Docker Compose 手動部署
  - PostgreSQL 數據庫與 pgvector 擴展
  - Python 客戶端庫 (uv 環境)
  - RAG 系統數據庫架構
  
- **核心組件**:
  - Supabase Studio 管理界面
  - GoTrue 認證服務
  - PostgREST API 自動生成
  - Realtime 訂閱功能
  - Storage 文件存儲服務

- **開發工具**:
  - Python 客戶端 SDK
  - SQLAlchemy ORM 集成
  - 基礎 CLI 工具

---

## 升級指南

### 從 1.0.0 升級到 2.0.0

1. **備份現有數據**:
   ```bash
   # 舊版本數據已自動備份到 volumes.backup/
   # 如需手動備份:
   pg_dump postgresql://postgres:hungtse2025@localhost:5435/postgres > backup_v1.sql
   ```

2. **停止舊服務**:
   ```bash
   docker compose -f docker-compose.yml.backup down
   ```

3. **遷移到新版本**:
   ```bash
   ./scripts/setup.sh
   ./scripts/start.sh
   ```

4. **恢復數據** (如需要):
   ```bash
   # 將舊數據導入新系統
   psql postgresql://postgres:postgres@localhost:54332/postgres < backup_v1.sql
   ```

### 配置遷移

| 舊配置 (v1.0.0) | 新配置 (v2.0.0) | 說明 |
|-----------------|-----------------|------|
| `.env` | `supabase/config.toml` | 配置格式變更 |
| `docker-compose.yml` | CLI 自動管理 | 不再需要手動配置 |
| `volumes/` | 容器內自動管理 | 數據持久化自動處理 |

### API 端點變更

| 服務 | v1.0.0 端點 | v2.0.0 端點 |
|------|-------------|-------------|
| API | :8000 | :54331 |
| Studio | :8000 | :54333 |
| 數據庫 | :5435 | :54332 |

---

## 貢獻指南

### 如何添加變更日誌條目

1. **確定變更類型**:
   - `Added` - 新功能
   - `Changed` - 現有功能變更
   - `Deprecated` - 即將移除的功能
   - `Removed` - 已移除的功能
   - `Fixed` - 問題修復
   - `Security` - 安全相關變更

2. **編寫清晰的描述**:
   - 使用主動語態
   - 包含足夠的上下文
   - 添加相關的代碼示例或命令

3. **標記破壞性變更**:
   - 在版本號前添加 `BREAKING CHANGES` 標記
   - 提供升級指南

---

## 版本說明

- **主版本** (X.0.0): 包含破壞性變更
- **次版本** (0.X.0): 新功能，向後兼容  
- **修訂版本** (0.0.X): 問題修復，向後兼容

---

*更多信息請參考 [README.md](README.md)*