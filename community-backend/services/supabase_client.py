"""
Supabase client wrapper for community feature operations.

This module provides access to the unified SupabaseClient from main-backend,
configured with community-backend's settings.
"""
import logging
from typing import Any, Dict, List, Optional
from config import get_config
from supabase import create_client, Client

# Global client instance - initialized at app startup
_community_client: Optional["CommunitySupabaseClient"] = None
logger = logging.getLogger(__name__)


def initialize_community_client() -> "CommunitySupabaseClient":
    """
    Initialize the Supabase client at application startup.
    
    This should be called once during FastAPI lifespan startup.
    Avoids lazy initialization race conditions and redundant client creation.
    
    Returns:
        SupabaseClient instance configured with community-backend's settings
    """
    global _community_client
    config = get_config()
    try:
        supabase = create_client(config.SUPABASE_URL, config.SUPABASE_SERVICE_ROLE_KEY)
        _community_client = CommunitySupabaseClient(supabase)
        logger.info("✅ Supabase client initialized at startup")
        return _community_client
    except Exception as e:
        logger.error(f"❌ Failed to initialize Supabase client: {e}")
        raise


def get_community_client() -> "CommunitySupabaseClient":
    """
    Get the community Supabase client instance.
    
    IMPORTANT: Call initialize_community_client() at app startup before using this.
    
    Returns:
        CommunitySupabaseClient instance
        
    Raises:
        RuntimeError: If client was not initialized at startup
    """
    if _community_client is None:
        raise RuntimeError(
            "Supabase client not initialized. "
            "Call initialize_community_client() during app startup (in lifespan)."
        )
    return _community_client


