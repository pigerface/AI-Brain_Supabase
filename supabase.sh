#!/bin/bash
set -e

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查依賴
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose is not installed${NC}"
        exit 1
    fi
    
    if ! command -v uv &> /dev/null; then
        echo -e "${RED}❌ UV is not installed${NC}"
        echo -e "${YELLOW}💡 Install UV: curl -LsSf https://astral.sh/uv/install.sh | sh${NC}"
        exit 1
    fi
}

# 首次設置
setup() {
    echo -e "${GREEN}🚀 Setting up Supabase local environment...${NC}"
    check_dependencies
    
    # 創建必要目錄
    mkdir -p volumes/{db,storage} sql volumes/api volumes/logs volumes/functions
    
    # 複製環境變數
    if [ ! -f .env ]; then
        cp .env.example .env
        echo -e "${YELLOW}📝 Created .env file from template${NC}"
        echo -e "${YELLOW}⚠️  Please edit .env file with your settings before starting${NC}"
        echo -e "${YELLOW}   Especially change POSTGRES_PASSWORD, JWT_SECRET, and API keys${NC}"
        exit 1
    fi
    
    # 創建 Kong 配置檔案
    if [ ! -f volumes/api/kong.yml ]; then
        create_kong_config
    fi
    
    # 創建 Vector 日誌配置
    if [ ! -f volumes/logs/vector.yml ]; then
        create_vector_config
    fi
    
    # 創建 Functions 目錄結構
    if [ ! -d volumes/functions/main ]; then
        create_functions_structure
    fi
    
    # 安裝 Python 依賴
    echo -e "${BLUE}📦 Installing Python dependencies with UV...${NC}"
    cd ..  # 回到 workspace 根目錄
    uv sync --extra monitoring --extra dev
    cd supabase  # 回到 supabase 目錄
    
    echo -e "${GREEN}✅ Setup complete! You can now run: ./supabase.sh start${NC}"
    echo -e "${BLUE}💡 Python environment ready with UV workspace${NC}"
}

# 創建 Kong 配置
create_kong_config() {
    cat > volumes/api/kong.yml << 'EOF'
_format_version: "1.1"
_transform: true

consumers:
  - username: anon
    keyauth_credentials:
      - key: ${ANON_KEY}
  - username: service_role
    keyauth_credentials:
      - key: ${SERVICE_ROLE_KEY}

acls:
  - consumer: anon
    group: anon
  - consumer: service_role
    group: admin

services:
  - name: auth-v1-open
    url: http://auth:9999/verify
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - /auth/v1/verify
    plugins:
      - name: cors
  - name: auth-v1-open-callback
    url: http://auth:9999/callback
    routes:
      - name: auth-v1-open-callback
        strip_path: true
        paths:
          - /auth/v1/callback
    plugins:
      - name: cors
  - name: auth-v1-open-authorize
    url: http://auth:9999/authorize
    routes:
      - name: auth-v1-open-authorize
        strip_path: true
        paths:
          - /auth/v1/authorize
    plugins:
      - name: cors

  - name: auth-v1
    _comment: "GoTrue: /auth/v1/* -> http://auth:9999/*"
    url: http://auth:9999/
    routes:
      - name: auth-v1-all
        strip_path: true
        paths:
          - /auth/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: rest-v1
    _comment: "PostgREST: /rest/v1/* -> http://rest:3000/*"
    url: http://rest:3000/
    routes:
      - name: rest-v1-all
        strip_path: true
        paths:
          - /rest/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: true
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: realtime-v1
    _comment: "Realtime: /realtime/v1/* -> ws://realtime:4000/socket/*"
    url: http://realtime-dev.supabase-realtime:4000/socket/
    routes:
      - name: realtime-v1-all
        strip_path: true
        paths:
          - /realtime/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: storage-v1
    _comment: "Storage: /storage/v1/* -> http://storage:5000/*"
    url: http://storage:5000/
    routes:
      - name: storage-v1-all
        strip_path: true
        paths:
          - /storage/v1/
    plugins:
      - name: cors

  - name: functions-v1
    _comment: "Edge Functions: /functions/v1/* -> http://functions:9000/*"
    url: http://functions:9000/
    routes:
      - name: functions-v1-all
        strip_path: true
        paths:
          - /functions/v1/
    plugins:
      - name: cors

  - name: meta
    _comment: "pg-meta: /pg/* -> http://meta:8080/*"
    url: http://meta:8080/
    routes:
      - name: meta-all
        strip_path: true
        paths:
          - /pg/
EOF
    echo -e "${GREEN}📝 Created Kong configuration${NC}"
}

