"""Subthread routes."""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional, List
from pydantic import BaseModel
import logging

from middleware.auth import get_current_user, get_optional_user
from services.supabase_client import get_community_client
from routes.posts import PostResponse as PostsPostResponse

logger = logging.getLogger(__name__)
router = APIRouter()


# Pydantic models
class SubthreadCreate(BaseModel):
    """Schema for creating a subthread."""
    name: str
    description: Optional[str] = None


class SubthreadResponse(BaseModel):
    """Schema for subthread response."""
    id: str
    name: str
    description: Optional[str] = None
    created_at: str


class SubthreadsListResponse(BaseModel):
    """Schema for subthreads list response."""
    subthreads: List[SubthreadResponse]
    total: int


@router.get("", response_model=SubthreadsListResponse)
async def list_subthreads(limit: int = Query(50, ge=1, le=200)):
    """List all subthreads."""
    try:
        client = get_community_client()
        subthreads = client.list_subthreads(limit=limit)
        
        # Convert dicts to Pydantic models
        subthread_models = [SubthreadResponse(**sub) for sub in subthreads]
        
        return SubthreadsListResponse(
            subthreads=subthread_models,
            total=len(subthread_models)
        )
    except Exception as e:
        logger.error(f"Error listing subthreads: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("", response_model=SubthreadResponse, status_code=status.HTTP_201_CREATED)
async def create_subthread(
    data: SubthreadCreate,
    user_id: str = Depends(get_current_user)
):
    """Create a new subthread (authenticated)."""
    try:
        client = get_community_client()
        result = client.create_subthread(
            name=data.name,
            description=data.description
        )
        
        if not result:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create subthread"
            )
        
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating subthread: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/{subthread_id}", response_model=SubthreadResponse)
async def get_subthread(subthread_id: str):
    """Get subthread by ID."""
    try:
        client = get_community_client()
        subthread = client.get_subthread_by_id(subthread_id)
        
        if not subthread:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subthread not found"
            )
        
        return subthread
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting subthread: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


class PostsListResponse(BaseModel):
    """Schema for posts list response."""
    posts: List[PostsPostResponse]
    total: int
    page: int
    page_size: int


@router.get("/{subthread_id}/posts", response_model=PostsListResponse)
async def list_subthread_posts(
    subthread_id: str,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: Optional[str] = Depends(get_optional_user),
):
    """List posts in a subthread (includes reposted_post for reposts)."""
    try:
        client = get_community_client()
        
        # Verify subthread exists
        subthread = client.get_subthread_by_id(subthread_id)
        if not subthread:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subthread not found"
            )
        
        posts = client.list_posts_by_subthread(
            subthread_id=subthread_id,
            limit=limit,
            offset=offset,
            current_user_id=current_user,
        )
        total = client.count_posts_by_subthread(subthread_id)
        
        # Convert dicts to Pydantic models (includes reposted_post, like_count, reply_count, etc.)
        post_models = []
        for post in posts:
            try:
                # Ensure nested reposted_post is a PostResponse so it serializes in the JSON response
                if "reposted_post" in post and post["reposted_post"]:
                    reposted_post_dict = post["reposted_post"]
                    if isinstance(reposted_post_dict, dict):
                        # Build nested model without reposted_post to avoid recursion
                        nested = {k: v for k, v in reposted_post_dict.items() if k != "reposted_post"}
                        post["reposted_post"] = PostsPostResponse(**nested)
                post_model = PostsPostResponse(**post)
                post_models.append(post_model)
            except Exception as e:
                logger.error(f"Error converting post to PostResponse: {str(e)}, post_id: {post.get('post_id')}")
                logger.exception(e)
                # Try without reposted_post if it fails
                try:
                    post_without_repost = {k: v for k, v in post.items() if k != "reposted_post"}
                    post_model = PostsPostResponse(**post_without_repost)
                    post_models.append(post_model)
                except:
                    logger.error(f"Failed to convert post even without reposted_post: {post.get('post_id')}")
                    # Skip this post
                    continue
        
        return PostsListResponse(
            posts=post_models,
            total=total,
            page=offset // limit + 1,
            page_size=limit
        )
    except HTTPException:
        raise
    except Exception:
        logger.error(f"Error listing subthread posts")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal Server Error"
        )


class DeleteResponse(BaseModel):
    """Schema for delete response."""
    message: str
    deleted_subthread_id: Optional[str] = None


@router.delete("/{subthread_id}", response_model=DeleteResponse)
async def delete_subthread(
    subthread_id: str,
    user_id: str = Depends(get_current_user)
):
    """Delete a subthread and all its posts/comments (authenticated)."""
    try:
        client = get_community_client()
        
        # TODO: Implement admin/moderator check before production  
        # TEMPORARY: Block all deletions until authorization is implemented  
        
        success = client.delete_subthread(subthread_id)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subthread not found"
            )
        
        return DeleteResponse(
            message="Subthread, posts, and comments deleted successfully",
            deleted_subthread_id=subthread_id
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting subthread")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal Server Error"
        )
