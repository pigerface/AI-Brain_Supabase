#!/bin/bash
# ============================================================================
# AI Brain Supabase - Official Docker Setup Launcher
# ============================================================================
# 
# 基於官方 Supabase Docker 配置的啟動腳本
# 使用標準 docker compose 命令，整合 RAG 系統
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

# 檢查環境
check_environment() {
    log_info "檢查環境配置..."
    
    # 檢查必要文件
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml 不存在"
        exit 1
    fi
    
    if [ ! -f ".env" ]; then
        log_error ".env 文件不存在"
        log_info "請先執行官方設置流程或運行 setup 腳本"
        exit 1
    fi
    
    # 檢查 Docker
    if ! docker info &> /dev/null; then
        log_error "Docker 未運行"
        exit 1
    fi
    
    # 檢查 Docker Compose
    if command -v docker-compose &> /dev/null; then
        export COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        export COMPOSE_CMD="docker compose"
    else
        log_error "Docker Compose 未安裝"
        exit 1
    fi
    
    log_success "環境檢查通過（使用 $COMPOSE_CMD）"
}

# 檢查端口
check_ports() {
    log_info "檢查端口占用..."
    
    local ports=(3000 8000 8443 5432 6543)
    local occupied_ports=()
    
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            occupied_ports+=($port)
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        log_warning "以下端口被占用: ${occupied_ports[*]}"
        read -p "是否繼續啟動？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 拉取映像
pull_images() {
    log_info "拉取 Docker 映像..."
    $COMPOSE_CMD pull
    log_success "映像拉取完成"
}

# 啟動服務
start_services() {
    log_info "啟動 Supabase 服務..."
    $COMPOSE_CMD up -d
    log_success "服務啟動命令已執行"
}

# 等待服務就緒
wait_for_services() {
    log_info "等待服務就緒..."
    
    local max_attempts=60
    local attempt=1
    
    # 等待數據庫
    log_info "等待 PostgreSQL..."
    while ! $COMPOSE_CMD exec -T db pg_isready -U postgres &> /dev/null; do
        if [ $attempt -ge $max_attempts ]; then
            log_error "數據庫啟動超時"
            return 1
        fi
        echo -n "."
        sleep 1
        ((attempt++))
    done
    echo ""
    log_success "PostgreSQL 已就緒"
    
    # 等待 API Gateway
    log_info "等待 API Gateway..."
    attempt=1
    while ! curl -s http://localhost:8000/health &> /dev/null; do
        if [ $attempt -ge $max_attempts ]; then
            log_warning "API Gateway 可能需要更多時間"
            break
        fi
        echo -n "."
        sleep 1
        ((attempt++))
    done
    echo ""
    
    # 等待 Studio
    log_info "等待 Studio..."
    sleep 10  # Studio 通常需要更多時間
    
    log_success "服務等待完成"
}

# 檢查服務狀態
check_service_status() {
    log_info "檢查服務狀態..."
    
    echo ""
    echo -e "${GREEN}📊 Service Status:${NC}"
    $COMPOSE_CMD ps
    
    echo ""
    echo -e "${BLUE}🔍 Health Checks:${NC}"
    
    # 檢查數據庫
    if $COMPOSE_CMD exec -T db pg_isready -U postgres &> /dev/null; then
        echo "  ✅ PostgreSQL: Healthy"
    else
        echo "  ❌ PostgreSQL: Not Ready"
    fi
    
    # 檢查 API
    if curl -s http://localhost:8000/health &> /dev/null; then
        echo "  ✅ API Gateway: Healthy"
    else
        echo "  ❌ API Gateway: Not Ready"
    fi
    
    # 檢查 Studio
    if curl -s http://localhost:3000 &> /dev/null; then
        echo "  ✅ Studio: Healthy"
    else
        echo "  ❌ Studio: Not Ready"
    fi
}

# 顯示連接信息
show_connection_info() {
    echo ""
    log_success "🎉 Supabase 官方 Docker 環境已啟動！"
    
    local dashboard_username=$(grep "DASHBOARD_USERNAME=" .env | cut -d'=' -f2 || echo "supabase")
    local dashboard_password=$(grep "DASHBOARD_PASSWORD=" .env | cut -d'=' -f2)
    local postgres_password=$(grep "POSTGRES_PASSWORD=" .env | cut -d'=' -f2)
    
    echo ""
    echo -e "${GREEN}🌐 Access Points:${NC}"
    echo "  📊 Supabase Studio: http://localhost:3000"
    echo "  🔌 API Gateway:     http://localhost:8000"
    echo "  📡 REST API:        http://localhost:8000/rest/v1/"
    echo "  🔐 Auth API:        http://localhost:8000/auth/v1/"
    echo "  💾 Storage API:     http://localhost:8000/storage/v1/"
    echo "  ⚡ Realtime API:    http://localhost:8000/realtime/v1/"
    
    echo ""
    echo -e "${BLUE}🔑 Credentials:${NC}"
    echo "  Dashboard Username: ${dashboard_username}"
    echo "  Dashboard Password: ${dashboard_password}"
    echo "  PostgreSQL URL:     postgresql://postgres:${postgres_password}@localhost:5432/postgres"
    
    echo ""
    echo -e "${YELLOW}📋 API Keys (first 50 chars):${NC}"
    echo "  ANON_KEY:           $(grep "ANON_KEY=" .env | cut -d'=' -f2 | head -c 50)..."
    echo "  SERVICE_ROLE_KEY:   $(grep "SERVICE_ROLE_KEY=" .env | cut -d'=' -f2 | head -c 50)..."
    
    echo ""
    echo -e "${GREEN}📝 Management Commands:${NC}"
    echo "  查看日誌:            $COMPOSE_CMD logs -f"
    echo "  停止服務:            $COMPOSE_CMD down"
    echo "  重啟服務:            $COMPOSE_CMD restart"
    echo "  官方重置:            ./reset.sh"
    echo "  進入數據庫:          $COMPOSE_CMD exec db psql -U postgres"
    
    echo ""
    echo -e "${BLUE}🧠 RAG System:${NC}"
    echo "  RAG Schema:         已整合到 volumes/db/init/01-rag-schema.sql"
    echo "  檢查 RAG 表格:      $COMPOSE_CMD exec db psql -U postgres -c \"\\dt\""
    echo "  測試向量搜索:       在 Studio 中執行 SQL 查詢"
}

# 主執行流程
main() {
    echo "🚀 啟動 AI Brain Supabase (官方 Docker 配置)"
    echo ""
    
    check_environment
    check_ports
    pull_images
    start_services
    wait_for_services
    check_service_status
    show_connection_info
    
    echo ""
    log_success "🎯 啟動完成！請訪問 http://localhost:3000 開始使用"
}

# 錯誤處理
trap 'log_error "啟動過程中發生錯誤"; exit 1' ERR

# 執行主函數
main "$@"