# 創建 Vector 日誌配置
create_vector_config() {
    cat > volumes/logs/vector.yml << 'EOF'
data_dir: /var/lib/vector
api:
  enabled: true
  address: 127.0.0.1:8686
sources:
  docker_host:
    type: docker_logs
    include_labels:
      - com.docker.compose.project
      - com.docker.compose.service

transforms:
  project_logs:
    type: remap
    inputs:
      - docker_host
    source: |
      .project = .label."com.docker.compose.project"
      .service = .label."com.docker.compose.service"
      del(.label)

sinks:
  pgsql:
    type: postgresql
    inputs:
      - project_logs
    connection_string: "postgresql://supabase_admin:${POSTGRES_PASSWORD}@db:${POSTGRES_PORT}/${POSTGRES_DB}"
    table: logs
    encoding:
      method: json
    buffer:
      max_events: 10000
EOF
    echo -e "${GREEN}📝 Created Vector logging configuration${NC}"
}

# 創建 Edge Functions 結構
create_functions_structure() {
    mkdir -p volumes/functions/main
    cat > volumes/functions/main/index.ts << 'EOF'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

console.log("Hello from Functions!")

serve(async (req) => {
  const { name } = await req.json()
  const data = {
    message: `Hello ${name}!`,
  }

  return new Response(
    JSON.stringify(data),
    { headers: { "Content-Type": "application/json" } },
  )
})
EOF
    echo -e "${GREEN}📝 Created Edge Functions structure${NC}"
}

# 啟動服務
start() {
    echo -e "${GREEN}▶️  Starting Supabase...${NC}"
    check_dependencies
    
    # 檢查 .env 檔案
    if [ ! -f .env ]; then
        echo -e "${RED}❌ .env file not found. Run './supabase.sh setup' first${NC}"
        exit 1
    fi
    
    # 啟動 Docker Compose
    docker compose up -d
    
    # 等待 PostgreSQL 就緒
    echo -e "${BLUE}⏳ Waiting for PostgreSQL to be ready...${NC}"
    until docker compose exec -T db pg_isready -U postgres > /dev/null 2>&1; do
        printf "."
        sleep 2
    done
    echo ""
    
    # 初始化 schema（如果存在）
    if [ -f sql/init_schema.sql ]; then
        echo -e "${BLUE}📊 Initializing database schema...${NC}"
        docker compose exec -T db psql -U postgres -d postgres < sql/init_schema.sql 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Schema initialization had warnings (this is normal for existing schemas)${NC}"
        }
    fi
    
    echo -e "${GREEN}✅ Supabase is running!${NC}"
    echo -e "${GREEN}📊 Studio Dashboard: http://localhost:8000${NC}"
    echo -e "${GREEN}🔗 API Gateway: http://localhost:8000${NC}"
    echo -e "${GREEN}🗄️  Database: postgresql://postgres:[password]@localhost:5432/postgres${NC}"
    echo ""
    echo -e "${BLUE}📋 Service Status:${NC}"
    docker compose ps
}

# 停止服務
stop() {
    echo -e "${YELLOW}⏹️  Stopping Supabase...${NC}"
    docker compose down
    echo -e "${GREEN}✅ Supabase stopped${NC}"
}

# 重啟服務
restart() {
    echo -e "${BLUE}🔄 Restarting Supabase...${NC}"
    stop
    sleep 2
    start
}

# 查看服務狀態
status() {
    echo -e "${BLUE}📋 Supabase Service Status:${NC}"
    docker compose ps
}

# 備份資料庫
backup() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="backups"
    BACKUP_FILE="${BACKUP_DIR}/supabase_backup_${TIMESTAMP}.sql"
    
    mkdir -p ${BACKUP_DIR}
    
    echo -e "${GREEN}💾 Creating backup: ${BACKUP_FILE}${NC}"
    docker compose exec -T db pg_dump -U postgres -d postgres > ${BACKUP_FILE}
    
    if [ $? -eq 0 ]; then
        gzip ${BACKUP_FILE}
        echo -e "${GREEN}✅ Backup created successfully: ${BACKUP_FILE}.gz${NC}"
        echo -e "${BLUE}📁 Backup size: $(du -h ${BACKUP_FILE}.gz | cut -f1)${NC}"
    else
        echo -e "${RED}❌ Backup failed${NC}"
        exit 1
    fi
}

