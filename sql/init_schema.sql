-- ============================================================
-- Postgres RAG Schema (Resources/Parsed/Chunks/Images + Embeddings)
-- Author: ChatGPT (Ginger) + Claude Code
-- Date: 2025-08-29
-- ------------------------------------------------------------
-- 使用說明：
-- 1) 在目標資料庫執行本檔：\i init_schema.sql
-- 2) 若尚未安裝外掛：CREATE EXTENSION 會自動忽略已存在的外掛
-- 3) 若你的 embedding 維度不是 1536，請將 vector(1536) 改為你的維度
-- 4) chunk_embeddings 為可選表，若你只使用單一模型，可不使用
-- ============================================================

-- ---- Extensions ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgvector;
-- 可選：大小寫不敏感字串
-- CREATE EXTENSION IF NOT EXISTS citext;

-- ---- ENUM Types ------------------------------------------------------------
-- Note: Removed resource_file_type and src_category ENUMs in favor of flexible text types

-- ---- Common trigger to maintain updated_at ---------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$ LANGUAGE plpgsql;

-- =============================================================================
-- 1) media_sources：媒體來源主檔
-- =============================================================================
CREATE TABLE IF NOT EXISTS media_sources (
  id                text PRIMARY KEY,           -- 'bloomberg', 'ayz', 'semianalysis', etc.
  name              text NOT NULL,              -- 'Bloomberg', 'AYZ'
  description       text NOT NULL,              -- '全球財經新聞領導品牌'
  category          text,                       -- 'financial_news', 'tech_analysis'
  lang              text CHECK (lang ~ '^[a-z]{2}(-[A-Z]{2})?$'),  -- 'en', 'zh-TW', 'zh-CN'
  config            jsonb DEFAULT '{}',        -- 媒體源配置 {"rss_url": "...", "crawl_interval": 300}
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- 2) resources：來源主檔（SSOT）
-- =============================================================================
CREATE TABLE IF NOT EXISTS resources (
  uuid              uuid GENERATED ALWAYS AS (
    uuid_generate_v5(uuid_ns_url(), source_id || ':' || content_header || ':' || to_char(COALESCE(content_time, now()), 'YYYYMM'))
  ) STORED PRIMARY KEY NOT NULL,
  local_src_url     text,                           -- 本地存放路徑
  remote_src_url    text UNIQUE,                    -- 遠端 URL（唯一避免重抓；允許 NULL）
  content_time      timestamptz NOT NULL,                    -- 內容時間（來源聲稱）
  content_header    text NOT NULL,                   -- 內容標題（必填，用於生成 UUID）
  content_authors   jsonb,                          -- 作者陣列 ["author1", "author2"]
  source_id         text NOT NULL REFERENCES media_sources(id), -- 媒體來源參照
  file_type         text,                           -- Changed from ENUM to text
  need_parsed       boolean NOT NULL DEFAULT false,
  crawl_completed   boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  -- 進階去重／校驗
  content_sha256    bytea                           -- 內容雜湊（可空）
);

CREATE INDEX IF NOT EXISTS idx_resources_time         ON resources (content_time);
CREATE INDEX IF NOT EXISTS idx_resources_source       ON resources (source_id);
CREATE INDEX IF NOT EXISTS idx_resources_source_time  ON resources (source_id, content_time DESC);
CREATE INDEX IF NOT EXISTS idx_resources_need_parsed  ON resources (need_parsed);
CREATE INDEX IF NOT EXISTS idx_resources_unparsed     ON resources (source_id) WHERE need_parsed = true;
CREATE INDEX IF NOT EXISTS idx_resources_remote_url   ON resources (remote_src_url) WHERE remote_src_url IS NOT NULL;

