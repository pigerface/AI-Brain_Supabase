#!/bin/bash
# ============================================================================
# AI Brain Supabase - Docker 數據庫重置腳本 (reset-db.sh)
# ============================================================================
# 
# 🎯 **腳本功能**：
#   重置 Supabase 數據庫到初始狀態（不依賴 CLI）
#   
# 🔧 **主要操作**：
#   1. 安全確認操作
#   2. 停止相關服務
#   3. 清理數據庫數據
#   4. 重新應用初始化腳本
#   5. 重啟服務
#   
# ✅ **選項**：
#   --force : 跳過確認提示，直接執行重置
#   --keep-users : 保留用戶數據（僅重置應用表格）
#   
# ⚠️  **警告**：此操作會刪除所有數據！
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
FORCE=false
KEEP_USERS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --keep-users)
            KEEP_USERS=true
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
    echo "重置 Supabase 數據庫到初始狀態"
    echo ""
    echo "⚠️  警告：此操作會刪除所有數據！"
    echo ""
    echo "Options:"
    echo "  --force       跳過確認提示，直接執行"
    echo "  --keep-users  保留 auth.users 表（僅重置應用數據）"
    echo "  -h, --help    顯示此幫助信息"
    echo ""
    echo "Examples:"
    echo "  $0                    # 完整重置（含用戶數據）"
    echo "  $0 --keep-users      # 重置但保留用戶"
    echo "  $0 --force           # 無確認直接重置"
}

# 檢查環境
check_environment() {
    if ! docker info &> /dev/null; then
        log_error "Docker 未運行或無權限訪問"
        exit 1
    fi
    
    if [ ! -f "docker-compose.yml" ]; then
        log_error "Docker Compose 配置文件不存在"
        exit 1
    fi
    
    # 檢查服務是否運行
    local running_containers=$(docker-compose ps -q --filter "status=running")
    if [ -z "$running_containers" ]; then
        log_error "Supabase 服務未運行"
        log_info "請先執行 ./scripts/start-docker.sh 啟動服務"
        exit 1
    fi
}

# 確認重置操作
confirm_reset() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    log_warning "⚠️  警告：此操作將會刪除所有數據庫資料！"
    echo ""
    echo -e "${RED}將會被刪除的內容：${NC}"
    echo "  🗑️  所有應用數據（resources, chunks, images 等）"
    
    if [ "$KEEP_USERS" = false ]; then
        echo "  🗑️  所有用戶數據和認證信息"
        echo "  🗑️  所有文件存儲內容"
    else
        echo "  ✅ 保留用戶數據和認證信息"
    fi
    
    echo ""
    echo -e "${GREEN}將會保留的內容：${NC}"
    echo "  ✅ 系統配置和設定"
    echo "  ✅ 數據庫結構和函數"
    
    echo ""
    read -p "確定要繼續重置嗎？請輸入 'RESET' 確認: " -r
    if [ "$REPLY" != "RESET" ]; then
        log_info "重置操作已取消"
        exit 0
    fi
}

# 備份當前數據（可選）
create_backup() {
    log_info "創建重置前備份..."
    
    local backup_file="backup_before_reset_$(date +%Y%m%d_%H%M%S).sql"
    
    if docker-compose exec -T db pg_dump -U postgres postgres > "$backup_file" 2>/dev/null; then
        log_success "備份已創建: $backup_file"
    else
        log_warning "無法創建備份，繼續重置操作"
    fi
}

# 重置數據庫
reset_database() {
    log_info "開始重置數據庫..."
    
    # 第一步：連接數據庫並清理數據
    if [ "$KEEP_USERS" = true ]; then
        log_info "清理應用數據（保留用戶數據）..."
        
        # 定義需要清理的應用表格
        local app_tables=(
            "media_sources"
            "resources" 
            "parsed_artifacts"
            "chunks"
            "images"
            "chunk_embeddings"
            "parse_settings"
            "chunk_settings"
        )
        
        for table in "${app_tables[@]}"; do
            docker-compose exec -T db psql -U postgres -d postgres -c "
                DELETE FROM $table;
            " 2>/dev/null || log_warning "表格 $table 不存在或清理失敗"
        done
        
    else
        log_info "完整重置數據庫..."
        
        # 刪除所有用戶創建的 schemas 和數據
        docker-compose exec -T db psql -U postgres -d postgres -c "
            -- 刪除 public schema 中的所有數據
            DROP SCHEMA IF EXISTS public CASCADE;
            CREATE SCHEMA public;
            GRANT ALL ON SCHEMA public TO postgres;
            GRANT ALL ON SCHEMA public TO public;
            
            -- 清理 auth schema 中的用戶數據
            DELETE FROM auth.users;
            DELETE FROM auth.identities;
            DELETE FROM auth.sessions;
            DELETE FROM auth.refresh_tokens;
            
            -- 清理 storage 中的文件
            DELETE FROM storage.objects;
            DELETE FROM storage.buckets WHERE id != 'avatars';
        "
    fi
    
    log_success "數據庫數據清理完成"
}

