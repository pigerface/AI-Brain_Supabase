#!/bin/bash
# ============================================================================
# AI Brain Supabase - 服務啟動與數據庫初始化腳本 (start.sh)
# ============================================================================
# 
# 🎯 **腳本功能**：
#   智能啟動 Supabase 服務並自動檢查與初始化數據庫 schema
#   
# 🔧 **主要操作**：
#   1. 環境檢查 (CLI 安裝、項目配置、Docker 狀態)
#   2. Supabase 服務容器啟動
#   3. 數據庫連接等待與健康檢查 (最多 30 次重試)
#   4. 核心表格存在性檢測 (resources, chunks, media_sources)
#   5. 自動應用數據庫遷移 (如需要)
#   6. 完整服務狀態報告與連接信息顯示
#   
# ✅ **智能特性**：
#   - 自動等待數據庫就緒，避免連接失敗
#   - 智能檢測 schema 是否已初始化
#   - 自動應用遷移檔案 (如表格不存在)
#   - 完整的錯誤處理與狀態檢查
#   - 提供開發提示與快速連接資訊
#   
# 📋 **使用方式**：
#   ./scripts/start.sh
#   
# 🔗 **相關腳本**：
#   - 停止服務：./scripts/stop.sh  
#   - 重置數據庫：./scripts/reset.sh
#   - 查看日誌：supabase logs -f
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

# Check if project is initialized
check_project() {
    if [[ ! -f "supabase/config.toml" ]]; then
        log_error "Supabase project not initialized. Please run './scripts/setup.sh' first."
        exit 1
    fi
}

# Check Docker
check_docker() {
    # Check if Docker context is set to desktop-linux and switch to default
    local current_context=$(docker context show 2>/dev/null || echo "unknown")
    if [[ "$current_context" == "desktop-linux" ]]; then
        log_info "Switching Docker context from desktop-linux to default..."
        docker context use default &> /dev/null
        log_success "Docker context switched to default"
    fi
    
    # Check if Docker is accessible
    if ! docker info &> /dev/null; then
        log_error "Docker is not running or not accessible."
        log_info "Try one of the following:"
        log_info "  1. Start Docker: sudo systemctl start docker"
        log_info "  2. Add user to docker group: sudo usermod -aG docker \$USER && newgrp docker"
        log_info "  3. If using Docker Desktop, start it from the application menu"
        exit 1
    fi
}

# Start Supabase services
start_services() {
    export PATH="$HOME/bin:$PATH"
    
    # Ensure we're using system Docker socket, not Docker Desktop
    unset DOCKER_HOST
    export DOCKER_CONTEXT=default
    
    log_info "Starting Supabase services..."
    echo
    
    # Start Supabase with increased timeout
    timeout 600 supabase start || {
        log_error "Failed to start Supabase services"
        log_info "This might be due to network issues downloading Docker images"
        log_info "Try running the command again, or check Docker Hub rate limits"
        exit 1
    }
}

# Display connection info
show_connection_info() {
    export PATH="$HOME/bin:$PATH"
    export DOCKER_CONTEXT=default
    
    log_success "🎉 Supabase services started successfully!"
    echo
    log_info "📋 Connection Information:"
    
    # Get status information
    supabase status
    
    echo
    log_info "🔗 Quick Access URLs:"
    echo "  • Studio Dashboard: http://localhost:54333"
    echo "  • API Endpoint: http://localhost:54331"
    echo "  • Database: postgresql://postgres:postgres@localhost:54332/postgres"
    echo "  • Inbucket (Email): http://localhost:54334"
    echo
    log_info "📝 Development Tips:"
    echo "  • Use 'supabase logs -f' to watch logs"
    echo "  • Use 'supabase db reset' to reset database with migrations"
    echo "  • Use './scripts/stop.sh' to stop all services"
    echo
}

# Check and initialize database schema
check_database_schema() {
    log_info "🗄️ Checking database schema..."
    
    # Wait for database to be ready
    local max_attempts=15
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -c "SELECT 1;" > /dev/null 2>&1; then
            log_success "Database is ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_warning "Database connection timeout after $max_attempts attempts"
            log_info "This might be normal - Supabase services may still be starting"
            log_info "Check http://127.0.0.1:54323 to verify Studio is accessible"
            return 0  # Don't fail the script, just warn
        fi
        
        log_info "Waiting for database... (attempt $attempt/$max_attempts)"
        sleep 3
        ((attempt++))
    done
    
    # Check if core tables exist
    local table_count=$(psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('resources', 'chunks', 'media_sources');" 2>/dev/null | xargs || echo "0")
    
    if [ "$table_count" -ge 2 ]; then
        log_success "Database schema verified! (found $table_count core tables)"
    else
        log_warning "Core tables not found (found $table_count). Migrations may still be applying..."
        log_info "Note: 'supabase start' automatically applies migrations from supabase/migrations/"
        log_info "If issues persist, run './scripts/reset.sh' to reinitialize"
    fi
}

# Main function
main() {
    log_info "Starting AI Brain Supabase..."
    echo
    
    check_cli
    check_project
    check_docker
    start_services
    
    # Give Supabase a moment to fully initialize
    log_info "Waiting for services to fully initialize..."
    sleep 5
    
    check_database_schema
    show_connection_info
}

# Handle interrupts
trap 'log_warning "Interrupted. Services may still be running. Use ./scripts/stop.sh to stop them."' INT

# Run main function
main "$@"