DROP TRIGGER IF EXISTS trg_resources_mtime ON resources;
CREATE TRIGGER trg_resources_mtime BEFORE UPDATE ON resources
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 2) parse_settings：解析設定管理
-- =============================================================================
CREATE TABLE IF NOT EXISTS parse_settings (
  id                SERIAL PRIMARY KEY,
  name              text NOT NULL UNIQUE,          -- 'standard_extraction', 'ai_enhanced'
  description       text,                          -- 設定描述
  config            jsonb NOT NULL DEFAULT '{}',   -- 設定參數 {"model": "gpt-4", "chunk_size": 1000}
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_parse_settings_mtime ON parse_settings;
CREATE TRIGGER trg_parse_settings_mtime BEFORE UPDATE ON parse_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 插入預設解析設定
INSERT INTO parse_settings (name, description, config) VALUES 
('standard', '標準解析設定', '{"chunk_size": 1000, "overlap": 200}'),
('ai_enhanced', 'AI 增強解析', '{"model": "gpt-4", "chunk_size": 800, "overlap": 150}')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- 3) chunk_settings：分塊設定管理
-- =============================================================================
CREATE TABLE IF NOT EXISTS chunk_settings (
  id                SERIAL PRIMARY KEY,
  name              text NOT NULL UNIQUE,          -- 'standard_chunking', 'semantic_chunking'
  description       text,                          -- 設定描述
  config            jsonb NOT NULL DEFAULT '{}',   -- 分塊參數 {"chunk_size": 1000, "overlap": 200, "method": "fixed"}
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_chunk_settings_mtime ON chunk_settings;
CREATE TRIGGER trg_chunk_settings_mtime BEFORE UPDATE ON chunk_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 插入預設分塊設定
INSERT INTO chunk_settings (name, description, config) VALUES 
('standard', '標準分塊（固定大小）', '{"chunk_size": 1000, "overlap": 200, "method": "fixed"}'),
('semantic', '語意分塊', '{"method": "semantic", "min_size": 500, "max_size": 1500}'),
('sliding_window', '滑動窗口分塊', '{"chunk_size": 800, "overlap": 400, "method": "sliding_window"}')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- 4) parsed_artifacts：解析產物（每個 resource 可有多組解析設定）
-- =============================================================================
CREATE TABLE IF NOT EXISTS parsed_artifacts (
  uuid              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  local_parsed_url  text,               -- 解析產物存放（JSON/中間檔）
  resource_uuid     uuid NOT NULL REFERENCES resources(uuid) ON DELETE CASCADE,
  source_id         text NOT NULL REFERENCES media_sources(id), -- 媒體來源參照（效能優化）
  parse_setting_id  integer NOT NULL REFERENCES parse_settings(id), -- 解析設定參照
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (resource_uuid, parse_setting_id)
);

CREATE INDEX IF NOT EXISTS idx_parsed_resource ON parsed_artifacts (resource_uuid);
CREATE INDEX IF NOT EXISTS idx_parsed_source ON parsed_artifacts (source_id);

-- Auto-populate source_id for parsed_artifacts
CREATE OR REPLACE FUNCTION set_parsed_source_id() RETURNS trigger AS $
BEGIN
  SELECT source_id INTO NEW.source_id 
  FROM resources 
  WHERE uuid = NEW.resource_uuid;
  RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER trg_parsed_source_id 
BEFORE INSERT ON parsed_artifacts
FOR EACH ROW EXECUTE FUNCTION set_parsed_source_id();

DROP TRIGGER IF EXISTS trg_parsed_mtime ON parsed_artifacts;
CREATE TRIGGER trg_parsed_mtime BEFORE UPDATE ON parsed_artifacts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 3) images：圖片主檔（可屬於某 resource 的圖庫；亦可被 chunk 引用）
-- =============================================================================
CREATE TABLE IF NOT EXISTS images (
  uuid              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  resource_uuid     uuid REFERENCES resources(uuid) ON DELETE SET NULL,
  local_image_url   text,
  remote_image_url  text,
  description       text,
  width             integer,
  height            integer,
  mime_type         text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  image_sha256      bytea,
  UNIQUE (remote_image_url)
);

CREATE INDEX IF NOT EXISTS idx_images_resource ON images (resource_uuid);
CREATE INDEX IF NOT EXISTS idx_images_remote_url ON images (remote_image_url) WHERE remote_image_url IS NOT NULL;

