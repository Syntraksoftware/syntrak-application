# Community Backend Cache Tests (Windows / PowerShell)

Base URL: http://127.0.0.1:5001/api/v1

Auth: write endpoints require Authorization: Bearer <JWT> from main-backend auth.

This version is for Windows PowerShell and creates a new user before running cache tests.

## Setup

```powershell
# 1) Community service health
Invoke-RestMethod -Method GET -Uri "http://127.0.0.1:5001/health" | ConvertTo-Json -Depth 10

# 2) Base URLs
$MainBase = "http://127.0.0.1:8080/api/v1"
$Base = "http://127.0.0.1:5001/api/v1"

# 3) Create a fresh user first (unique email each run)
$Stamp = Get-Date -Format "yyyyMMddHHmmss"
$Email = "community.cache.$Stamp@example.com"
$Password = "StrongPass123!"

$RegisterBody = @{
  email = $Email
  password = $Password
  first_name = "Cache"
  last_name = "Tester"
} | ConvertTo-Json

try {
  $RegisterResponse = Invoke-RestMethod -Method POST -Uri "$MainBase/auth/register" -ContentType "application/json" -Body $RegisterBody
  Write-Host "User created: $Email"
}
catch {
  Write-Host "Register failed. Response body:"
  Write-Host $_.Exception.Message
  throw
}

# 4) Login and export token
$LoginBody = @{
  email = $Email
  password = $Password
} | ConvertTo-Json

$LoginResponse = Invoke-RestMethod -Method POST -Uri "$MainBase/auth/login" -ContentType "application/json" -Body $LoginBody
$Token = $LoginResponse.access_token

if ([string]::IsNullOrWhiteSpace($Token)) {
  throw "Failed to get token"
}

$Headers = @{ Authorization = "Bearer $Token" }
Write-Host "TOKEN set for $Email"
```

## Test Data Bootstrap

```powershell
# Create a subthread for cache tests
$SubthreadPayload = @{
  name = "cache-tests-windows"
  description = "cache verification on windows"
} | ConvertTo-Json

$SubthreadResponse = Invoke-RestMethod -Method POST -Uri "$Base/subthreads" -Headers $Headers -ContentType "application/json" -Body $SubthreadPayload
$SubthreadId = $SubthreadResponse.id

if ([string]::IsNullOrWhiteSpace($SubthreadId)) {
  throw "Failed to create subthread"
}

Write-Host "SUBTHREAD_ID=$SubthreadId"

# Create one seed post
$PostPayload = @{
  subthread_id = $SubthreadId
  title = "Cache seed"
  content = "first content"
} | ConvertTo-Json

$PostResponse = Invoke-RestMethod -Method POST -Uri "$Base/posts/" -Headers $Headers -ContentType "application/json" -Body $PostPayload
$PostId = $PostResponse.post_id

if ([string]::IsNullOrWhiteSpace($PostId)) {
  throw "Failed to create post"
}

Write-Host "POST_ID=$PostId"
```

## Cache Test 1: Feed Warm + Hit

Expected: first request is slower (cache miss), second request is faster (cache hit).

```powershell
$Time1 = Measure-Command {
  Invoke-RestMethod -Method GET -Uri "$Base/feed?limit=20&offset=0" -Headers $Headers | Out-Null
}
Write-Host ("feed-call-1 total_ms={0}" -f [math]::Round($Time1.TotalMilliseconds, 2))

$Time2 = Measure-Command {
  Invoke-RestMethod -Method GET -Uri "$Base/feed?limit=20&offset=0" -Headers $Headers | Out-Null
}
Write-Host ("feed-call-2 total_ms={0}" -f [math]::Round($Time2.TotalMilliseconds, 2))
```

## Cache Test 2: Feed Invalidates On Post Write

Expected: after creating a new post, feed refreshes and newest post appears first.

```powershell
# Warm feed first
$FeedBefore = Invoke-RestMethod -Method GET -Uri "$Base/feed?limit=20&offset=0" -Headers $Headers
$TopBefore = $FeedBefore.items[0].post_id
Write-Host "TOP_BEFORE=$TopBefore"

# Create a new post (invalidates feed cache version)
$NewPostPayload = @{
  subthread_id = $SubthreadId
  title = "Invalidate feed"
  content = "new content"
} | ConvertTo-Json

$NewPostResponse = Invoke-RestMethod -Method POST -Uri "$Base/posts/" -Headers $Headers -ContentType "application/json" -Body $NewPostPayload
$NewPostId = $NewPostResponse.post_id
Write-Host "NEW_POST_ID=$NewPostId"

$FeedAfter = Invoke-RestMethod -Method GET -Uri "$Base/feed?limit=20&offset=0" -Headers $Headers
$TopAfter = $FeedAfter.items[0].post_id
Write-Host "TOP_AFTER=$TopAfter"

if ($TopAfter -eq $NewPostId) {
  Write-Host "PASS: feed invalidated"
} else {
  Write-Host "WARN: ordering/timestamp may differ"
}
```

