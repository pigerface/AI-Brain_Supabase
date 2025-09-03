#!/bin/bash
# ============================================================================
# AI Brain Supabase - Docker 服務停止腳本 (stop-docker.sh)
# ============================================================================
# 
# 🎯 **腳本功能**：
#   安全停止所有 Supabase Docker 服務
#   
# 🔧 **主要操作**：
#   1. 停止所有運行中的服務容器
#   2. 清理未使用的網路和卷（可選）
#   3. 顯示停止狀態確認
#   
# ✅ **選項**：
#   --cleanup : 同時清理 Docker 資源（網路、未使用的卷等）
#   --volumes : 同時移除數據卷（⚠️ 會刪除所有資料！）
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

# 解析參數
CLEANUP=false
REMOVE_VOLUMES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知參數: $1"
            show_help
            exit 1
            ;;
    esac
done

# 顯示幫助信息
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "停止 Supabase Docker 服務"
    echo ""
    echo "Options:"
    echo "  --cleanup    清理未使用的 Docker 資源"
    echo "  --volumes    同時移除數據卷（⚠️  會刪除所有資料！）"
    echo "  -h, --help   顯示此幫助信息"
    echo ""
    echo "Examples:"
    echo "  $0              # 僅停止服務"
    echo "  $0 --cleanup    # 停止服務並清理資源"
    echo "  $0 --volumes    # 停止服務並移除所有資料（危險！）"
}

# 檢查環境
check_environment() {
    if ! docker info &> /dev/null; then
        log_error "Docker 未運行或無權限訪問"
        exit 1
    fi
    
    if [ ! -f "docker-compose.yml" ]; then
        log_error "Docker Compose 配置文件不存在"
        log_info "請確保在正確的目錄中運行此腳本"
        exit 1
    fi
}

# 確認危險操作
confirm_dangerous_operation() {
    if [ "$REMOVE_VOLUMES" = true ]; then
        log_warning "⚠️  警告：--volumes 選項將會刪除所有資料！"
        log_warning "這包括數據庫資料、上傳的文件等所有持久化資料。"
        echo ""
        read -p "確定要繼續嗎？請輸入 'yes' 確認: " -r
        if [ "$REPLY" != "yes" ]; then
            log_info "操作已取消"
            exit 0
        fi
    fi
}

# 顯示當前狀態
show_current_status() {
    log_info "檢查當前服務狀態..."
    
    local running_containers=$(docker-compose ps -q)
    if [ -z "$running_containers" ]; then
        log_info "沒有運行中的 Supabase 服務"
        return 0
    fi
    
    echo ""
    echo -e "${BLUE}當前運行的服務：${NC}"
    docker-compose ps
    echo ""
}

# 停止服務
stop_services() {
    log_info "正在停止 Supabase 服務..."
    
    # 使用 docker-compose down 停止並移除容器
    local down_options=""
    
    if [ "$REMOVE_VOLUMES" = true ]; then
        down_options="--volumes"
        log_warning "同時移除數據卷..."
    fi
    
    docker-compose down $down_options
    
    log_success "服務已停止並清理"
}

# 清理 Docker 資源
cleanup_docker_resources() {
    if [ "$CLEANUP" = true ]; then
        log_info "清理未使用的 Docker 資源..."
        
        # 清理未使用的網路
        log_info "清理未使用的網路..."
        docker network prune -f
        
        # 清理未使用的卷（如果沒有使用 --volumes）
        if [ "$REMOVE_VOLUMES" = false ]; then
            log_info "清理未使用的匿名卷..."
            docker volume prune -f
        fi
        
        # 清理未使用的映像
        log_info "清理未使用的 Docker 映像..."
        docker image prune -f
        
        log_success "Docker 資源清理完成"
    fi
}

# 驗證停止狀態
verify_stopped() {
    log_info "驗證服務停止狀態..."
    
    local running_containers=$(docker-compose ps -q --filter "status=running")
    if [ -n "$running_containers" ]; then
        log_warning "仍有服務在運行："
        docker-compose ps --filter "status=running"
        return 1
    fi
    
    # 檢查端口是否已釋放
    local ports=(3000 8000 8443 5432 6543)
    local still_occupied=()
    
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            still_occupied+=($port)
        fi
    done
    
    if [ ${#still_occupied[@]} -gt 0 ]; then
        log_warning "以下端口仍被占用: ${still_occupied[*]}"
        log_info "這可能是其他應用程序在使用這些端口"
    fi
    
    log_success "服務停止驗證完成"
}

# 顯示停止摘要
show_stop_summary() {
    echo ""
    log_success "🛑 Supabase 服務已停止"
    
    echo ""
    echo -e "${GREEN}📋 停止摘要：${NC}"
    echo "  ✅ 所有服務容器已停止並移除"
    echo "  ✅ 網路已清理"
    
    if [ "$REMOVE_VOLUMES" = true ]; then
        echo "  ✅ 所有數據卷已移除（資料已刪除）"
    else
        echo "  ✅ 數據卷已保留（資料安全）"
    fi
    
    if [ "$CLEANUP" = true ]; then
        echo "  ✅ 未使用的 Docker 資源已清理"
    fi
    
    echo ""
    echo -e "${BLUE}💡 提示：${NC}"
    echo "  - 重新啟動: ./scripts/start-docker.sh"
    echo "  - 檢查狀態: docker-compose ps"
    
    if [ "$REMOVE_VOLUMES" = false ]; then
        echo "  - 如需刪除所有資料: $0 --volumes"
    fi
    
    echo ""
    echo -e "${YELLOW}🔧 如需完整清理：${NC}"
    echo "  docker system prune -a --volumes  # ⚠️  會刪除所有未使用的 Docker 資源"
}

# 主執行流程
main() {
    echo "🛑 停止 AI Brain Supabase Docker 環境"
    echo ""
    
    check_environment
    confirm_dangerous_operation
    show_current_status
    stop_services
    cleanup_docker_resources
    verify_stopped
    show_stop_summary
}

# 錯誤處理
trap 'log_error "停止過程中發生錯誤"; exit 1' ERR

# 執行主函數
main "$@"