DROP TRIGGER IF EXISTS trg_images_mtime ON images;
CREATE TRIGGER trg_images_mtime BEFORE UPDATE ON images
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 4) chunks：文字分塊（全文 + 向量檢索）
-- =============================================================================
-- 注意：若你的 embedding 維度不同，請調整 vector(1536)
CREATE TABLE IF NOT EXISTS chunks (
  uuid                    uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  resource_uuid           uuid NOT NULL REFERENCES resources(uuid) ON DELETE CASCADE,
  parsed_uuid             uuid REFERENCES parsed_artifacts(uuid) ON DELETE SET NULL,
  image_uuid              uuid REFERENCES images(uuid) ON DELETE SET NULL,
  source_id               text NOT NULL REFERENCES media_sources(id), -- 媒體來源參照（效能優化）

  page                    integer CHECK (page IS NULL OR page >= 0),
  chunk_order             integer NOT NULL CHECK (chunk_order >= 0),
  chunk_setting_id        integer REFERENCES chunk_settings(id), -- 分塊策略參照（可空）
  token_size              integer CHECK (token_size IS NULL OR token_size >= 0),

  chunking_text           text NOT NULL,           -- 分塊文本
  description             text,                    -- 階層描述／LLM 摘要

  -- 產生欄位：全文索引（使用 simple 配置；如需中文斷詞可改 zhparser）
  chunking_text_tsv       tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(chunking_text,''))) STORED,
  description_tsv         tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(description,''))) STORED,

  -- 固定模型向量（單模型情境）
  chunk_embedding         vector(1536),
  description_embedding   vector(1536),

  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),

  UNIQUE (resource_uuid, chunk_order)
);

CREATE INDEX IF NOT EXISTS idx_chunks_resource_order ON chunks (resource_uuid, chunk_order);
CREATE INDEX IF NOT EXISTS idx_chunks_parsed        ON chunks (parsed_uuid);
CREATE INDEX IF NOT EXISTS idx_chunks_page          ON chunks (page);
CREATE INDEX IF NOT EXISTS idx_chunks_source        ON chunks (source_id);
CREATE INDEX IF NOT EXISTS idx_chunks_source_order  ON chunks (source_id, chunk_order);

-- 全文 GIN 索引
CREATE INDEX IF NOT EXISTS idx_chunks_text_gin ON chunks USING GIN (chunking_text_tsv);
CREATE INDEX IF NOT EXISTS idx_chunks_desc_gin ON chunks USING GIN (description_tsv);

-- 向量近鄰索引（IVFFlat；資料量夠再建立，lists 依資料量微調）
-- 若建立時無資料，建完建議 ANALYZE；查詢前可 SET ivfflat.probes
CREATE INDEX IF NOT EXISTS idx_chunks_chunk_emb_ivf ON chunks USING ivfflat (chunk_embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_chunks_desc_emb_ivf  ON chunks USING ivfflat (description_embedding vector_cosine_ops) WITH (lists = 100);

-- Auto-populate source_id for chunks
CREATE OR REPLACE FUNCTION set_chunk_source_id() RETURNS trigger AS $
BEGIN
  SELECT source_id INTO NEW.source_id 
  FROM resources 
  WHERE uuid = NEW.resource_uuid;
  RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER trg_chunk_source_id 
BEFORE INSERT ON chunks
FOR EACH ROW EXECUTE FUNCTION set_chunk_source_id();

DROP TRIGGER IF EXISTS trg_chunks_mtime ON chunks;
CREATE TRIGGER trg_chunks_mtime BEFORE UPDATE ON chunks
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 5) （可選）chunk_embeddings：多模型／多維度向量（彈性擴充）
-- =============================================================================
-- 若同時維護多個向量模型，建議啟用本表，並可忽略 chunks 內的向量欄位
CREATE TABLE IF NOT EXISTS chunk_embeddings (
  chunk_uuid    uuid NOT NULL REFERENCES chunks(uuid) ON DELETE CASCADE,
  kind          text NOT NULL CHECK (kind IN ('chunk','description')), -- 兩類語義
  model         text NOT NULL,       -- 例：'text-embedding-3-large@1536'
  dim           integer NOT NULL,    -- 維度
  embedding     vector,              -- pgvector（可不指定長度；建議同模型維度一致）
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (chunk_uuid, kind, model)
);

CREATE INDEX IF NOT EXISTS idx_ce_chunk_uuid ON chunk_embeddings (chunk_uuid);
CREATE INDEX IF NOT EXISTS idx_ce_model      ON chunk_embeddings (model);

-- 如需近鄰索引，請依常用模型建立「條件式」索引（建議手動挑選模型名）：
-- CREATE INDEX idx_ce_emb_ivf_1536 ON chunk_embeddings
--   USING ivfflat (embedding vector_cosine_ops)
--   WHERE model = 'text-embedding-3-large@1536'
--   WITH (lists = 100);

