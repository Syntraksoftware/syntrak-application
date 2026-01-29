"""
Redis cache layer for community backend. Caches subthread posts list to speed up reloads.
"""
import json
import logging
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)
_redis = None
_ttl = 60


def init_cache(redis_url: str, ttl_seconds: int = 60) -> None:
    global _redis, _ttl
    _ttl = ttl_seconds
    try:
        import redis
        _redis = redis.from_url(redis_url, decode_responses=True)
        _redis.ping()
        logger.info("Redis cache connected")
    except Exception as e:
        logger.warning("Redis unavailable, cache disabled: %s", e)
        _redis = None


def _key(subthread_id: str, limit: int, offset: int, user_id: Optional[str]) -> str:
    uid = user_id or "anon" # anonymous user id
    return f"community:posts:{subthread_id}:{limit}:{offset}:{uid}"


def get_posts(subthread_id: str, limit: int, offset: int, user_id: Optional[str]) -> Optional[Dict[str, Any]]:
    """Return cached {posts: [...], total: N} or None."""
    if _redis is None:
        return None
    try:
        raw = _redis.get(_key(subthread_id, limit, offset, user_id))
        if raw is None:
            return None
        return json.loads(raw)
    except Exception as e:
        logger.debug("Cache get error: %s", e)
        return None


def set_posts(subthread_id: str, limit: int, offset: int, user_id: Optional[str], posts: List[Dict], total: int) -> None:
    """Cache posts list and total."""
    if _redis is None:
        return
    try:
        payload = json.dumps({"posts": posts, "total": total})
        _redis.setex(_key(subthread_id, limit, offset, user_id), _ttl, payload)
    except Exception as e:
        logger.debug("Cache set error: %s", e)


def invalidate_subthread(subthread_id: str) -> None:
    """Remove all keys for a subthread (e.g. after new post). Optional; scan is O(N)."""
    if _redis is None:
        return
    try:
        for key in _redis.scan_iter(match=f"community:posts:{subthread_id}:*", count=100):
            _redis.delete(key)
    except Exception as e:
        logger.debug("Cache invalidate error: %s", e)