# 還原資料庫
restore() {
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Please provide backup file${NC}"
        echo -e "${BLUE}Usage: $0 restore backup_file.sql.gz${NC}"
        echo -e "${BLUE}Available backups:${NC}"
        ls -la backups/ 2>/dev/null || echo "No backups found"
        exit 1
    fi
    
    if [ ! -f "$1" ]; then
        echo -e "${RED}❌ Backup file '$1' not found${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  This will REPLACE the current database. Continue? (y/n)${NC}"
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${BLUE}📖 Restore cancelled${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📥 Restoring database from: $1${NC}"
    
    # 解壓並還原
    if [[ "$1" == *.gz ]]; then
        gunzip -c "$1" | docker compose exec -T db psql -U postgres -d postgres
    else
        docker compose exec -T db psql -U postgres -d postgres < "$1"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Database restored successfully${NC}"
    else
        echo -e "${RED}❌ Restore failed${NC}"
        exit 1
    fi
}

# 查看日誌
logs() {
    if [ -n "$2" ]; then
        echo -e "${BLUE}📋 Showing logs for service: $2${NC}"
        docker compose logs -f "$2"
    else
        echo -e "${BLUE}📋 Showing logs for all services (Ctrl+C to exit):${NC}"
        docker compose logs -f
    fi
}

# 進入 PostgreSQL 命令列
psql() {
    echo -e "${BLUE}🔗 Connecting to PostgreSQL...${NC}"
    echo -e "${YELLOW}💡 Tip: Use \\q to exit${NC}"
    docker compose exec db psql -U postgres -d postgres
}

# Python 環境管理
python_shell() {
    echo -e "${BLUE}🐍 Starting Python shell with Supabase client...${NC}"
    cd ..  # 回到 workspace 根目錄
    uv run python -c "
from supabase.client import create_client
print('Supabase client available as: client = create_client()')
client = create_client()
print(f'Config info: {client.get_config_info()}')
"
    uv run python
    cd supabase
}

# 安裝依賴
install_deps() {
    echo -e "${BLUE}📦 Installing/updating dependencies with UV...${NC}"
    cd ..  # 回到 workspace 根目錄
    uv sync --extra monitoring --extra dev --extra ai
    cd supabase
    echo -e "${GREEN}✅ Dependencies installed${NC}"
}

# 運行測試
test() {
    echo -e "${BLUE}🧪 Running tests...${NC}"
    cd ..  # 回到 workspace 根目錄
    uv run pytest supabase/tests/ -v
    cd supabase
}

# 程式碼檢查
lint() {
    echo -e "${BLUE}🔍 Running code quality checks...${NC}"
    cd ..  # 回到 workspace 根目錄
    echo "Running ruff..."
    uv run ruff check supabase/client/
    echo "Running black..."
    uv run black --check supabase/client/
    cd supabase
}

# 更新 Supabase
update() {
    echo -e "${BLUE}🔄 Updating Supabase...${NC}"
    
    # 備份當前資料
    echo -e "${BLUE}💾 Creating backup before update...${NC}"
    backup
    
    # 停止服務
    stop
    
    # 更新 Docker images
    echo -e "${BLUE}📥 Pulling latest images...${NC}"
    docker compose pull
    
    # 重新啟動
    start
    
    echo -e "${GREEN}✅ Update complete!${NC}"
}

# 清理
clean() {
    echo -e "${YELLOW}⚠️  This will remove all containers, volumes, and data. Continue? (y/n)${NC}"
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${BLUE}📖 Clean cancelled${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}🧹 Cleaning up Supabase...${NC}"
    docker compose down -v --remove-orphans
    docker compose rm -f
    
    # 刪除卷目錄（保留備份）
    echo -e "${YELLOW}🗑️  Removing volumes...${NC}"
    rm -rf volumes/db volumes/storage volumes/logs
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# 主程式
case "$1" in
    setup)
        setup
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    backup)
        backup
        ;;
    restore)
        restore "$2"
        ;;
    logs)
        logs "$1" "$2"
        ;;
    psql)
        psql
        ;;
    update)
        update
        ;;
    clean)
        clean
        ;;
    python)
        python_shell
        ;;
    install)
        install_deps
        ;;
    test)
        test
        ;;
    lint)
        lint
        ;;
    *)
        echo -e "${BLUE}🚀 Supabase Local Management Script (UV Workspace)${NC}"
        echo ""
        echo -e "${GREEN}Usage: $0 {command}${NC}"
        echo ""
        echo -e "${BLUE}🔧 Setup & Control:${NC}"
        echo "  setup      - First time setup (create directories, configs, install deps)"
        echo "  start      - Start all services"
        echo "  stop       - Stop all services"
        echo "  restart    - Restart all services"
        echo "  status     - Show service status"
        echo ""
        echo -e "${BLUE}💾 Data Management:${NC}"
        echo "  backup     - Backup database"
        echo "  restore    - Restore database from backup file"
        echo "  clean      - Remove all data and containers"
        echo ""
        echo -e "${BLUE}🔍 Monitoring:${NC}"
        echo "  logs       - Show logs (add service name for specific service)"
        echo "  psql       - Connect to PostgreSQL CLI"
        echo ""
        echo -e "${BLUE}🐍 Python Development:${NC}"
        echo "  python     - Start Python shell with Supabase client loaded"
        echo "  install    - Install/update Python dependencies with UV"
        echo "  test       - Run Python tests"
        echo "  lint       - Run code quality checks (ruff + black)"
        echo ""
        echo -e "${BLUE}🔄 Maintenance:${NC}"
        echo "  update     - Update Supabase to latest version"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo "  $0 setup                    # First time setup with UV"
        echo "  $0 start                    # Start Supabase"
        echo "  $0 python                   # Python development shell"
        echo "  $0 logs db                  # Show database logs"
        echo "  $0 restore backup.sql.gz    # Restore from backup"
        exit 1
        ;;
esac