-- Schema updates for likes and reposts functionality

-- 1. Add like_count column to posts table (defaults to 0)
ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS like_count INTEGER DEFAULT 0 NOT NULL;

-- 2. Create likes table to track individual user likes (for preventing duplicates and checking if user liked)
CREATE TABLE IF NOT EXISTS post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES user_info(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT post_likes_unique UNIQUE(post_id, user_id) -- Prevent duplicate likes
);

-- Ensure the unique constraint exists (in case table already exists)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'post_likes_unique'
    ) THEN
        ALTER TABLE post_likes ADD CONSTRAINT post_likes_unique UNIQUE(post_id, user_id);
    END IF;
END $$;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);

-- 3. Add reposted_post_id column to posts table for reposts
ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS reposted_post_id UUID REFERENCES posts(post_id) ON DELETE SET NULL;

-- Create index for repost queries
CREATE INDEX IF NOT EXISTS idx_posts_reposted_post_id ON posts(reposted_post_id);

-- 4. Add repost_count column to posts (defaults to 0)
ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS repost_count INTEGER DEFAULT 0 NOT NULL;
