#!/bin/bash
# ============================================================================
# AI Brain Supabase - Docker 服務啟動腳本 (start-docker.sh)
# ============================================================================
# 
# 🎯 **腳本功能**：
#   啟動完整的 Supabase Docker 服務堆疊
#   
# 🔧 **主要操作**：
#   1. 環境檢查（Docker、配置文件）
#   2. 拉取最新 Docker 映像
#   3. 啟動所有 Supabase 服務
#   4. 等待服務健康檢查
#   5. 顯示服務狀態和連接信息
#   
# ✅ **智能特性**：
#   - 自動等待數據庫就緒
#   - 健康檢查和服務狀態監控
#   - 完整的連接信息顯示
#   - 錯誤處理和故障排除提示
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
    
    # 檢查 Docker
    if ! docker info &> /dev/null; then
        log_error "Docker 未運行或無權限訪問"
        exit 1
    fi
    
    # 檢查配置文件
    if [ ! -f ".env" ]; then
        log_error "環境配置文件 .env 不存在"
        log_info "請先執行 ./scripts/setup-docker.sh 進行初始化"
        exit 1
    fi
    
    if [ ! -f "docker-compose.yml" ]; then
        log_error "Docker Compose 配置文件不存在"
        exit 1
    fi
    
    # 檢查端口占用
    local ports=(3000 8000 8443 5432 6543)
    local occupied_ports=()
    
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            occupied_ports+=($port)
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        log_warning "以下端口被占用: ${occupied_ports[*]}"
        log_info "如果這些是舊的 Supabase 服務，請先執行 ./scripts/stop-docker.sh"
        read -p "是否繼續啟動？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "環境檢查通過"
}

# 拉取 Docker 映像
pull_images() {
    log_info "拉取最新 Docker 映像..."
    
    # 顯示進度
    docker-compose pull --parallel
    
    log_success "Docker 映像已更新"
}

# 啟動服務
start_services() {
    log_info "啟動 Supabase 服務..."
    
    # 啟動所有服務
    docker-compose up -d
    
    log_success "服務啟動指令已執行"
}

# 等待服務就緒
wait_for_services() {
    log_info "等待服務就緒..."
    
    local max_attempts=60
    local attempt=1
    
    # 等待數據庫
    log_info "等待 PostgreSQL 數據庫..."
    while ! docker-compose exec -T db pg_isready -U postgres &> /dev/null; do
        if [ $attempt -ge $max_attempts ]; then
            log_error "數據庫啟動超時（${max_attempts} 秒）"
            show_troubleshooting
            exit 1
        fi
        
        echo -n "."
        sleep 1
        ((attempt++))
    done
    echo ""
    log_success "PostgreSQL 數據庫已就緒"
    
    # 等待 API Gateway (Kong)
    log_info "等待 API Gateway..."
    attempt=1
    while ! curl -s http://localhost:8000/health &> /dev/null; do
        if [ $attempt -ge $max_attempts ]; then
            log_warning "API Gateway 可能尚未完全就緒，但繼續檢查其他服務"
            break
        fi
        
        echo -n "."
        sleep 1
        ((attempt++))
    done
    echo ""
    
    # 檢查 Studio
    log_info "檢查 Supabase Studio..."
    if curl -s http://localhost:3000 &> /dev/null; then
        log_success "Supabase Studio 已就緒"
    else
        log_warning "Studio 可能需要更多時間啟動"
    fi
    
    # 額外等待時間確保所有服務穩定
    log_info "等待服務穩定..."
    sleep 10
    
    log_success "服務等待完成"
}

# 檢查服務狀態
check_service_status() {
    log_info "檢查服務狀態..."
    
    echo ""
    echo -e "${GREEN}📊 Service Status:${NC}"
    docker-compose ps
    
    echo ""
    echo -e "${BLUE}🔍 Health Checks:${NC}"
    
    # 檢查數據庫
    if docker-compose exec -T db pg_isready -U postgres &> /dev/null; then
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
    log_success "🎉 Supabase 服務已啟動！"
    
    # 從 .env 文件讀取信息
    local dashboard_username=$(grep "DASHBOARD_USERNAME=" .env | cut -d'=' -f2)
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
    echo -e "${YELLOW}📋 API Keys (from .env):${NC}"
    echo "  ANON_KEY:           $(grep "ANON_KEY=" .env | cut -d'=' -f2 | head -c 50)..."
    echo "  SERVICE_ROLE_KEY:   $(grep "SERVICE_ROLE_KEY=" .env | cut -d'=' -f2 | head -c 50)..."
    
    echo ""
    echo -e "${GREEN}📝 Useful Commands:${NC}"
    echo "  查看日誌:            docker-compose logs -f"
    echo "  查看特定服務日誌:     docker-compose logs -f [service-name]"
    echo "  停止服務:            ./scripts/stop-docker.sh"
    echo "  重啟服務:            docker-compose restart"
    echo "  重置數據庫:          ./scripts/reset-db.sh"
    echo "  進入數據庫:          docker-compose exec db psql -U postgres"
    
    echo ""
    echo -e "${BLUE}🧪 Quick Tests:${NC}"
    echo "  測試 API:            curl http://localhost:8000/rest/v1/"
    echo "  測試數據庫連接:      docker-compose exec db psql -U postgres -c \"SELECT version();\""
}

# 故障排除信息
show_troubleshooting() {
    echo ""
    echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
    echo "  1. 檢查 Docker 狀態:  docker info"
    echo "  2. 檢查服務狀態:      docker-compose ps"
    echo "  3. 查看服務日誌:      docker-compose logs"
    echo "  4. 重啟 Docker:       sudo systemctl restart docker"
    echo "  5. 清理並重啟:        docker-compose down && ./scripts/start-docker.sh"
    
    echo ""
    echo -e "${RED}常見問題:${NC}"
    echo "  - 端口占用: 檢查 3000, 8000, 5432 端口"
    echo "  - 權限問題: 確保用戶在 docker 組中"
    echo "  - 磁盤空間: 確保有足夠的磁盤空間（>5GB）"
    echo "  - 記憶體不足: Docker 建議至少 4GB RAM"
}

# 主執行流程
main() {
    echo "🚀 啟動 AI Brain Supabase Docker 環境"
    echo ""
    
    check_environment
    pull_images
    start_services
    wait_for_services
    check_service_status
    show_connection_info
    
    echo ""
    log_success "🎯 啟動完成！請訪問 http://localhost:3000 開始使用 Supabase Studio"
}

# 錯誤處理
trap 'log_error "啟動過程中發生錯誤"; show_troubleshooting; exit 1' ERR

# 執行主函數
main "$@"