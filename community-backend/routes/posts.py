"""Post routes."""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional, List
from pydantic import BaseModel
import logging

from middleware.auth import get_current_user, get_optional_user
from services.supabase_client import get_community_client
from services import cache as cache_svc

logger = logging.getLogger(__name__)
router = APIRouter()


# Pydantic models
class PostCreate(BaseModel):
    """Schema for creating a post."""
    subthread_id: str
    title: str
    content: str
    reposted_post_id: Optional[str] = None  # For reposts


class PostResponse(BaseModel):
    """Schema for post response."""
    post_id: str
    user_id: str
    subthread_id: str
    title: str
    content: str
    created_at: str
    author_email: Optional[str] = None
    author_first_name: Optional[str] = None
    author_last_name: Optional[str] = None
    like_count: int = 0
    repost_count: int = 0
    reply_count: int = 0  # comment count
    liked_by_current_user: bool = False
    reposted_by_current_user: bool = False
    reposted_post_id: Optional[str] = None
    reposted_post: Optional["PostResponse"] = None  # Embedded reposted post
    
    class Config:
        # Allow recursive models and populate from dicts
        from_attributes = True
        populate_by_name = True


class CommentResponse(BaseModel):
    """Schema for comment response."""
    id: str
    user_id: str
    post_id: str
    parent_id: Optional[str] = None
    content: str
    has_parent: bool
    created_at: str
    author_email: Optional[str] = None
    author_first_name: Optional[str] = None
    author_last_name: Optional[str] = None


class CommentsListResponse(BaseModel):
    """Schema for comments list response."""
    comments: List[CommentResponse]
    total: int
    post_id: str


class PostsListResponse(BaseModel):
    """Schema for posts list response."""
    posts: List[PostResponse]
    page: int
    page_size: int


class DeleteResponse(BaseModel):
    """Schema for delete response."""
    message: str
    deleted_post_id: Optional[str] = None


@router.post("", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def create_post(
    data: PostCreate,
    user_id: str = Depends(get_current_user)
):
    """Create a new post (authenticated)."""
    try:
        client = get_community_client()
        
        # Verify subthread exists
        subthread = client.get_subthread_by_id(data.subthread_id)
        if not subthread:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subthread not found"
            )
        
        result = client.create_post(
            user_id=user_id,
            subthread_id=data.subthread_id,
            title=data.title,
            content=data.content,
            reposted_post_id=data.reposted_post_id
        )
        
        if not result:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create post"
            )
        cache_svc.invalidate_subthread(data.subthread_id)
        return result
    except HTTPException:
        raise
    except Exception:
        logger.error(f"Error creating post")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal Server Error"
        )


@router.get("/{post_id}", response_model=PostResponse)
async def get_post(
    post_id: str,
    current_user: Optional[str] = Depends(get_optional_user)
):
    """Get post by ID."""
    try:
        client = get_community_client()
        post = client.get_post_by_id(post_id, current_user)
        
        if not post:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Post not found"
            )
        
        return post
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting post: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/user/{user_id}", response_model=PostsListResponse)
async def list_posts_by_user(
    user_id: str,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: Optional[str] = Depends(get_optional_user)
):
    """List posts by user ID (optional authentication)."""
    try:
        client = get_community_client()
        
        posts = client.list_posts_by_user_id(
            user_id=user_id,
            limit=limit,
            offset=offset,
            current_user_id=current_user
        )
        
        # Convert dicts to Pydantic models
        post_models = [PostResponse(**post) for post in posts]
        
        return PostsListResponse(
            posts=post_models,
            page=offset // limit + 1,
            page_size=limit
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error listing posts by user: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal Server Error"
        )


@router.get("/{post_id}/comments", response_model=CommentsListResponse)
async def list_post_comments(post_id: str):
    """List all comments for a post."""
    try:
        client = get_community_client()
        
        # Verify post exists
        post = client.get_post_by_id(post_id)
        if not post:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Post not found"
            )
        
        comments = client.list_comments_by_post(post_id)
        total = client.count_comments_by_post(post_id)
        
        # Convert dicts to Pydantic models
        comment_models = [CommentResponse(**comment) for comment in comments]
        
        return CommentsListResponse(
            comments=comment_models,
            total=total,
            post_id=post_id
        )
    except HTTPException:
        raise
    except Exception:
        logger.error(f"Error listing post comments")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal Server Error"
        )


@router.delete("/{post_id}", response_model=DeleteResponse)
async def delete_post(
    post_id: str,
    user_id: str = Depends(get_current_user)
):
    """Delete a post and all its comments (authenticated)."""
    try:
        client = get_community_client()
        result = client.delete_post(post_id, user_id)
        if not result:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Post not found or unauthorized"
            )
        sid = result.get("subthread_id")
        if sid:
            cache_svc.invalidate_subthread(sid)
        return DeleteResponse(
            message="Post and all comments deleted successfully",
            deleted_post_id=post_id
        )
    except HTTPException:
        raise
    except Exception:
        logger.error(f"Error deleting post")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal Server Error"
        )


class LikeResponse(BaseModel):
    """Schema for like response."""
    message: str
    liked: bool
    like_count: int


@router.post("/{post_id}/like", response_model=LikeResponse)
async def toggle_like(
    post_id: str,
    user_id: str = Depends(get_current_user)
):
    """Like or unlike a post (authenticated)."""
    try:
        client = get_community_client()
        
        # Toggle like (this will verify post exists internally)
        result = client.toggle_post_like(post_id, user_id)
        
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Post not found"
            )
        
        sid = result.get("subthread_id")
        if sid:
            cache_svc.invalidate_subthread(sid)
        return LikeResponse(
            message="Like toggled successfully",
            liked=result["liked"],
            like_count=result["like_count"]
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error toggling like: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal Server Error: {str(e)}"
        )


class RepostCreate(BaseModel):
    """Schema for creating a repost."""
    subthread_id: str
    content: Optional[str] = None  # Optional comment on the repost


@router.post("/{post_id}/repost", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def create_repost(
    post_id: str,
    data: RepostCreate,
    user_id: str = Depends(get_current_user)
):
    """Create a repost (authenticated)."""
    try:
        client = get_community_client()
        
        # Verify original post exists
        original_post = client.get_post_by_id(post_id)
        if not original_post:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Original post not found"
            )
        
        # Verify subthread exists
        subthread = client.get_subthread_by_id(data.subthread_id)
        if not subthread:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subthread not found"
            )
        
        # Create repost (new post with reference to original)
        result = client.create_repost(
            user_id=user_id,
            subthread_id=data.subthread_id,
            original_post_id=post_id,
            content=data.content or ""
        )
        
        if not result:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create repost"
            )
        cache_svc.invalidate_subthread(data.subthread_id)
        orig_sid = original_post.get("subthread_id")
        if orig_sid and orig_sid != data.subthread_id:
            cache_svc.invalidate_subthread(orig_sid)
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating repost: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal Server Error"
        )
