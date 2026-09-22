-- =============================================================================
-- init/postgres/01_extensions.sql
-- Automatically executed by PostgreSQL on first container startup.
-- Enables the pgvector extension in the tugboat database.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS vector;
