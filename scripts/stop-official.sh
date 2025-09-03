#!/bin/bash
# ============================================================================
# AI Brain Supabase - Official Docker Stop Script
# ============================================================================
# 
# 基於官方配置的服務停止腳本
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
REMOVE_VOLUMES=false
CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --volumes    同時移除數據卷（⚠️ 會刪除所有資料！）"
            echo "  --cleanup    清理未使用的 Docker 資源"
            echo "  -h, --help   顯示此幫助"
            exit 0
            ;;
        *)
            log_error "未知參數: $1"
            exit 1
            ;;
    esac
done

# 檢查環境
check_environment() {
    if ! docker info &> /dev/null; then
        log_error "Docker 未運行"
        exit 1
    fi
    
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml 不存在"
        exit 1
    fi
    
    # 確定 Docker Compose 命令
    if command -v docker-compose &> /dev/null; then
        export COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        export COMPOSE_CMD="docker compose"
    else
        log_error "Docker Compose 未安裝"
        exit 1
    fi
}

# 確認危險操作
confirm_dangerous_operation() {
    if [ "$REMOVE_VOLUMES" = true ]; then
        log_warning "⚠️ 警告：--volumes 選項將會刪除所有資料！"
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
    
    if $COMPOSE_CMD ps -q | grep -q .; then
        echo ""
        echo -e "${BLUE}當前運行的服務：${NC}"
        $COMPOSE_CMD ps
        echo ""
    else
        log_info "沒有運行中的服務"
    fi
}

# 停止服務
stop_services() {
    log_info "正在停止 Supabase 服務..."
    
    local down_options=""
    if [ "$REMOVE_VOLUMES" = true ]; then
        down_options="--volumes"
        log_warning "同時移除數據卷..."
    fi
    
    $COMPOSE_CMD down $down_options
    log_success "服務已停止"
}

# 清理資源
cleanup_resources() {
    if [ "$CLEANUP" = true ]; then
        log_info "清理未使用的 Docker 資源..."
        
        # 清理未使用的網路
        docker network prune -f
        
        # 清理未使用的卷（如果沒有使用 --volumes）
        if [ "$REMOVE_VOLUMES" = false ]; then
            docker volume prune -f
        fi
        
        # 清理未使用的映像
        docker image prune -f
        
        log_success "資源清理完成"
    fi
}

# 驗證停止狀態
verify_stopped() {
    log_info "驗證停止狀態..."
    
    if $COMPOSE_CMD ps -q | grep -q .; then
        log_warning "仍有服務在運行："
        $COMPOSE_CMD ps
        return 1
    fi
    
    log_success "所有服務已停止"
}

# 顯示摘要
show_summary() {
    echo ""
    log_success "🛑 Supabase 服務已停止"
    
    echo ""
    echo -e "${GREEN}📋 停止摘要：${NC}"
    echo "  ✅ 所有服務容器已停止並移除"
    
    if [ "$REMOVE_VOLUMES" = true ]; then
        echo "  ✅ 所有數據卷已移除（資料已刪除）"
    else
        echo "  ✅ 數據卷已保留（資料安全）"
    fi
    
    if [ "$CLEANUP" = true ]; then
        echo "  ✅ 未使用的 Docker 資源已清理"
    fi
    
    echo ""
    echo -e "${BLUE}💡 後續操作：${NC}"
    echo "  重新啟動:    ./scripts/start-official.sh"
    echo "  查看狀態:    $COMPOSE_CMD ps"
    echo "  官方重置:    ./reset.sh"
    
    if [ "$REMOVE_VOLUMES" = false ]; then
        echo "  完整清理:    $0 --volumes --cleanup"
    fi
}

# 主執行流程
main() {
    echo "🛑 停止 AI Brain Supabase (官方 Docker 配置)"
    echo ""
    
    check_environment
    confirm_dangerous_operation
    show_current_status
    stop_services
    cleanup_resources
    verify_stopped
    show_summary
}

# 錯誤處理
trap 'log_error "停止過程中發生錯誤"; exit 1' ERR

# 執行主函數
main "$@"