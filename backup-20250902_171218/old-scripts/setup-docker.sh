#!/bin/bash
# ============================================================================
# AI Brain Supabase - Docker 環境設置腳本 (setup-docker.sh)
# ============================================================================
# 
# 🎯 **腳本功能**：
#   完全基於 Docker Compose 的 Supabase 環境初始化（不依賴 CLI）
#   
# 🔧 **主要操作**：
#   1. 檢查 Docker 環境
#   2. 生成安全的 JWT 密鑰和 API Keys
#   3. 創建必要的目錄結構
#   4. 準備數據庫初始化腳本
#   5. 驗證配置完整性
#   
# ✅ **特性**：
#   - 不依賴 Supabase CLI
#   - 使用 Python 生成 JWT（避免 Node.js 依賴）
#   - 自動創建所需的 Docker 卷目錄
#   - 完整的錯誤檢查和日誌輸出
#   
# ============================================================================

set -euo pipefail

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日誌函數
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 檢查 Docker 環境
check_docker() {
    log_info "檢查 Docker 環境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安裝。請先安裝 Docker Desktop 或 Docker Engine。"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker 未運行或無權限訪問。"
        log_info "請嘗試："
        log_info "  1. 啟動 Docker Desktop"
        log_info "  2. 或執行: sudo systemctl start docker"
        log_info "  3. 或添加用戶到 docker 組: sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose 未安裝。"
        log_info "請安裝 Docker Compose 或使用 Docker Desktop。"
        exit 1
    fi
    
    log_success "Docker 環境檢查通過"
}

# 檢查 Python 環境
check_python() {
    log_info "檢查 Python 環境..."
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 未安裝。請安裝 Python 3.7+ 版本。"
        exit 1
    fi
    
    # 檢查 PyJWT 模組
    if ! python3 -c "import jwt" &> /dev/null; then
        log_info "安裝 PyJWT 模組..."
        pip3 install PyJWT || {
            log_error "無法安裝 PyJWT。請手動安裝: pip3 install PyJWT"
            exit 1
        }
    fi
    
    log_success "Python 環境檢查通過"
}

