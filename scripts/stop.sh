#!/bin/bash
# ============================================================================
# AI Brain Supabase - 服務停止腳本 (stop.sh)
# ============================================================================
# 
# 🎯 **腳本功能**：
#   安全停止所有 Supabase 服務容器，確保數據完整性
#   
# 🔧 **主要操作**：
#   1. 環境檢查 (CLI 安裝狀態)
#   2. 優雅關閉所有 Supabase 服務容器
#   3. 驗證服務是否已完全停止
#   4. 可選的 Docker 資源清理
#   
# ✅ **安全特性**：
#   - 優雅關閉，確保數據庫事務完整性
#   - 完整的狀態驗證與錯誤處理
#   - 支援 --cleanup 參數清理 Docker 資源
#   - 處理服務未運行等異常情況
#   
# 📋 **使用方式**：
#   ./scripts/stop.sh           # 標準停止
#   ./scripts/stop.sh --cleanup # 停止並清理 Docker 資源
#   
# 🔗 **相關腳本**：
#   - 啟動服務：./scripts/start.sh
#   - 重置數據庫：./scripts/reset.sh  
#   - 查看狀態：supabase status
#   
# ============================================================================

set -euo pipefail

# ============================================================================
# 顏色定義與日誌函數
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if Supabase CLI is available
check_cli() {
    export PATH="$HOME/bin:$PATH"
    
    if ! command -v supabase &> /dev/null; then
        log_error "Supabase CLI not found. Please run './scripts/setup.sh' first."
        exit 1
    fi
}

# Stop Supabase services
stop_services() {
    export PATH="$HOME/bin:$PATH"
    
    log_info "Stopping Supabase services..."
    
    # Check if services are running
    if ! supabase status &> /dev/null; then
        log_warning "Supabase services are not running."
        return 0
    fi
    
    # Stop services
    supabase stop
    
    log_success "All Supabase services stopped."
}

# Clean up containers (optional)
cleanup_containers() {
    if [[ "${1:-}" == "--cleanup" ]]; then
        log_info "Cleaning up Docker containers..."
        
        # Remove Supabase containers
        docker ps -a --filter "label=com.supabase.cli.project" -q | xargs -r docker rm -f
        
        # Remove Supabase networks
        docker network ls --filter "label=com.supabase.cli.project" -q | xargs -r docker network rm
        
        log_success "Docker cleanup completed."
    fi
}

# Main function
main() {
    log_info "Stopping AI Brain Supabase..."
    echo
    
    check_cli
    stop_services
    cleanup_containers "$@"
    
    echo
    log_success "🛑 Supabase services stopped successfully!"
    echo
    log_info "To start services again, run: ./scripts/start.sh"
    echo
}

# Run main function
main "$@"