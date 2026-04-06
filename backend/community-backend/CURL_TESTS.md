# Community Backend Curl Tests

Base URL: `http://127.0.0.1:5001/api/v1`

Auth: write endpoints require `Authorization: Bearer <JWT>` from main-backend auth.

Windows users: use `CURL_TESTS_WINDOWS.md` for a PowerShell-friendly version that creates a test user before login.

## Setup

```bash
# 1) Community service health
curl -sS http://127.0.0.1:5001/health | jq .

# 2) Login on main-backend and export TOKEN
EMAIL="demo.user@example.com"
PASSWORD="StrongPass123!"

TOKEN=$(curl -sS -X POST \
  "http://127.0.0.1:8080/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  --data @- <<JSON | jq -r '.access_token'
{ "email": "${EMAIL}", "password": "${PASSWORD}" }
JSON
)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Failed to get TOKEN"; exit 1
fi

echo "TOKEN set: ${TOKEN:0:16}..."

BASE="http://127.0.0.1:5001/api/v1"
```

## Test Data Bootstrap

```bash
# Create a subthread used by cache tests
SUBTHREAD_ID=$(curl -sS -X POST \
  "$BASE/subthreads" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"name":"cache-tests","description":"cache verification"}' \
  | jq -r '.id')

if [ -z "$SUBTHREAD_ID" ] || [ "$SUBTHREAD_ID" = "null" ]; then
  echo "Failed to create SUBTHREAD_ID"; exit 1
fi

echo "SUBTHREAD_ID=$SUBTHREAD_ID"

# Create one seed post
POST_ID=$(curl -sS -X POST \
  "$BASE/posts/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @- <<JSON | jq -r '.post_id'
{ "subthread_id": "${SUBTHREAD_ID}", "title": "Cache seed", "content": "first content" }
JSON
)

if [ -z "$POST_ID" ] || [ "$POST_ID" = "null" ]; then
  echo "Failed to create POST_ID"; exit 1
fi

echo "POST_ID=$POST_ID"
```

## Cache Test 1: Feed Warm + Hit

Expected: first request is slower (cache miss), second request is faster (cache hit).

```bash
curl -sS -o /dev/null -w "feed-call-1 time_total=%{time_total}\n" \
  "$BASE/feed?limit=20&offset=0" \
  -H "Authorization: Bearer $TOKEN"

curl -sS -o /dev/null -w "feed-call-2 time_total=%{time_total}\n" \
  "$BASE/feed?limit=20&offset=0" \
  -H "Authorization: Bearer $TOKEN"
```

## Cache Test 2: Feed Invalidates On Post Write

Expected: after creating a new post, feed refreshes and newest post appears first.

```bash
# Warm feed first
curl -sS "$BASE/feed?limit=20&offset=0" -H "Authorization: Bearer $TOKEN" | jq -r '.items[0].post_id'

# Create a new post (this should invalidate feed cache version)
NEW_POST_ID=$(curl -sS -X POST \
  "$BASE/posts/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @- <<JSON | jq -r '.post_id'
{ "subthread_id": "${SUBTHREAD_ID}", "title": "Invalidate feed", "content": "new content" }
JSON
)

echo "NEW_POST_ID=$NEW_POST_ID"

# Feed should now reflect fresh data
TOP_POST_ID=$(curl -sS "$BASE/feed?limit=20&offset=0" -H "Authorization: Bearer $TOKEN" | jq -r '.items[0].post_id')

echo "TOP_POST_ID=$TOP_POST_ID"
[ "$TOP_POST_ID" = "$NEW_POST_ID" ] && echo "PASS: feed invalidated" || echo "WARN: ordering/timestamp may differ"
```

## Cache Test 3: Comments Warm + Hit

Expected: first comments request is slower, second is faster.

```bash
# Create one comment
COMMENT_ID=$(curl -sS -X POST \
  "$BASE/comments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @- <<JSON | jq -r '.id'
{ "post_id": "${POST_ID}", "content": "first comment" }
JSON
)

echo "COMMENT_ID=$COMMENT_ID"

curl -sS -o /dev/null -w "comments-call-1 time_total=%{time_total}\n" \
  "$BASE/posts/$POST_ID/comments" \
  -H "Authorization: Bearer $TOKEN"

curl -sS -o /dev/null -w "comments-call-2 time_total=%{time_total}\n" \
  "$BASE/posts/$POST_ID/comments" \
  -H "Authorization: Bearer $TOKEN"
```

## Cache Test 4: Comments Invalidate On New Comment

Expected: after posting another comment, comments endpoint returns updated count.

```bash
COUNT_BEFORE=$(curl -sS "$BASE/posts/$POST_ID/comments" -H "Authorization: Bearer $TOKEN" | jq -r '.meta.pagination.total')

echo "COUNT_BEFORE=$COUNT_BEFORE"

curl -sS -X POST \
  "$BASE/comments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @- <<JSON | jq .
{ "post_id": "${POST_ID}", "content": "second comment" }
JSON

COUNT_AFTER=$(curl -sS "$BASE/posts/$POST_ID/comments" -H "Authorization: Bearer $TOKEN" | jq -r '.meta.pagination.total')

echo "COUNT_AFTER=$COUNT_AFTER"
```

## Cache Test 5: Batch Comments Reuses Per-Post Cache

Expected: second batch call is faster and returns same per-post comment data.

```bash
# Ensure two post ids exist
POST_ID_2=$(curl -sS -X POST \
  "$BASE/posts/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @- <<JSON | jq -r '.post_id'
{ "subthread_id": "${SUBTHREAD_ID}", "title": "Batch seed", "content": "batch content" }
JSON
)

curl -sS -X POST \
  "$BASE/comments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @- <<JSON | jq .
{ "post_id": "${POST_ID_2}", "content": "comment for second post" }
JSON

BODY=$(cat <<JSON
{ "post_ids": ["${POST_ID}", "${POST_ID_2}"] }
JSON
)

curl -sS -o /dev/null -w "batch-call-1 time_total=%{time_total}\n" \
  -X POST "$BASE/posts/comments/batch" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY"

curl -sS -o /dev/null -w "batch-call-2 time_total=%{time_total}\n" \
  -X POST "$BASE/posts/comments/batch" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY"

curl -sS -X POST "$BASE/posts/comments/batch" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" | jq .
```

## Optional: Verify Redis Version Keys

These checks only work if `redis-cli` is installed and cache is enabled.

```bash
redis-cli GET community-backend-cache:version:feed
redis-cli GET community-backend-cache:version:post-comments:$POST_ID
```

## Notes

- TTL defaults in config are short (`CACHE_FEED_TTL_SECONDS=15`, `CACHE_POST_COMMENTS_TTL_SECONDS=20`).
- If timings are very close on local machine, run each pair 3-5 times and compare average.
- Cache keys are user-scoped, so run tests with the same token when comparing warm vs hit behavior.
