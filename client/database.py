"""
SQLAlchemy 資料庫模型和管理器

定義 RAG 系統的所有資料庫模型，並提供統一的資料庫操作介面。
"""

from typing import Optional, List, Dict, Any, Union
from sqlalchemy import Column, String, Text, DateTime, Integer, Boolean, Enum, LargeBinary, CheckConstraint, UniqueConstraint, Index, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, TSVECTOR, JSONB
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Session, relationship
from sqlalchemy.sql import func
from pgvector.sqlalchemy import Vector
import uuid
import json
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

# 建立基礎類別
Base = declarative_base()

# ENUM 類型定義
import enum

# Note: Removed ResourceFileType and SrcCategory enums in favor of flexible text types

class MediaSource(Base):
    """媒體來源主檔表"""
    __tablename__ = 'media_sources'
    
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=False)
    category = Column(Text)
    lang = Column(Text, CheckConstraint("lang ~ '^[a-z]{2}(-[A-Z]{2})?$'"))
    config = Column(JSONB, default={})
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    
    # 關聯
    resources = relationship("Resource", back_populates="media_source")
    
    def to_dict(self) -> Dict[str, Any]:
        """轉換為字典"""
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'category': self.category,
            'lang': self.lang,
            'config': self.config,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class ParseSetting(Base):
    """解析設定管理表"""
    __tablename__ = 'parse_settings'
    
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False, unique=True)
    description = Column(Text)
    config = Column(JSONB, nullable=False, default={})
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, default=func.now(), onupdate=func.now())
    
    # 關聯
    parsed_artifacts = relationship("ParsedArtifact", back_populates="parse_setting")


class ChunkSetting(Base):
    """分塊設定管理表"""
    __tablename__ = 'chunk_settings'
    
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False, unique=True)
    description = Column(Text)
    config = Column(JSONB, nullable=False, default={})
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, default=func.now(), onupdate=func.now())
    
    # 關聯
    chunks = relationship("Chunk", back_populates="chunk_setting")


class Resource(Base):
    """資源主檔表"""
    __tablename__ = 'resources'
    
    # 注意：這裡使用 generated UUID，實際應用中可能需要特殊處理
    uuid = Column(UUID(as_uuid=True), primary_key=True)
    local_src_url = Column(Text)
    remote_src_url = Column(Text, unique=True)
    content_time = Column(DateTime(timezone=True), nullable=False)
    content_header = Column(Text, nullable=False)
    content_authors = Column(JSONB)
    source_id = Column(String, ForeignKey('media_sources.id'), nullable=False)
    file_type = Column(Text)
    need_parsed = Column(Boolean, nullable=False, default=False)
    crawl_completed = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, default=func.now(), onupdate=func.now())
    content_sha256 = Column(LargeBinary)
    
    # 關聯
    media_source = relationship("MediaSource", back_populates="resources")
    parsed_artifacts = relationship("ParsedArtifact", back_populates="resource", cascade="all, delete-orphan")
    images = relationship("Image", back_populates="resource")
    chunks = relationship("Chunk", back_populates="resource", cascade="all, delete-orphan")
    
    def to_dict(self) -> Dict[str, Any]:
        """轉換為字典"""
        return {
            'uuid': str(self.uuid),
            'local_src_url': self.local_src_url,
            'remote_src_url': self.remote_src_url,
            'content_time': self.content_time.isoformat() if self.content_time else None,
            'content_header': self.content_header,
            'content_authors': self.content_authors,
            'source_id': self.source_id,
            'file_type': self.file_type,
            'need_parsed': self.need_parsed,
            'crawl_completed': self.crawl_completed,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class ParsedArtifact(Base):
    """解析產物表"""
    __tablename__ = 'parsed_artifacts'
    
    uuid = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    resource_uuid = Column(UUID(as_uuid=True), ForeignKey('resources.uuid', ondelete='CASCADE'), nullable=False)
    source_id = Column(String, ForeignKey('media_sources.id'), nullable=False)
    local_parsed_url = Column(Text)
    parse_setting_id = Column(Integer, ForeignKey('parse_settings.id'), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, default=func.now(), onupdate=func.now())
    
    # 關聯
    resource = relationship("Resource", back_populates="parsed_artifacts")
    parse_setting = relationship("ParseSetting", back_populates="parsed_artifacts")
    chunks = relationship("Chunk", back_populates="parsed_artifact")
    
    __table_args__ = (
        UniqueConstraint('resource_uuid', 'parse_setting_id', name='uq_resource_parse_setting'),
    )


class Image(Base):
    """圖片表"""
    __tablename__ = 'images'
    
    uuid = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    resource_uuid = Column(UUID(as_uuid=True), ForeignKey('resources.uuid', ondelete='SET NULL'))
    local_image_url = Column(Text)
    remote_image_url = Column(Text, unique=True)
    description = Column(Text)
    width = Column(Integer)
    height = Column(Integer)
    mime_type = Column(Text)
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, default=func.now(), onupdate=func.now())
    image_sha256 = Column(LargeBinary)
    
    # 關聯
    resource = relationship("Resource", back_populates="images")
    chunks = relationship("Chunk", back_populates="image")