# 重新應用初始化腳本
reapply_initialization() {
    log_info "重新應用數據庫初始化..."
    
    # 檢查初始化腳本目錄
    if [ ! -d "volumes/db/init" ]; then
        log_warning "初始化腳本目錄不存在"
        return 0
    fi
    
    # 應用所有初始化腳本
    local init_files=($(ls volumes/db/init/*.sql 2>/dev/null || true))
    
    if [ ${#init_files[@]} -eq 0 ]; then
        log_warning "沒有找到初始化腳本"
        return 0
    fi
    
    for sql_file in "${init_files[@]}"; do
        local filename=$(basename "$sql_file")
        log_info "應用初始化腳本: $filename"
        
        if docker-compose exec -T db psql -U postgres -d postgres -f "/docker-entrypoint-initdb.d/$filename"; then
            log_success "✅ $filename 應用成功"
        else
            log_error "❌ $filename 應用失敗"
            return 1
        fi
    done
    
    log_success "所有初始化腳本已應用"
}

# 重啟相關服務
restart_services() {
    log_info "重啟相關服務以確保狀態同步..."
    
    # 重啟 PostgREST 服務以重新載入 schema
    docker-compose restart rest || log_warning "無法重啟 rest 服務"
    
    # 重啟 Auth 服務
    docker-compose restart auth || log_warning "無法重啟 auth 服務"
    
    # 等待服務穩定
    sleep 5
    
    log_success "服務重啟完成"
}

# 驗證重置結果
verify_reset() {
    log_info "驗證重置結果..."
    
    # 檢查數據庫連接
    if ! docker-compose exec -T db pg_isready -U postgres &> /dev/null; then
        log_error "數據庫連接失敗"
        return 1
    fi
    
    # 檢查基本表格是否存在
    local table_count=$(docker-compose exec -T db psql -U postgres -d postgres -t -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    " 2>/dev/null | tr -d ' ')
    
    if [ "$table_count" -gt 0 ]; then
        log_success "✅ 數據庫表格結構正常（$table_count 個表格）"
    else
        log_warning "⚠️ 沒有找到應用表格，可能需要手動初始化"
    fi
    
    # 檢查系統健康狀態
    if curl -s http://localhost:8000/rest/v1/ &> /dev/null; then
        log_success "✅ API 服務正常"
    else
        log_warning "⚠️ API 服務可能需要時間恢復"
    fi
    
    log_success "重置驗證完成"
}

# 顯示重置摘要
show_reset_summary() {
    echo ""
    log_success "🔄 數據庫重置完成！"
    
    echo ""
    echo -e "${GREEN}📋 重置摘要：${NC}"
    echo "  ✅ 數據庫數據已清理"
    
    if [ "$KEEP_USERS" = true ]; then
        echo "  ✅ 用戶數據已保留"
    else
        echo "  ✅ 用戶數據已重置"
    fi
    
    echo "  ✅ 初始化腳本已重新應用"
    echo "  ✅ 相關服務已重啟"
    
    echo ""
    echo -e "${BLUE}🔗 連接信息：${NC}"
    echo "  Studio: http://localhost:3000"
    echo "  API:    http://localhost:8000"
    
    echo ""
    echo -e "${YELLOW}📝 後續步驟：${NC}"
    echo "  1. 訪問 Studio 確認數據庫狀態"
    echo "  2. 重新創建必要的用戶和數據"
    echo "  3. 測試 API 功能是否正常"
    
    if ls backup_before_reset_*.sql >/dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}💾 備份文件：${NC}"
        ls backup_before_reset_*.sql
    fi
}

# 主執行流程
main() {
    echo "🔄 AI Brain Supabase 數據庫重置"
    echo ""
    
    check_environment
    confirm_reset
    create_backup
    reset_database
    reapply_initialization
    restart_services
    verify_reset
    show_reset_summary
}

# 錯誤處理
trap 'log_error "重置過程中發生錯誤"; exit 1' ERR

# 執行主函數
main "$@"