# 生成安全密鑰
generate_keys() {
    log_info "生成安全密鑰..."
    
    # 生成 JWT Secret
    JWT_SECRET=$(openssl rand -hex 32)
    
    # 生成 Postgres 密碼
    POSTGRES_PASSWORD="ai-brain-$(openssl rand -hex 16)"
    
    # 生成其他密鑰
    DASHBOARD_PASSWORD="admin-$(openssl rand -hex 8)"
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    VAULT_ENC_KEY=$(openssl rand -hex 32)
    
    # 使用 Python 生成 JWT tokens
    ANON_KEY=$(python3 -c "
import jwt
import json
secret = '$JWT_SECRET'
payload = {'role': 'anon', 'iss': 'supabase'}
token = jwt.encode(payload, secret, algorithm='HS256')
print(token if isinstance(token, str) else token.decode())
")
    
    SERVICE_ROLE_KEY=$(python3 -c "
import jwt
import json
secret = '$JWT_SECRET'
payload = {'role': 'service_role', 'iss': 'supabase'}
token = jwt.encode(payload, secret, algorithm='HS256')
print(token if isinstance(token, str) else token.decode())
")
    
    log_success "安全密鑰已生成"
}

# 更新環境文件
update_env_file() {
    log_info "更新環境配置文件..."
    
    # 創建臨時環境文件
    cp .env.example .env.tmp
    
    # 更新密鑰
    sed -i.bak "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" .env.tmp
    sed -i.bak "s|JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env.tmp
    sed -i.bak "s|ANON_KEY=.*|ANON_KEY=${ANON_KEY}|" .env.tmp
    sed -i.bak "s|SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}|" .env.tmp
    sed -i.bak "s|DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}|" .env.tmp
    sed -i.bak "s|SECRET_KEY_BASE=.*|SECRET_KEY_BASE=${SECRET_KEY_BASE}|" .env.tmp
    sed -i.bak "s|VAULT_ENC_KEY=.*|VAULT_ENC_KEY=${VAULT_ENC_KEY}|" .env.tmp
    
    # 更新應用特定配置
    sed -i.bak "s|STUDIO_DEFAULT_ORGANIZATION=.*|STUDIO_DEFAULT_ORGANIZATION=AI Brain Organization|" .env.tmp
    sed -i.bak "s|STUDIO_DEFAULT_PROJECT=.*|STUDIO_DEFAULT_PROJECT=AI Brain RAG System|" .env.tmp
    sed -i.bak "s|ENABLE_EMAIL_AUTOCONFIRM=.*|ENABLE_EMAIL_AUTOCONFIRM=true|" .env.tmp
    sed -i.bak "s|SMTP_SENDER_NAME=.*|SMTP_SENDER_NAME=AI Brain Supabase|" .env.tmp
    sed -i.bak "s|ENABLE_PHONE_SIGNUP=.*|ENABLE_PHONE_SIGNUP=false|" .env.tmp
    sed -i.bak "s|ENABLE_PHONE_AUTOCONFIRM=.*|ENABLE_PHONE_AUTOCONFIRM=false|" .env.tmp
    
    # 移動到最終位置
    mv .env.tmp .env
    rm -f .env.tmp.bak
    
    log_success "環境配置文件已更新"
}

# 創建目錄結構
create_directories() {
    log_info "創建必要的目錄結構..."
    
    # 創建 Docker 卷目錄
    mkdir -p volumes/{db/{init,data},storage,functions,logs}
    
    # 設置權限
    chmod -R 755 volumes/
    
    log_success "目錄結構已創建"
}

# 準備數據庫初始化
setup_database_init() {
    log_info "準備數據庫初始化腳本..."
    
    # 檢查是否存在 RAG schema
    if [ -f "sql/init_schema.sql" ]; then
        cp sql/init_schema.sql volumes/db/init/01-rag-schema.sql
        log_success "RAG schema 已準備完成"
    else
        log_warning "找不到 sql/init_schema.sql，將創建基本初始化腳本"
        
        cat > volumes/db/init/01-basic-init.sql << EOF
-- Basic initialization for AI Brain Supabase
-- This file will be executed when the database starts for the first time

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create a test table to verify initialization
CREATE TABLE IF NOT EXISTS system_status (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    status TEXT NOT NULL DEFAULT 'initialized',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO system_status (status) VALUES ('Docker initialization complete');
EOF
        log_success "基本初始化腳本已創建"
    fi
}

# 驗證配置
verify_setup() {
    log_info "驗證環境配置..."
    
    # 檢查必要文件
    local required_files=(".env" "docker-compose.yml" "volumes/db/init")
    for file in "${required_files[@]}"; do
        if [ ! -e "$file" ]; then
            log_error "缺少必要文件或目錄: $file"
            exit 1
        fi
    done
    
    # 檢查環境變數
    if ! grep -q "POSTGRES_PASSWORD=" .env; then
        log_error ".env 文件配置不完整"
        exit 1
    fi
    
    log_success "環境配置驗證通過"
}

# 顯示設置摘要
show_summary() {
    log_success "🎉 Docker 環境設置完成！"
    
    echo ""
    echo -e "${GREEN}📋 設置摘要：${NC}"
    echo "  ✅ Docker 環境已驗證"
    echo "  ✅ 安全密鑰已生成"
    echo "  ✅ 環境配置已更新"
    echo "  ✅ 目錄結構已創建"
    echo "  ✅ 數據庫初始化已準備"
    
    echo ""
    echo -e "${BLUE}🔑 重要信息：${NC}"
    echo "  - Dashboard 用戶名: admin"
    echo "  - Dashboard 密碼: 請查看 .env 文件中的 DASHBOARD_PASSWORD"
    echo "  - API Keys 已自動生成並配置"
    
    echo ""
    echo -e "${YELLOW}🚀 下一步：${NC}"
    echo "  1. 檢查並修改 .env 文件中的配置（如需要）"
    echo "  2. 執行 ./scripts/start-docker.sh 啟動服務"
    echo "  3. 訪問 http://localhost:3000 打開 Supabase Studio"
    
    echo ""
    echo -e "${GREEN}📚 常用命令：${NC}"
    echo "  - 啟動: ./scripts/start-docker.sh"
    echo "  - 停止: ./scripts/stop-docker.sh"
    echo "  - 查看日誌: docker-compose logs -f"
    echo "  - 重置: ./scripts/reset-db.sh"
}

# 主執行流程
main() {
    echo "🚀 開始設置 AI Brain Supabase Docker 環境"
    echo ""
    
    check_docker
    check_python
    generate_keys
    update_env_file
    create_directories
    setup_database_init
    verify_setup
    show_summary
}

# 執行主函數
main "$@"