## Cache Test 3: Comments Warm + Hit

Expected: first comments request is slower, second request is faster.

```powershell
# Create one comment
$CommentPayload = @{
  post_id = $PostId
  content = "first comment"
} | ConvertTo-Json

$CommentResponse = Invoke-RestMethod -Method POST -Uri "$Base/comments" -Headers $Headers -ContentType "application/json" -Body $CommentPayload
$CommentId = $CommentResponse.id
Write-Host "COMMENT_ID=$CommentId"

$CommentsTime1 = Measure-Command {
  Invoke-RestMethod -Method GET -Uri "$Base/posts/$PostId/comments" -Headers $Headers | Out-Null
}
Write-Host ("comments-call-1 total_ms={0}" -f [math]::Round($CommentsTime1.TotalMilliseconds, 2))

$CommentsTime2 = Measure-Command {
  Invoke-RestMethod -Method GET -Uri "$Base/posts/$PostId/comments" -Headers $Headers | Out-Null
}
Write-Host ("comments-call-2 total_ms={0}" -f [math]::Round($CommentsTime2.TotalMilliseconds, 2))
```

## Cache Test 4: Comments Invalidate On New Comment

Expected: after posting another comment, comments endpoint returns updated count.

```powershell
$CommentsBefore = Invoke-RestMethod -Method GET -Uri "$Base/posts/$PostId/comments" -Headers $Headers
$CountBefore = [int]$CommentsBefore.meta.pagination.total
Write-Host "COUNT_BEFORE=$CountBefore"

$SecondCommentPayload = @{
  post_id = $PostId
  content = "second comment"
} | ConvertTo-Json

Invoke-RestMethod -Method POST -Uri "$Base/comments" -Headers $Headers -ContentType "application/json" -Body $SecondCommentPayload | Out-Null

$CommentsAfter = Invoke-RestMethod -Method GET -Uri "$Base/posts/$PostId/comments" -Headers $Headers
$CountAfter = [int]$CommentsAfter.meta.pagination.total
Write-Host "COUNT_AFTER=$CountAfter"

if ($CountAfter -gt $CountBefore) {
  Write-Host "PASS: comments invalidated"
} else {
  Write-Host "FAIL: expected count increase"
}
```

## Cache Test 5: Batch Comments Reuses Per-Post Cache

Expected: second batch call is faster and returns same per-post comment data.

```powershell
# Create a second post
$Post2Payload = @{
  subthread_id = $SubthreadId
  title = "Batch seed"
  content = "batch content"
} | ConvertTo-Json

$Post2Response = Invoke-RestMethod -Method POST -Uri "$Base/posts/" -Headers $Headers -ContentType "application/json" -Body $Post2Payload
$PostId2 = $Post2Response.post_id

# Create one comment on post 2
$Comment2Payload = @{
  post_id = $PostId2
  content = "comment for second post"
} | ConvertTo-Json

Invoke-RestMethod -Method POST -Uri "$Base/comments" -Headers $Headers -ContentType "application/json" -Body $Comment2Payload | Out-Null

$BatchBody = @{
  post_ids = @($PostId, $PostId2)
} | ConvertTo-Json

$BatchTime1 = Measure-Command {
  Invoke-RestMethod -Method POST -Uri "$Base/posts/comments/batch" -Headers $Headers -ContentType "application/json" -Body $BatchBody | Out-Null
}
Write-Host ("batch-call-1 total_ms={0}" -f [math]::Round($BatchTime1.TotalMilliseconds, 2))

$BatchTime2 = Measure-Command {
  Invoke-RestMethod -Method POST -Uri "$Base/posts/comments/batch" -Headers $Headers -ContentType "application/json" -Body $BatchBody | Out-Null
}
Write-Host ("batch-call-2 total_ms={0}" -f [math]::Round($BatchTime2.TotalMilliseconds, 2))

$BatchResult = Invoke-RestMethod -Method POST -Uri "$Base/posts/comments/batch" -Headers $Headers -ContentType "application/json" -Body $BatchBody
$BatchResult | ConvertTo-Json -Depth 10
```

## Optional: Verify Redis Version Keys

These checks work if redis-cli is installed and cache is enabled.

```powershell
redis-cli GET community-backend-cache:version:feed
redis-cli GET community-backend-cache:version:post-comments:$PostId
```

## Notes

- TTL defaults are short: CACHE_FEED_TTL_SECONDS=15, CACHE_POST_COMMENTS_TTL_SECONDS=20.
- On local machines, timing differences can be small; run each pair 3-5 times and compare average.
- Cache keys are user-scoped, so use the same token for warm vs hit comparison.