-- 也可建立 HNSW 索引（pgvector >= 0.7）：
-- CREATE INDEX idx_ce_emb_hnsw_1536 ON chunk_embeddings
--   USING hnsw (embedding vector_cosine_ops)
--   WHERE model = 'text-embedding-3-large@1536';

-- =============================================================================
-- 6) Supabase 權限設定 (Row Level Security)
-- =============================================================================
-- 啟用 RLS
ALTER TABLE media_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE parsed_artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE images ENABLE ROW LEVEL SECURITY;
ALTER TABLE chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE chunk_embeddings ENABLE ROW LEVEL SECURITY;

-- 基本政策：允許認證用戶讀取所有資料
CREATE POLICY IF NOT EXISTS "Allow authenticated users to read media_sources" ON media_sources
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Allow authenticated users to read resources" ON resources
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Allow authenticated users to read parsed_artifacts" ON parsed_artifacts
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Allow authenticated users to read images" ON images
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Allow authenticated users to read chunks" ON chunks
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Allow authenticated users to read chunk_embeddings" ON chunk_embeddings
    FOR SELECT USING (auth.role() = 'authenticated');

-- Service role 完整權限
CREATE POLICY IF NOT EXISTS "Service role full access to media_sources" ON media_sources
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY IF NOT EXISTS "Service role full access to resources" ON resources
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY IF NOT EXISTS "Service role full access to parsed_artifacts" ON parsed_artifacts
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY IF NOT EXISTS "Service role full access to images" ON images
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY IF NOT EXISTS "Service role full access to chunks" ON chunks
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY IF NOT EXISTS "Service role full access to chunk_embeddings" ON chunk_embeddings
    FOR ALL USING (auth.role() = 'service_role');

-- =============================================================================
-- 7) 實用函數
-- =============================================================================

-- 向量搜索函數
CREATE OR REPLACE FUNCTION search_chunks_by_embedding(
    query_embedding vector(1536),
    filter_source_id text DEFAULT NULL,
    match_threshold float DEFAULT 0.8,
    match_count int DEFAULT 10
)
RETURNS TABLE (
    chunk_uuid uuid,
    resource_uuid uuid,
    chunking_text text,
    description text,
    similarity float
)
LANGUAGE sql STABLE
AS $$
    SELECT 
        c.uuid,
        c.resource_uuid,
        c.chunking_text,
        c.description,
        1 - (c.chunk_embedding <=> query_embedding) as similarity
    FROM chunks c
    WHERE c.chunk_embedding IS NOT NULL
        AND 1 - (c.chunk_embedding <=> query_embedding) > match_threshold
        AND (filter_source_id IS NULL OR c.source_id = filter_source_id)
    ORDER BY c.chunk_embedding <=> query_embedding
    LIMIT match_count;
$$;

-- 全文搜索函數
CREATE OR REPLACE FUNCTION search_chunks_by_text(
    search_query text,
    filter_source_id text DEFAULT NULL,
    match_count int DEFAULT 10
)
RETURNS TABLE (
    chunk_uuid uuid,
    resource_uuid uuid,
    chunking_text text,
    description text,
    rank float
)
LANGUAGE sql STABLE
AS $$
    SELECT 
        c.uuid,
        c.resource_uuid,
        c.chunking_text,
        c.description,
        ts_rank(c.chunking_text_tsv, websearch_to_tsquery('simple', search_query)) as rank
    FROM chunks c
    WHERE c.chunking_text_tsv @@ websearch_to_tsquery('simple', search_query)
        AND (filter_source_id IS NULL OR c.source_id = filter_source_id)
    ORDER BY rank DESC
    LIMIT match_count;
$$;

