#!/bin/bash
# ============================================================================
# AI Brain Supabase - 環境安裝與初始化腳本 (setup.sh)
# ============================================================================
# 
# 🎯 **腳本功能**：
#   一鍵完整項目初始化，包含環境檢測、軟體安裝、項目配置
#   
# 🔧 **主要操作**：
#   1. 系統環境檢測 (Linux/macOS, 架構檢查)
#   2. Docker 安裝狀態驗證與檢查
#   3. Supabase CLI 自動下載與安裝
#   4. Supabase 項目初始化與配置
#   5. RAG 系統數據庫遷移檔案創建
#   6. 環境變量配置檔案生成
#   
# ✅ **智能特性**：
#   - 自動檢測已安裝的軟體，避免重複安裝
#   - 優先使用簡化版 RAG schema (相容性更好)
#   - 自動設定 PATH 環境變量
#   - 完善的錯誤處理與狀態回報
#   
# 📋 **使用方式**：
#   ./scripts/setup.sh
#   
# 🔗 **後續步驟**：
#   執行成功後可使用 ./scripts/start.sh 啟動服務
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

# Check if running on Linux
check_os() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_warning "This script is optimized for Linux. Other OS may require manual steps."
    fi
    
    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log_warning "Architecture $arch detected. This script is optimized for x86_64."
    fi
}

# Check Docker installation
check_docker() {
    log_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    log_success "Docker is installed and running"
}

# Install Supabase CLI
install_supabase_cli() {
    log_info "Checking Supabase CLI installation..."
    
    # Check if Supabase CLI is already installed and working
    if command -v supabase &> /dev/null && supabase --version &> /dev/null; then
        local version=$(supabase --version 2>/dev/null | head -1)
        log_success "Supabase CLI is already installed ($version)"
        return 0
    fi
    
    log_info "Installing Supabase CLI..."
    
    # Create local bin directory if it doesn't exist
    mkdir -p ~/bin
    
    # Use temporary directory to avoid conflicts
    local temp_dir=$(mktemp -d)
    log_info "Using temporary directory: $temp_dir"
    
    # Download and install Supabase CLI in temp directory
    if (
        cd "$temp_dir" && \
        curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz | tar -xz && \
        mv supabase ~/bin/
    ); then
        log_success "Supabase CLI installed successfully"
    else
        log_error "Failed to install Supabase CLI"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
    
    # Add to PATH if not already there
    # Check file content to avoid duplicates
    if [[ "$SHELL" == *"zsh"* ]] && ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.zshrc 2>/dev/null; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
        export PATH="$HOME/bin:$PATH"
    elif [[ "$SHELL" == *"bash"* ]] && ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/bin:$PATH"
    fi
    
    log_success "Supabase CLI installed successfully"
}

# Initialize Supabase project
init_supabase_project() {
    log_info "Initializing Supabase project..."
    
    if [[ -f "supabase/config.toml" ]]; then
        log_success "Supabase project already initialized"
        return 0
    fi
    
    # Set PATH for this session
    export PATH="$HOME/bin:$PATH"
    
    # Initialize Supabase project
    echo -e "N\nN" | supabase init
    
    log_success "Supabase project initialized"
}

# Create initial seed file
create_seed_file() {
    log_info "Creating initial seed file..."
    
    if [[ -f "supabase/seed.sql" ]]; then
        log_warning "Seed file already exists, skipping creation"
        return 0
    fi
    
    cat > supabase/seed.sql << 'EOF'
-- Initial seed data for AI Brain Supabase
-- This file will be automatically loaded when running 'supabase db reset'

-- Example: Create initial roles and permissions
INSERT INTO auth.users (id, email, created_at) VALUES 
('00000000-0000-0000-0000-000000000001', 'admin@ai-brain.local', NOW())
ON CONFLICT (id) DO NOTHING;

-- Add your custom seed data below
-- Example tables, functions, triggers, etc.

EOF
    
    log_success "Initial seed file created"
}

# Create migration for initial schema
create_initial_migration() {
    log_info "Checking for initial migration..."
    
    export PATH="$HOME/bin:$PATH"
    
    if ls supabase/migrations/*.sql &> /dev/null; then
        log_info "Existing migrations found, recreating with latest schema..."
        rm -f supabase/migrations/*.sql
    fi
    
    log_info "Creating RAG system initial migration..."
    supabase migration new rag_system_init
    
    # Get the migration file path
    local migration_file=$(ls supabase/migrations/*_rag_system_init.sql | head -1)
    
    # Use only the main RAG schema file
    if [[ -f "sql/init_schema.sql" ]]; then
        log_info "Copying RAG system schema to migration..."
        # Copy the RAG system schema to the migration file
        cat sql/init_schema.sql > "$migration_file"
        log_success "RAG system schema integrated into migration"
    else
        log_error "RAG schema file (sql/init_schema.sql) not found!"
        log_info "Please ensure sql/init_schema.sql exists before running setup"
        exit 1
    fi
    
    log_success "Initial migration created"
}

# Set up environment variables
setup_environment() {
    log_info "Setting up environment configuration..."
    
    # Create .env.example file
    cat > .env.example << 'EOF'
# Supabase CLI Configuration
# These variables are automatically managed by the CLI
# Copy this file to .env.local for custom overrides

# Project Configuration
PROJECT_ID=ai-brain-supabase

# API Configuration (auto-generated by CLI)
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=auto-generated
SUPABASE_SERVICE_ROLE_KEY=auto-generated

# Database Configuration (auto-generated by CLI)
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres

# Custom Application Variables
NODE_ENV=development
LOG_LEVEL=info

# Add your custom environment variables below
EOF
    
    log_success "Environment configuration created"
}

# Main installation process
main() {
    log_info "Starting AI Brain Supabase setup..."
    echo
    
    check_os
    check_docker
    install_supabase_cli
    init_supabase_project
    create_seed_file
    create_initial_migration
    setup_environment
    
    echo
    log_success "🎉 Setup completed successfully!"
    echo
    log_info "Next steps:"
    echo "  1. Run './scripts/start.sh' to start Supabase services"
    echo "  2. Visit http://localhost:54323 for the Studio Dashboard"
    echo "  3. Check './scripts/start.sh' output for API keys and URLs"
    echo
    log_info "Useful commands:"
    echo "  - Start services: ./scripts/start.sh"
    echo "  - Stop services: ./scripts/stop.sh"
    echo "  - Reset database: ./scripts/reset.sh"
    echo "  - View logs: supabase logs"
    echo
}

# Run main function
main "$@"