class CommunitySupabaseClient:
    """
    Handles all Supabase operations for the community feature.
    
    Tables:
    - subthreads: Community topics/categories
    - posts: User posts within subthreads
    - comments: Comments on posts (supports nesting)
    """
    
    def __init__(self, supabase_client: Client):
        """
        Initialize with an existing Supabase client.
        
        Args:
            supabase_client: Authenticated Supabase client instance
        """
        self._client = supabase_client
    
    # ========== Subthread Operations ==========
    
    def create_subthread(
        self,
        name: str,
        description: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Create a new subthread.
        
        Args:
            name: Unique name for the subthread
            description: Optional description
            
        Returns:
            Created subthread data or None on failure
        """
        try:
            payload = {
                "name": name,
                "description": description,
            }
            resp = self._client.table("subthreads").insert(payload).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                logger.info(f"Created subthread: {name}")
                return data[0]
            return None
        except Exception as exc:
            logger.exception(f"Failed to create subthread {name}: {exc}")
            return None
    
    def get_subthread_by_id(self, subthread_id: str) -> Optional[Dict[str, Any]]:
        """Get subthread by ID."""
        try:
            resp = self._client.table("subthreads").select("*").eq("id", subthread_id).limit(1).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                return data[0]
            return None
        except Exception as exc:
            logger.exception(f"Failed to get subthread {subthread_id}: {exc}")
            return None
    
    def get_subthread_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Get subthread by name."""
        try:
            resp = self._client.table("subthreads").select("*").eq("name", name).limit(1).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                return data[0]
            return None
        except Exception as exc:
            logger.exception(f"Failed to get subthread by name {name}: {exc}")
            return None
    
    def list_subthreads(self, limit: int = 50) -> List[Dict[str, Any]]:
        """List all subthreads."""
        try:
            resp = self._client.table("subthreads").select("*").order("created_at", desc=True).limit(limit).execute()
            data = getattr(resp, "data", None)
            return data if isinstance(data, list) else []
        except Exception as exc:
            logger.exception(f"Failed to list subthreads: {exc}")
            return []
    
    def delete_subthread(self, subthread_id: str) -> bool:
        """
        Delete a subthread and all its posts (and comments via CASCADE).
        
        Args:
            subthread_id: UUID of the subthread to delete
            
        Returns:
            True if deleted successfully, False otherwise
        """
        try:
            # Verify the subthread exists
            subthread = self.get_subthread_by_id(subthread_id)
            if not subthread:
                logger.warning(f"Subthread {subthread_id} not found")
                return False
            
            # Delete the subthread (CASCADE will handle posts and their comments)
            resp = self._client.table("subthreads").delete().eq("id", subthread_id).execute()
            data = getattr(resp, "data", None)
            
            if isinstance(data, list) and data:
                logger.info(f"Deleted subthread {subthread_id} and all associated posts/comments")
                return True
            
            return False
        except Exception as exc:
            logger.exception(f"Failed to delete subthread {subthread_id}: {exc}")
            return False
    
    # ========== Post Operations ==========
    
    def create_post(
        self,
        user_id: str,
        subthread_id: str,
        title: str,
        content: str,
        reposted_post_id: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Create a new post.
        
        Args:
            user_id: UUID of the author
            subthread_id: UUID of the subthread
            title: Post title
            content: Post content
            reposted_post_id: Optional UUID of the original post (for reposts)
            
        Returns:
            Created post data or None on failure
        """
        try:
            payload = {
                "user_id": user_id,
                "subthread_id": subthread_id,
                "title": title,
                "content": content,
            }
            if reposted_post_id:
                payload["reposted_post_id"] = reposted_post_id
            
            resp = self._client.table("posts").insert(payload).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                logger.info(f"Created post by user {user_id}")
                return data[0]
            return None
        except Exception as exc:
            logger.exception(f"Failed to create post: {exc}")
            return None
    
    def get_post_by_id(
        self, 
        post_id: str, 
        current_user_id: Optional[str] = None,
        include_reposted_post: bool = True
    ) -> Optional[Dict[str, Any]]:
        """
        Get post by ID with author information, like counts, and reposted post.
        
        Args:
            post_id: UUID of the post
            current_user_id: Optional UUID of current user for like/repost status
            include_reposted_post: If True, recursively fetch reposted_post (one level only)
        """
        try:
            resp = self._client.table("posts").select(
                "*, user_info!posts_user_id_fkey(email, first_name, last_name)"
            ).eq("post_id", post_id).limit(1).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                post = data[0]
                # Flatten author info
                if "user_info" in post and post["user_info"]:
                    author = post.pop("user_info")
                    post["author_email"] = author.get("email")
                    post["author_first_name"] = author.get("first_name")
                    post["author_last_name"] = author.get("last_name")
                
                # Get like_count, repost_count, reply_count
                post["like_count"] = post.get("like_count", 0) or 0
                post["repost_count"] = post.get("repost_count", 0) or 0
                post["reply_count"] = self.count_comments_by_post(post_id)
                
                # Check if user liked/reposted this post
                if current_user_id:
                    post["liked_by_current_user"] = self.is_post_liked_by_user(
                        post_id, current_user_id
                    )
                    post["reposted_by_current_user"] = self.is_post_reposted_by_user(
                        post_id, current_user_id
                    )
                else:
                    post["liked_by_current_user"] = False
                    post["reposted_by_current_user"] = False
                
                # If this is a repost, get the original post (without its reposted_post to avoid infinite recursion)
                if include_reposted_post:
                    reposted_post_id = post.get("reposted_post_id")
                    if reposted_post_id:
                        original_post = self.get_post_by_id(
                            reposted_post_id, current_user_id, include_reposted_post=False
                        )
                        if original_post:
                            post["reposted_post"] = original_post
                
                return post
            return None
        except Exception as exc:
            logger.exception(f"Failed to get post {post_id}: {exc}")
            return None

    def get_posts_by_ids(
        self,
        post_ids: List[str],
        current_user_id: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """Fetch multiple posts by ID with author info and counts (one query + batch lookups)."""
        if not post_ids:
            return []
        try:
            resp = self._client.table("posts").select(
                "*, user_info!posts_user_id_fkey(email, first_name, last_name)"
            ).in_("post_id", post_ids).execute()
            data = getattr(resp, "data", None)
            if not isinstance(data, list):
                return []
            reply_counts = self.get_comment_counts_for_posts(post_ids)
            liked_set = self.get_liked_post_ids_for_user(current_user_id, post_ids) if current_user_id else set()
            reposted_set = self.get_reposted_post_ids_for_user(current_user_id, post_ids) if current_user_id else set()
            enriched = []
            for post in data:
                if "user_info" in post and post["user_info"]:
                    author = post.pop("user_info")
                    post["author_email"] = author.get("email")
                    post["author_first_name"] = author.get("first_name")
                    post["author_last_name"] = author.get("last_name")
                pid = post.get("post_id")
                if pid:
                    post["like_count"] = post.get("like_count", 0) or 0
                    post["repost_count"] = post.get("repost_count", 0) or 0
                    post["reply_count"] = reply_counts.get(pid, 0)
                    post["liked_by_current_user"] = pid in liked_set if current_user_id else False
                    post["reposted_by_current_user"] = pid in reposted_set if current_user_id else False
                enriched.append(post)
            return enriched
        except Exception as exc:
            logger.exception(f"Failed to get posts by ids: {exc}")
            return []

    def list_posts_by_subthread(
        self,
        subthread_id: str,
        limit: int = 20,
        offset: int = 0,
        current_user_id: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """List posts in a subthread with author info, counts, and reposted posts (batched to avoid timeout)."""
        try:
            resp = self._client.table("posts").select(
                "*, user_info!posts_user_id_fkey(email, first_name, last_name)"
            ).eq("subthread_id", subthread_id).order("created_at", desc=True).range(offset, offset + limit - 1).execute()
            data = getattr(resp, "data", None)
            if not isinstance(data, list):
                return []
            post_ids = [p["post_id"] for p in data if p.get("post_id")]
            if not post_ids:
                return []
            # One batch for comment counts, liked, reposted
            reply_counts = self.get_comment_counts_for_posts(post_ids)
            liked_set = self.get_liked_post_ids_for_user(current_user_id, post_ids) if current_user_id else set()
            reposted_set = self.get_reposted_post_ids_for_user(current_user_id, post_ids) if current_user_id else set()
            # One batch for all reposted originals
            reposted_ids = list({p["reposted_post_id"] for p in data if p.get("reposted_post_id")})
            originals_map = {}
            if reposted_ids:
                originals_list = self.get_posts_by_ids(reposted_ids, current_user_id)
                originals_map = {p["post_id"]: p for p in originals_list}
            enriched_posts = []
            for post in data:
                if "user_info" in post and post["user_info"]:
                    author = post.pop("user_info")
                    post["author_email"] = author.get("email")
                    post["author_first_name"] = author.get("first_name")
                    post["author_last_name"] = author.get("last_name")
                post_id = post.get("post_id")
                if post_id:
                    post["like_count"] = post.get("like_count", 0) or 0
                    post["repost_count"] = post.get("repost_count", 0) or 0
                    post["reply_count"] = reply_counts.get(post_id, 0)
                    post["liked_by_current_user"] = post_id in liked_set if current_user_id else False
                    post["reposted_by_current_user"] = post_id in reposted_set if current_user_id else False
                    rid = post.get("reposted_post_id")
                    if rid and rid in originals_map:
                        post["reposted_post"] = originals_map[rid]
                enriched_posts.append(post)
            return enriched_posts
        except Exception as exc:
            logger.exception(f"Failed to list posts for subthread {subthread_id}: {exc}")
            return []
    
    def count_posts_by_subthread(self, subthread_id: str) -> int:
        """Count total posts in a subthread."""
        try:
            from postgrest import CountMethod
            resp = self._client.table("posts").select("post_id", count=CountMethod.exact).eq("subthread_id", subthread_id).execute()
            return getattr(resp, "count", 0) or 0
        except Exception as exc:
            logger.exception(f"Failed to count posts: {exc}")
            return 0
    
    def list_posts_by_user_id(
        self,
        user_id: str,
        limit: int = 20,
        offset: int = 0,
        current_user_id: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """List posts by user ID with author information, like counts, and reposted posts."""
        try:
            resp = self._client.table("posts").select(
                "*, user_info!posts_user_id_fkey(email, first_name, last_name)"
            ).eq("user_id", user_id).order("created_at", desc=True).range(offset, offset + limit - 1).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list):
                # Enrich each post with author info, likes, and reposts
                enriched_posts = []
                for post in data:
                    # Flatten author info
                    if "user_info" in post and post["user_info"]:
                        author = post.pop("user_info")
                        post["author_email"] = author.get("email")
                        post["author_first_name"] = author.get("first_name")
                        post["author_last_name"] = author.get("last_name")
                    
                    post_id = post.get("post_id")
                    if post_id:
                        # Get like_count, repost_count, reply_count
                        post["like_count"] = post.get("like_count", 0) or 0
                        post["repost_count"] = post.get("repost_count", 0) or 0
                        post["reply_count"] = self.count_comments_by_post(post_id)
                        
                        # Add user's like/repost status
                        if current_user_id:
                            post["liked_by_current_user"] = self.is_post_liked_by_user(
                                post_id, current_user_id
                            )
                            post["reposted_by_current_user"] = self.is_post_reposted_by_user(
                                post_id, current_user_id
                            )
                        else:
                            post["liked_by_current_user"] = False
                            post["reposted_by_current_user"] = False
                        
                        # If this is a repost, get the original post (without its reposted_post to avoid infinite recursion)
                        reposted_post_id = post.get("reposted_post_id")
                        if reposted_post_id:
                            original_post = self.get_post_by_id(
                                reposted_post_id, current_user_id, include_reposted_post=False
                            )
                            if original_post:
                                post["reposted_post"] = original_post
                    
                    enriched_posts.append(post)
                return enriched_posts
            return []
        except Exception as exc:
            logger.exception(f"Failed to list posts for user {user_id}: {exc}")
            return []
    
    def delete_post(self, post_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Delete a post and all its comments (via CASCADE).
        Returns dict with ok and subthread_id on success (for cache invalidation), None otherwise.
        """
        try:
            post = self.get_post_by_id(post_id)
            if not post:
                logger.warning(f"Post {post_id} not found")
                return None
            if post["user_id"] != user_id:
                logger.warning(f"User {user_id} attempted to delete post {post_id} owned by {post['user_id']}")
                return None
            resp = self._client.table("posts").delete().eq("post_id", post_id).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                logger.info(f"Deleted post {post_id} and all comments")
                return {"ok": True, "subthread_id": post["subthread_id"]}
            return None
        except Exception as exc:
            logger.exception(f"Failed to delete post {post_id}: {exc}")
            return None
    
    # ========== Comment Operations ==========
    
    def create_comment(
        self,
        user_id: str,
        post_id: str,
        content: str,
        parent_id: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Create a new comment.
        
        Args:
            user_id: UUID of the author
            post_id: UUID of the post
            content: Comment content
            parent_id: Optional UUID of parent comment (for nested replies)
            
        Returns:
            Created comment data or None on failure
        """
        try:
            payload = {
                "user_id": user_id,
                "post_id": post_id,
                "content": content,
                "parent_id": parent_id,
                "has_parent": parent_id is not None,
            }
            resp = self._client.table("comments").insert(payload).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                logger.info(f"Created comment by user {user_id} on post {post_id}")
                return data[0]
            return None
        except Exception as exc:
            logger.exception(f"Failed to create comment: {exc}")
            return None
    
    def get_comment_by_id(self, comment_id: str) -> Optional[Dict[str, Any]]:
        """Get comment by ID with author information."""
        try:
            resp = self._client.table("comments").select(
                "*, user_info!comments_user_id_fkey(email, first_name, last_name)"
            ).eq("id", comment_id).limit(1).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                comment = data[0]
                # Flatten author info
                if "user_info" in comment and comment["user_info"]:
                    author = comment.pop("user_info")
                    comment["author_email"] = author.get("email")
                    comment["author_first_name"] = author.get("first_name")
                    comment["author_last_name"] = author.get("last_name")
                return comment
            return None
        except Exception as exc:
            logger.exception(f"Failed to get comment {comment_id}: {exc}")
            return None
    
    def list_comments_by_post(self, post_id: str) -> List[Dict[str, Any]]:
        """List all comments for a post with author information."""
        try:
            resp = self._client.table("comments").select(
                "*, user_info!comments_user_id_fkey(email, first_name, last_name)"
            ).eq("post_id", post_id).order("created_at", desc=False).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list):
                # Flatten author info for each comment
                for comment in data:
                    if "user_info" in comment and comment["user_info"]:
                        author = comment.pop("user_info")
                        comment["author_email"] = author.get("email")
                        comment["author_first_name"] = author.get("first_name")
                        comment["author_last_name"] = author.get("last_name")
                return data
            return []
        except Exception as exc:
            logger.exception(f"Failed to list comments for post {post_id}: {exc}")
            return []
    
    def count_comments_by_post(self, post_id: str) -> int:
        """Count total comments on a post."""
        try:
            from postgrest import CountMethod
            resp = self._client.table("comments").select("id", count=CountMethod.exact).eq("post_id", post_id).execute()
            return getattr(resp, "count", 0) or 0
        except Exception as exc:
            logger.exception(f"Failed to count comments: {exc}")
            return 0

    def get_comment_counts_for_posts(self, post_ids: List[str]) -> Dict[str, int]:
        """Return comment count per post_id (one query for all)."""
        if not post_ids:
            return {}
        try:
            resp = self._client.table("comments").select("post_id").in_("post_id", post_ids).execute()
            data = getattr(resp, "data", None) or []
            counts: Dict[str, int] = {pid: 0 for pid in post_ids}
            for row in data:
                pid = row.get("post_id")
                if pid:
                    counts[pid] = counts.get(pid, 0) + 1
            return counts
        except Exception as exc:
            logger.exception(f"Failed to get comment counts: {exc}")
            return {pid: 0 for pid in post_ids}

    def get_liked_post_ids_for_user(self, user_id: str, post_ids: List[str]) -> set:
        """Return set of post_ids liked by user (one query)."""
        if not post_ids or not user_id:
            return set()
        try:
            resp = self._client.table("post_likes").select("post_id").eq("user_id", user_id).in_("post_id", post_ids).execute()
            data = getattr(resp, "data", None) or []
            return {row["post_id"] for row in data if row.get("post_id")}
        except Exception as exc:
            logger.exception(f"Failed to get liked post ids: {exc}")
            return set()

    def get_reposted_post_ids_for_user(self, user_id: str, original_post_ids: List[str]) -> set:
        """Return set of original post_ids that the user has reposted (one query)."""
        if not original_post_ids or not user_id:
            return set()
        try:
            resp = self._client.table("posts").select("reposted_post_id").eq("user_id", user_id).in_("reposted_post_id", original_post_ids).execute()
            data = getattr(resp, "data", None) or []
            return {row["reposted_post_id"] for row in data if row.get("reposted_post_id")}
        except Exception as exc:
            logger.exception(f"Failed to get reposted post ids: {exc}")
            return set()

    def delete_comment(self, comment_id: str, user_id: str) -> bool:
        """
        Delete a comment (and all nested child comments via CASCADE).
        
        Args:
            comment_id: UUID of the comment to delete
            user_id: UUID of the user attempting deletion (must be comment author)
            
        Returns:
            True if deleted successfully, False otherwise
        """
        try:
            # First verify the comment exists and belongs to the user
            comment = self.get_comment_by_id(comment_id)
            if not comment:
                logger.warning(f"Comment {comment_id} not found")
                return False
            
            if comment["user_id"] != user_id:
                logger.warning(f"User {user_id} attempted to delete comment {comment_id} owned by {comment['user_id']}")
                return False
            
            # Delete the comment (CASCADE will handle nested comments)
            resp = self._client.table("comments").delete().eq("id", comment_id).execute()
            data = getattr(resp, "data", None)
            
            if isinstance(data, list) and data:
                logger.info(f"Deleted comment {comment_id} and all nested replies")
                return True
            
            return False
        except Exception as exc:
            logger.exception(f"Failed to delete comment {comment_id}: {exc}")
            return False
    
    # ========== Like Operations ==========
    
    def toggle_post_like(self, post_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Toggle like on a post (like if not liked, unlike if liked).
        Updates the like_count in the posts table directly.
        Enforces one like per user (can only like or unlike, not multiple likes).
        
        Args:
            post_id: UUID of the post
            user_id: UUID of the user
            
        Returns:
            Dict with 'liked' (bool) and 'like_count' (int) or None on failure
        """
        try:
            # First verify the post exists and get current like_count
            # Use * to get all columns in case post_id column name is different
            post_resp = self._client.table("posts").select("*").eq(
                "post_id", post_id
            ).limit(1).execute()
            
            post_data = getattr(post_resp, "data", None)
            if not isinstance(post_data, list) or len(post_data) == 0:
                logger.error(f"Post {post_id} not found in database")
                return None
            
            # Log for debugging
            logger.debug(f"Found post {post_id}, current like_count: {post_data[0].get('like_count', 0)}")
            
            current_like_count = post_data[0].get("like_count", 0) or 0
            
            # Check if like already exists (using the unique constraint)
            existing_like_resp = self._client.table("post_likes").select("id").eq(
                "post_id", post_id
            ).eq("user_id", user_id).limit(1).execute()
            
            like_data = getattr(existing_like_resp, "data", None)
            is_liked = isinstance(like_data, list) and len(like_data) > 0
            
            if is_liked:
                # Unlike: delete the like and decrement count
                delete_resp = self._client.table("post_likes").delete().eq(
                    "post_id", post_id
                ).eq("user_id", user_id).execute()
                
                # Verify deletion succeeded
                deleted_data = getattr(delete_resp, "data", None)
                if not isinstance(deleted_data, list) or len(deleted_data) == 0:
                    logger.warning(f"Failed to delete like for post {post_id} by user {user_id}")
                    return None
                
                # Decrement like_count in posts table
                new_count = max(0, current_like_count - 1)
                update_resp = self._client.table("posts").update({
                    "like_count": new_count
                }).eq("post_id", post_id).execute()
                
                updated_data = getattr(update_resp, "data", None)
                if not isinstance(updated_data, list) or len(updated_data) == 0:
                    logger.warning(f"Failed to update like_count for post {post_id}")
                    return None
                
                logger.info(f"User {user_id} unliked post {post_id}, new count: {new_count}")
                return {
                    "liked": False,
                    "like_count": new_count,
                    "subthread_id": post_data[0].get("subthread_id"),
                }
            else:
                # Like: create the like and increment count
                # Check one more time to prevent race conditions
                final_check = self._client.table("post_likes").select("id").eq(
                    "post_id", post_id
                ).eq("user_id", user_id).limit(1).execute()
                
                final_check_data = getattr(final_check, "data", None)
                if isinstance(final_check_data, list) and len(final_check_data) > 0:
                    # Like was created between our checks (race condition)
                    # Just return the current state
                    logger.info(f"Like already exists for post {post_id} by user {user_id} (race condition)")
                    return {
                        "liked": True,
                        "like_count": current_like_count,
                        "subthread_id": post_data[0].get("subthread_id"),
                    }
                
                # Insert the like
                try:
                    insert_resp = self._client.table("post_likes").insert({
                        "post_id": post_id,
                        "user_id": user_id,
                    }).execute()
                    
                    inserted_data = getattr(insert_resp, "data", None)
                    if not isinstance(inserted_data, list) or len(inserted_data) == 0:
                        # Insert failed, check if it's because of unique constraint
                        verify_like = self._client.table("post_likes").select("id").eq(
                            "post_id", post_id
                        ).eq("user_id", user_id).limit(1).execute()
                        verify_data = getattr(verify_like, "data", None)
                        if isinstance(verify_data, list) and len(verify_data) > 0:
                            # Like exists now (unique constraint prevented duplicate)
                            logger.info(f"Like already exists for post {post_id} by user {user_id}")
                            return {
                                "liked": True,
                                "like_count": current_like_count,
                                "subthread_id": post_data[0].get("subthread_id"),
                            }
                        logger.warning(f"Failed to insert like for post {post_id} by user {user_id}")
                        return None
                except Exception as insert_exc:
                    # Handle unique constraint violation or other errors
                    error_str = str(insert_exc).lower()
                    if "unique" in error_str or "duplicate" in error_str or "violates" in error_str:
                        # Like already exists (unique constraint prevented duplicate)
                        logger.info(f"Like already exists for post {post_id} by user {user_id} (unique constraint)")
                        # Verify the like exists and return current state
                        verify_like = self._client.table("post_likes").select("id").eq(
                            "post_id", post_id
                        ).eq("user_id", user_id).limit(1).execute()
                        verify_data = getattr(verify_like, "data", None)
                        if isinstance(verify_data, list) and len(verify_data) > 0:
                            return {
                                "liked": True,
                                "like_count": current_like_count,
                                "subthread_id": post_data[0].get("subthread_id"),
                            }
                    # Re-raise if it's not a unique constraint error
                    logger.exception(f"Unexpected error inserting like: {insert_exc}")
                    raise
                
                # Increment like_count in posts table
                new_count = current_like_count + 1
                update_resp = self._client.table("posts").update({
                    "like_count": new_count
                }).eq("post_id", post_id).execute()
                
                updated_data = getattr(update_resp, "data", None)
                if not isinstance(updated_data, list) or len(updated_data) == 0:
                    logger.warning(f"Failed to update like_count for post {post_id}")
                    # Rollback: delete the like we just created
                    try:
                        self._client.table("post_likes").delete().eq(
                            "post_id", post_id
                        ).eq("user_id", user_id).execute()
                    except:
                        pass
                    return None
                
                logger.info(f"User {user_id} liked post {post_id}, new count: {new_count}")
                return {
                    "liked": True,
                    "like_count": new_count,
                    "subthread_id": post_data[0].get("subthread_id"),
                }
        except Exception as exc:
            logger.exception(f"Failed to toggle like for post {post_id}: {exc}")
            return None
    
    def get_post_like_count(self, post_id: str) -> int:
        """Get like count for a post from the posts table."""
        try:
            resp = self._client.table("posts").select("like_count").eq(
                "post_id", post_id
            ).limit(1).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                return data[0].get("like_count", 0) or 0
            return 0
        except Exception as exc:
            logger.exception(f"Failed to get like count for post {post_id}: {exc}")
            return 0
    
    def is_post_liked_by_user(self, post_id: str, user_id: str) -> bool:
        """Check if a post is liked by a user."""
        try:
            resp = self._client.table("post_likes").select("id").eq(
                "post_id", post_id
            ).eq("user_id", user_id).limit(1).execute()
            data = getattr(resp, "data", None)
            return isinstance(data, list) and len(data) > 0
        except Exception as exc:
            logger.exception(f"Failed to check like status: {exc}")
            return False
    
    def get_post_repost_count(self, post_id: str) -> int:
        """Get repost count for a post from the posts table."""
        try:
            resp = self._client.table("posts").select("repost_count").eq(
                "post_id", post_id
            ).limit(1).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                return data[0].get("repost_count", 0) or 0
            return 0
        except Exception as exc:
            logger.exception(f"Failed to get repost count for post {post_id}: {exc}")
            return 0
    
    def is_post_reposted_by_user(self, post_id: str, user_id: str) -> bool:
        """Check if a post is reposted by a user."""
        try:
            resp = self._client.table("posts").select("post_id").eq(
                "reposted_post_id", post_id
            ).eq("user_id", user_id).limit(1).execute()
            data = getattr(resp, "data", None)
            return isinstance(data, list) and len(data) > 0
        except Exception as exc:
            logger.exception(f"Failed to check repost status: {exc}")
            return False
    
    def create_repost(
        self,
        user_id: str,
        subthread_id: str,
        original_post_id: str,
        content: str = "",
    ) -> Optional[Dict[str, Any]]:
        """
        Create a repost (new post that references the original).
        Increments the repost_count in the original post.
        
        Args:
            user_id: UUID of the user creating the repost
            subthread_id: UUID of the subthread
            original_post_id: UUID of the original post being reposted
            content: Optional comment/content on the repost
            
        Returns:
            Created repost data with embedded original post or None on failure
        """
        try:
            # Get original post
            original_post = self.get_post_by_id(original_post_id)
            if not original_post:
                logger.warning(f"Original post {original_post_id} not found")
                return None
            
            # Get current repost_count
            current_repost_count = original_post.get("repost_count", 0) or 0
            
            # Create repost
            title = original_post.get("title", "")
            payload = {
                "user_id": user_id,
                "subthread_id": subthread_id,
                "title": title,
                "content": content or "",
                "reposted_post_id": original_post_id,
            }
            
            resp = self._client.table("posts").insert(payload).execute()
            data = getattr(resp, "data", None)
            if isinstance(data, list) and data:
                repost = data[0]
                
                # Increment repost_count in original post
                new_repost_count = current_repost_count + 1
                self._client.table("posts").update({
                    "repost_count": new_repost_count
                }).eq("post_id", original_post_id).execute()
                
                # Add author info to repost
                repost = self._enrich_post_with_author(repost)
                # Add embedded original post (with updated repost_count)
                original_post["repost_count"] = new_repost_count
                repost["reposted_post"] = original_post
                logger.info(f"Created repost by user {user_id}")
                return repost
            return None
        except Exception as exc:
            logger.exception(f"Failed to create repost: {exc}")
            return None
    
    def _enrich_post_with_author(self, post: Dict[str, Any]) -> Dict[str, Any]:
        """Helper to add author information to a post."""
        try:
            user_id = post.get("user_id")
            if not user_id:
                return post
            
            # Get author info
            resp = self._client.table("user_info").select(
                "email, first_name, last_name"
            ).eq("id", user_id).limit(1).execute()
            author_data = getattr(resp, "data", None)
            
            if isinstance(author_data, list) and author_data:
                author = author_data[0]
                post["author_email"] = author.get("email")
                post["author_first_name"] = author.get("first_name")
                post["author_last_name"] = author.get("last_name")
            
            return post
        except Exception as exc:
            logger.exception(f"Failed to enrich post with author: {exc}")
            return post