-- 混合搜索函數（全文 + 向量）
CREATE OR REPLACE FUNCTION hybrid_search_chunks(
    search_query text,
    query_embedding vector(1536),
    filter_source_id text DEFAULT NULL,
    text_weight float DEFAULT 0.5,
    vector_weight float DEFAULT 0.5,
    match_count int DEFAULT 10
)
RETURNS TABLE (
    chunk_uuid uuid,
    resource_uuid uuid,
    chunking_text text,
    description text,
    combined_score float
)
LANGUAGE sql STABLE
AS $$
    WITH text_search AS (
        SELECT 
            c.uuid,
            c.resource_uuid,
            c.chunking_text,
            c.description,
            ts_rank(c.chunking_text_tsv, websearch_to_tsquery('simple', search_query)) as text_score
        FROM chunks c
        WHERE c.chunking_text_tsv @@ websearch_to_tsquery('simple', search_query)
            AND (filter_source_id IS NULL OR c.source_id = filter_source_id)
    ),
    vector_search AS (
        SELECT 
            c.uuid,
            c.resource_uuid,
            c.chunking_text,
            c.description,
            1 - (c.chunk_embedding <=> query_embedding) as vector_score
        FROM chunks c
        WHERE c.chunk_embedding IS NOT NULL
            AND (filter_source_id IS NULL OR c.source_id = filter_source_id)
    )
    SELECT 
        COALESCE(t.uuid, v.uuid) as chunk_uuid,
        COALESCE(t.resource_uuid, v.resource_uuid) as resource_uuid,
        COALESCE(t.chunking_text, v.chunking_text) as chunking_text,
        COALESCE(t.description, v.description) as description,
        (COALESCE(t.text_score, 0) * text_weight + 
         COALESCE(v.vector_score, 0) * vector_weight) as combined_score
    FROM text_search t
    FULL OUTER JOIN vector_search v ON t.uuid = v.uuid
    ORDER BY combined_score DESC
    LIMIT match_count;
$$;

-- =============================================================================
-- 8) 創建基本索引優化
-- =============================================================================

-- =============================================================================
-- 7.1) 統計資訊 Materialized View
-- =============================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS media_source_stats AS
SELECT 
    ms.id,
    ms.name,
    ms.category,
    ms.lang,
    COUNT(DISTINCT r.uuid) as resource_count,
    COUNT(DISTINCT p.uuid) as parsed_count,
    COUNT(DISTINCT c.uuid) as chunk_count,
    MAX(r.content_time) as latest_content,
    MAX(r.created_at) as last_crawl,
    COUNT(DISTINCT r.uuid) FILTER (WHERE r.need_parsed = true) as unparsed_count
FROM media_sources ms
LEFT JOIN resources r ON r.source_id = ms.id
LEFT JOIN parsed_artifacts p ON p.source_id = ms.id
LEFT JOIN chunks c ON c.source_id = ms.id
GROUP BY ms.id, ms.name, ms.category, ms.lang;

-- 為統計視圖建立唯一索引
CREATE UNIQUE INDEX IF NOT EXISTS idx_media_source_stats_id ON media_source_stats(id);

-- 建立刷新函數
CREATE OR REPLACE FUNCTION refresh_media_source_stats() RETURNS void AS $
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY media_source_stats;
END;
$ LANGUAGE plpgsql;

-- 分析表格以優化查詢計劃
ANALYZE resources;
ANALYZE parsed_artifacts;
ANALYZE images;
ANALYZE chunks;
ANALYZE chunk_embeddings;
ANALYZE media_source_stats;

-- =============================================================================
-- 完成
-- =============================================================================

-- 插入一些範例資料（可選）
DO $$
BEGIN
    -- 插入範例 resource
    INSERT INTO resources (
        uuid, 
        remote_src_url, 
        content_header, 
        src_name, 
        src_category, 
        file_type
    ) VALUES (
        '12345678-1234-5678-9012-123456789012',
        'https://example.com/sample-article',
        'Sample Article for Testing',
        'Example News',
        'news',
        'html'
    ) ON CONFLICT (remote_src_url) DO NOTHING;
    
    -- 插入範例 chunk
    INSERT INTO chunks (
        resource_uuid,
        chunk_order,
        chunking_text,
        description
    ) VALUES (
        '12345678-1234-5678-9012-123456789012',
        1,
        'This is a sample chunk for testing the RAG system.',
        'Sample chunk description'
    ) ON CONFLICT (resource_uuid, chunk_order) DO NOTHING;
    
EXCEPTION
    WHEN OTHERS THEN
        -- 忽略範例資料插入錯誤
        NULL;
END$$;

NOTIFY pgrst, 'reload schema';

-- 完成訊息
DO $$
BEGIN
    RAISE NOTICE '✅ RAG Schema initialization completed successfully!';
    RAISE NOTICE '📊 Tables created: resources, parsed_artifacts, images, chunks, chunk_embeddings';
    RAISE NOTICE '🔍 Search functions available: search_chunks_by_embedding, search_chunks_by_text, hybrid_search_chunks';
    RAISE NOTICE '🔒 Row Level Security enabled with basic policies';
END$$;