class Chunk(Base):
    """文字分塊表"""
    __tablename__ = 'chunks'
    
    uuid = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    resource_uuid = Column(UUID(as_uuid=True), ForeignKey('resources.uuid', ondelete='CASCADE'), nullable=False)
    parsed_uuid = Column(UUID(as_uuid=True), ForeignKey('parsed_artifacts.uuid', ondelete='SET NULL'))
    image_uuid = Column(UUID(as_uuid=True), ForeignKey('images.uuid', ondelete='SET NULL'))
    source_id = Column(String, ForeignKey('media_sources.id'), nullable=False)
    page = Column(Integer, CheckConstraint('page IS NULL OR page >= 0'))
    chunk_order = Column(Integer, CheckConstraint('chunk_order >= 0'), nullable=False)
    chunk_setting_id = Column(Integer, ForeignKey('chunk_settings.id'))
    token_size = Column(Integer, CheckConstraint('token_size IS NULL OR token_size >= 0'))
    chunking_text = Column(Text, nullable=False)
    description = Column(Text)
    
    # 全文搜索向量（自動生成）
    chunking_text_tsv = Column(TSVECTOR)
    description_tsv = Column(TSVECTOR)
    
    # 向量嵌入
    chunk_embedding = Column(Vector(1536))
    description_embedding = Column(Vector(1536))
    
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, default=func.now(), onupdate=func.now())
    
    # 關聯
    resource = relationship("Resource", back_populates="chunks")
    parsed_artifact = relationship("ParsedArtifact", back_populates="chunks")
    image = relationship("Image", back_populates="chunks")
    chunk_setting = relationship("ChunkSetting", back_populates="chunks")
    embeddings = relationship("ChunkEmbedding", back_populates="chunk", cascade="all, delete-orphan")
    
    __table_args__ = (
        UniqueConstraint('resource_uuid', 'chunk_order', name='uq_resource_chunk_order'),
        Index('idx_chunks_resource_order', 'resource_uuid', 'chunk_order'),
        Index('idx_chunks_text_gin', 'chunking_text_tsv', postgresql_using='gin'),
        Index('idx_chunks_desc_gin', 'description_tsv', postgresql_using='gin'),
        Index('idx_chunks_chunk_emb_ivf', 'chunk_embedding', postgresql_using='ivfflat', 
              postgresql_ops={'chunk_embedding': 'vector_cosine_ops'}),
        Index('idx_chunks_desc_emb_ivf', 'description_embedding', postgresql_using='ivfflat',
              postgresql_ops={'description_embedding': 'vector_cosine_ops'}),
    )
    
    def to_dict(self) -> Dict[str, Any]:
        """轉換為字典"""
        return {
            'uuid': str(self.uuid),
            'resource_uuid': str(self.resource_uuid),
            'parsed_uuid': str(self.parsed_uuid) if self.parsed_uuid else None,
            'image_uuid': str(self.image_uuid) if self.image_uuid else None,
            'page': self.page,
            'chunk_order': self.chunk_order,
            'chunk_setting_id': self.chunk_setting_id,
            'token_size': self.token_size,
            'chunking_text': self.chunking_text,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class ChunkEmbedding(Base):
    """分塊嵌入向量表（多模型支援）"""
    __tablename__ = 'chunk_embeddings'
    
    chunk_uuid = Column(UUID(as_uuid=True), ForeignKey('chunks.uuid', ondelete='CASCADE'), nullable=False, primary_key=True)
    kind = Column(String, CheckConstraint("kind IN ('chunk', 'description')"), nullable=False, primary_key=True)
    model = Column(String, nullable=False, primary_key=True)
    dim = Column(Integer, nullable=False)
    embedding = Column(Vector)
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    
    # 關聯
    chunk = relationship("Chunk", back_populates="embeddings")


class DatabaseManager:
    """資料庫管理器"""
    
    def __init__(self, session: Session):
        """
        初始化資料庫管理器
        
        Args:
            session: SQLAlchemy Session 實例
        """
        self.session = session
    
    def create_resource(self, **kwargs) -> Resource:
        """創建資源"""
        # Note: Removed enum conversion logic - src_category and file_type are now text fields
        
        resource = Resource(**kwargs)
        self.session.add(resource)
        self.session.commit()
        self.session.refresh(resource)
        
        logger.info(f"Created resource: {resource.uuid}")
        return resource
    
    def get_resource(self, resource_uuid: Union[str, uuid.UUID]) -> Optional[Resource]:
        """取得資源"""
        if isinstance(resource_uuid, str):
            resource_uuid = uuid.UUID(resource_uuid)
        
        return self.session.query(Resource).filter_by(uuid=resource_uuid).first()
    
    def get_resources_by_url(self, remote_url: str) -> Optional[Resource]:
        """根據 URL 取得資源"""
        return self.session.query(Resource).filter_by(remote_src_url=remote_url).first()
    
    def get_resources_by_source(self, source_id: str, 
                                limit: int = 100) -> List[Resource]:
        """根據來源取得資源"""
        return self.session.query(Resource).filter_by(source_id=source_id).limit(limit).all()
    
    def update_resource(self, resource_uuid: Union[str, uuid.UUID], **kwargs) -> Optional[Resource]:
        """更新資源"""
        resource = self.get_resource(resource_uuid)
        if not resource:
            return None
        
        # Note: Removed enum conversion logic - src_category and file_type are now text fields
        
        for key, value in kwargs.items():
            if hasattr(resource, key):
                setattr(resource, key, value)
        
        self.session.commit()
        self.session.refresh(resource)
        
        logger.info(f"Updated resource: {resource.uuid}")
        return resource
    
    def create_chunk(self, **kwargs) -> Chunk:
        """創建分塊"""
        chunk = Chunk(**kwargs)
        self.session.add(chunk)
        self.session.commit()
        self.session.refresh(chunk)
        
        logger.info(f"Created chunk: {chunk.uuid}")
        return chunk
    
    def get_chunks_by_resource(self, resource_uuid: Union[str, uuid.UUID],
                              limit: int = 100) -> List[Chunk]:
        """取得資源的所有分塊"""
        if isinstance(resource_uuid, str):
            resource_uuid = uuid.UUID(resource_uuid)
        
        return (self.session.query(Chunk)
                .filter_by(resource_uuid=resource_uuid)
                .order_by(Chunk.chunk_order)
                .limit(limit)
                .all())
    
    def search_chunks_by_text(self, query: str, limit: int = 10) -> List[Chunk]:
        """全文搜索分塊"""
        return (self.session.query(Chunk)
                .filter(Chunk.chunking_text_tsv.op('@@')(func.websearch_to_tsquery('simple', query)))
                .order_by(func.ts_rank(Chunk.chunking_text_tsv, func.websearch_to_tsquery('simple', query)).desc())
                .limit(limit)
                .all())
    
    def search_chunks_by_embedding(self, embedding: List[float], 
                                  threshold: float = 0.8, limit: int = 10) -> List[Dict[str, Any]]:
        """向量搜索分塊"""
        # 使用原始 SQL 查詢以支援向量操作
        query = """
        SELECT 
            uuid,
            resource_uuid,
            chunking_text,
            description,
            1 - (chunk_embedding <=> :embedding) as similarity
        FROM chunks
        WHERE chunk_embedding IS NOT NULL
            AND 1 - (chunk_embedding <=> :embedding) > :threshold
        ORDER BY chunk_embedding <=> :embedding
        LIMIT :limit
        """
        
        result = self.session.execute(query, {
            'embedding': str(embedding),
            'threshold': threshold,
            'limit': limit
        })
        
        return [dict(row) for row in result]
    
    def hybrid_search_chunks(self, text_query: str, embedding: List[float],
                           text_weight: float = 0.5, vector_weight: float = 0.5,
                           limit: int = 10) -> List[Dict[str, Any]]:
        """混合搜索（全文 + 向量）"""
        query = """
        WITH text_search AS (
            SELECT 
                uuid,
                resource_uuid,
                chunking_text,
                description,
                ts_rank(chunking_text_tsv, websearch_to_tsquery('simple', :text_query)) as text_score
            FROM chunks
            WHERE chunking_text_tsv @@ websearch_to_tsquery('simple', :text_query)
        ),
        vector_search AS (
            SELECT 
                uuid,
                resource_uuid,
                chunking_text,
                description,
                1 - (chunk_embedding <=> :embedding) as vector_score
            FROM chunks
            WHERE chunk_embedding IS NOT NULL
        )
        SELECT 
            COALESCE(t.uuid, v.uuid) as uuid,
            COALESCE(t.resource_uuid, v.resource_uuid) as resource_uuid,
            COALESCE(t.chunking_text, v.chunking_text) as chunking_text,
            COALESCE(t.description, v.description) as description,
            (COALESCE(t.text_score, 0) * :text_weight + 
             COALESCE(v.vector_score, 0) * :vector_weight) as combined_score
        FROM text_search t
        FULL OUTER JOIN vector_search v ON t.uuid = v.uuid
        ORDER BY combined_score DESC
        LIMIT :limit
        """
        
        result = self.session.execute(query, {
            'text_query': text_query,
            'embedding': str(embedding),
            'text_weight': text_weight,
            'vector_weight': vector_weight,
            'limit': limit
        })
        
        return [dict(row) for row in result]
    
    def get_statistics(self) -> Dict[str, int]:
        """取得資料庫統計資訊"""
        stats = {}
        
        stats['resources_count'] = self.session.query(Resource).count()
        stats['chunks_count'] = self.session.query(Chunk).count()
        stats['images_count'] = self.session.query(Image).count()
        stats['parsed_artifacts_count'] = self.session.query(ParsedArtifact).count()
        
        # 按來源統計
        source_stats = {}
        sources = self.session.query(Resource.source_id).distinct().filter(Resource.source_id.isnot(None)).all()
        for source_row in sources:
            source = source_row[0]
            count = self.session.query(Resource).filter_by(source_id=source).count()
            if count > 0:
                source_stats[source] = count
        
        stats['by_source'] = source_stats
        
        return stats
    
    def close(self):
        """關閉 session"""
        self.session.close()
    
    def __enter__(self):
        """支援 context manager"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """支援 context manager"""
        if exc_type:
            self.session.rollback()
        self.close()


def get_db_session() -> Session:
    """取得資料庫 Session（需要從 config 模組引入）"""
    from .config import get_config
    return get_config().create_session()

def create_database_manager(session: Optional[Session] = None) -> DatabaseManager:
    """創建資料庫管理器"""
    if session is None:
        session = get_db_session()
    
    return DatabaseManager(session)