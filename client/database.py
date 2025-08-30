"""
SQLAlchemy 資料庫模型和管理器

定義 RAG 系統的所有資料庫模型，並提供統一的資料庫操作介面。
"""

from typing import Optional, List, Dict, Any, Union
from sqlalchemy import Column, String, Text, DateTime, Integer, Boolean, Enum, LargeBinary, CheckConstraint, UniqueConstraint, Index
from sqlalchemy.dialects.postgresql import UUID, TSVECTOR
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


class Resource(Base):
    """資源主檔表"""
    __tablename__ = 'resources'
    
    uuid = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    local_src_url = Column(Text)
    remote_src_url = Column(Text, unique=True)
    content_time = Column(DateTime(timezone=True))
    content_header = Column(Text)
    content_authors = Column(Text)
    src_name = Column(Text)
    src_description = Column(Text)
    src_category = Column(Text)
    file_type = Column(Text)
    need_parsed = Column(Boolean, nullable=False, default=False)
    crawl_completed = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, default=func.now(), onupdate=func.now())
    content_sha256 = Column(LargeBinary)
    lang = Column(Text)
    
    # 關聯
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
            'src_name': self.src_name,
            'src_description': self.src_description,
            'src_category': self.src_category,
            'file_type': self.file_type,
            'need_parsed': self.need_parsed,
            'crawl_completed': self.crawl_completed,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'lang': self.lang
        }


class ParsedArtifact(Base):
    """解析產物表"""
    __tablename__ = 'parsed_artifacts'
    
    uuid = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    resource_uuid = Column(UUID(as_uuid=True), nullable=False)
    local_parsed_url = Column(Text)
    parse_setting = Column(Integer, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, default=func.now(), onupdate=func.now())
    
    # 關聯
    resource = relationship("Resource", back_populates="parsed_artifacts")
    chunks = relationship("Chunk", back_populates="parsed_artifact")
    
    __table_args__ = (
        UniqueConstraint('resource_uuid', 'parse_setting', name='uq_resource_parse_setting'),
    )


class Image(Base):
    """圖片表"""
    __tablename__ = 'images'
    
    uuid = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    resource_uuid = Column(UUID(as_uuid=True))
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
    resource_uuid = Column(UUID(as_uuid=True), nullable=False)
    parsed_uuid = Column(UUID(as_uuid=True))
    image_uuid = Column(UUID(as_uuid=True))
    page = Column(Integer, CheckConstraint('page IS NULL OR page >= 0'))
    chunk_order = Column(Integer, CheckConstraint('chunk_order >= 0'), nullable=False)
    chunk_setting = Column(Integer)
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
            'chunk_setting': self.chunk_setting,
            'token_size': self.token_size,
            'chunking_text': self.chunking_text,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class ChunkEmbedding(Base):
    """分塊嵌入向量表（多模型支援）"""
    __tablename__ = 'chunk_embeddings'
    
    chunk_uuid = Column(UUID(as_uuid=True), nullable=False, primary_key=True)
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
    
    def get_resources_by_category(self, category: str, 
                                limit: int = 100) -> List[Resource]:
        """根據分類取得資源"""
        return self.session.query(Resource).filter_by(src_category=category).limit(limit).all()
    
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
        
        # 按分類統計
        category_stats = {}
        categories = self.session.query(Resource.src_category).distinct().filter(Resource.src_category.isnot(None)).all()
        for category_row in categories:
            category = category_row[0]
            count = self.session.query(Resource).filter_by(src_category=category).count()
            if count > 0:
                category_stats[category] = count
        
        stats['by_category'] = category_stats
        
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