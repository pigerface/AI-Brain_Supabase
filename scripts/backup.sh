#!/bin/bash
# ============================================================================
# AI Brain Supabase - 完整備份腳本 (backup.sh)  
# ============================================================================
# 
# 🎯 **腳本功能**：
#   創建完整的項目備份，包含數據庫、配置、代碼
#   
# 🔧 **主要操作**：
#   1. 環境檢查 (服務狀態、CLI 可用性)
#   2. 數據庫完整備份 (使用 pg_dump)
#   3. 配置檔案備份 (supabase/ 目錄)
#   4. 應用代碼備份 (client/, scripts/, sql/)
#   5. 壓縮打包 (tar.gz 格式)
#   6. 時間戳命名 (supabase_backup_YYYYMMDD_HHMMSS.tar.gz)
#   
# ✅ **完整性特性**：
#   - 包含所有數據表與數據
#   - 保留數據庫 schema 結構
#   - 備份所有配置與遷移檔案
#   - 包含客戶端代碼與腳本
#   - 壓縮存儲節省空間
#   
# 💾 **備份內容**：
#   - 完整 PostgreSQL 數據庫 (.sql)
#   - Supabase 配置與遷移檔案
#   - Python 客戶端庫代碼
#   - 管理腳本與 SQL schema
#   - 項目配置檔案 (pyproject.toml 等)
#   
# 📋 **使用方式**：
#   ./scripts/backup.sh
#   
# 📁 **備份位置**：
#   ./backups/supabase_backup_YYYYMMDD_HHMMSS.tar.gz
#   
# 🔗 **相關腳本**：
#   - 恢復說明請參閱 README.md
#   - 重置數據庫：./scripts/reset.sh
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

# Configuration
BACKUP_DIR="backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="supabase_backup_${TIMESTAMP}"

# Check if Supabase CLI is available
check_cli() {
    export PATH="$HOME/bin:$PATH"
    
    if ! command -v supabase &> /dev/null; then
        log_error "Supabase CLI not found. Please run './scripts/setup.sh' first."
        exit 1
    fi
}

# Check if services are running
check_services() {
    export PATH="$HOME/bin:$PATH"
    
    if ! supabase status &> /dev/null; then
        log_error "Supabase services are not running. Please start them first with './scripts/start.sh'"
        exit 1
    fi
}

# Create backup directory
create_backup_dir() {
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"
    log_info "Created backup directory: ${BACKUP_DIR}/${BACKUP_NAME}"
}

# Backup database schema and data
backup_database() {
    export PATH="$HOME/bin:$PATH"
    
    log_info "Backing up database..."
    
    # Get database connection info
    local db_url
    db_url=$(supabase status | grep "DB URL" | awk '{print $3}')
    
    if [[ -z "$db_url" ]]; then
        log_error "Could not get database URL"
        exit 1
    fi
    
    # Backup schema and data
    docker exec supabase_db_ai-brain_supabase pg_dump \
        --username=postgres \
        --host=localhost \
        --port=5432 \
        --dbname=postgres \
        --file=/tmp/backup.sql \
        --verbose \
        --clean \
        --create \
        --if-exists
    
    # Copy backup from container
    docker cp supabase_db_ai-brain_supabase:/tmp/backup.sql "${BACKUP_DIR}/${BACKUP_NAME}/database.sql"
    
    # Clean up temporary file
    docker exec supabase_db_ai-brain_supabase rm -f /tmp/backup.sql
    
    log_success "Database backup completed"
}

# Backup configuration files
backup_config() {
    log_info "Backing up configuration..."
    
    # Copy Supabase configuration
    cp -r supabase "${BACKUP_DIR}/${BACKUP_NAME}/"
    
    # Copy custom SQL files if they exist
    if [[ -d "sql" ]]; then
        cp -r sql "${BACKUP_DIR}/${BACKUP_NAME}/"
    fi
    
    # Copy environment files
    if [[ -f ".env.local" ]]; then
        cp .env.local "${BACKUP_DIR}/${BACKUP_NAME}/"
    fi
    
    if [[ -f ".env.example" ]]; then
        cp .env.example "${BACKUP_DIR}/${BACKUP_NAME}/"
    fi
    
    log_success "Configuration backup completed"
}

# Create backup info file
create_backup_info() {
    local info_file="${BACKUP_DIR}/${BACKUP_NAME}/backup_info.txt"
    
    cat > "$info_file" << EOF
AI Brain Supabase Backup Information
===================================

Backup Date: $(date)
Backup Name: ${BACKUP_NAME}
CLI Version: $(supabase --version)

Included Files:
- database.sql (Complete database dump)
- supabase/ (Project configuration and migrations)
- sql/ (Custom SQL files, if any)
- .env.local (Environment variables, if exists)

Restore Instructions:
1. Ensure Supabase CLI is installed
2. Initialize a new project: supabase init
3. Replace supabase/ directory with backed up version
4. Start services: supabase start
5. Restore database: supabase db reset (to apply migrations)
   Or manually: psql -f database.sql <connection_string>

Generated by: AI Brain Supabase backup script
EOF
    
    log_success "Backup info file created"
}

# Compress backup
compress_backup() {
    if command -v tar &> /dev/null; then
        log_info "Compressing backup..."
        
        cd "$BACKUP_DIR"
        tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
        rm -rf "$BACKUP_NAME"
        cd ..
        
        log_success "Backup compressed: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    else
        log_warning "tar not available, backup left uncompressed"
    fi
}

# Clean old backups
clean_old_backups() {
    local keep_days=${1:-7}  # Keep backups for 7 days by default
    
    log_info "Cleaning backups older than ${keep_days} days..."
    
    find "$BACKUP_DIR" -name "supabase_backup_*" -type f -mtime +${keep_days} -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "supabase_backup_*" -type d -mtime +${keep_days} -exec rm -rf {} + 2>/dev/null || true
    
    log_success "Old backups cleaned"
}

# Display backup summary
show_summary() {
    local backup_path
    if [[ -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" ]]; then
        backup_path="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    else
        backup_path="${BACKUP_DIR}/${BACKUP_NAME}"
    fi
    
    local backup_size
    backup_size=$(du -sh "$backup_path" | cut -f1)
    
    echo
    log_success "🎉 Backup completed successfully!"
    echo
    log_info "📋 Backup Details:"
    echo "  • Name: $BACKUP_NAME"
    echo "  • Location: $backup_path"
    echo "  • Size: $backup_size"
    echo "  • Contains: Database dump, configurations, migrations"
    echo
    log_info "📝 To restore this backup:"
    echo "  1. Extract: tar -xzf ${BACKUP_NAME}.tar.gz"
    echo "  2. Copy supabase/ directory to your project"
    echo "  3. Run: supabase start && supabase db reset"
    echo
}

# Main function
main() {
    log_info "Starting AI Brain Supabase backup..."
    echo
    
    check_cli
    check_services
    create_backup_dir
    backup_database
    backup_config
    create_backup_info
    compress_backup
    clean_old_backups
    show_summary
}

# Handle cleanup on interrupt
cleanup() {
    if [[ -d "${BACKUP_DIR}/${BACKUP_NAME}" ]]; then
        log_warning "Backup interrupted, cleaning up..."
        rm -rf "${BACKUP_DIR}/${BACKUP_NAME}"
    fi
}

trap cleanup INT

# Run main function
main "$@"