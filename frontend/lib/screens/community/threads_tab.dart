import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syntrak/core/theme.dart';
import 'package:syntrak/providers/auth_provider.dart';
import 'package:syntrak/models/post.dart';
import 'package:syntrak/services/api_service.dart';
import 'package:syntrak/widgets/thread_card.dart';

class ThreadsTab extends StatefulWidget {
  final ValueListenable<int>? refreshTrigger;

  const ThreadsTab({super.key, this.refreshTrigger});

  @override
  State<ThreadsTab> createState() => _ThreadsTabState();
}

class _ThreadsTabState extends State<ThreadsTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<Post> _posts = [];
  List<Post> _filteredPosts = [];
  bool _isRefreshing = false;
  bool _isLoading = false;
  bool _isSearchFocused = false;
  String? _expandedPostId;
  String? _defaultSubthreadId;

  @override
  void initState() {
    super.initState();
    widget.refreshTrigger?.addListener(_onRefreshTriggered);
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
    _searchController.addListener(() {
      setState(() {
        // Trigger rebuild when text changes to update clear button
      });
    });
    _loadFeed();
  }

  void _onRefreshTriggered() {
    _loadFeed();
  }

  @override
  void dispose() {
    widget.refreshTrigger?.removeListener(_onRefreshTriggered);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterPosts() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredPosts = List.from(_posts);
      } else {
        _filteredPosts = _posts.where((post) {
          return post.text.toLowerCase().contains(query) ||
              post.author.displayName.toLowerCase().contains(query) ||
              post.author.username.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  /// Parses API count (may be int or double from JSON) to int. Always show when != 0.
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// Converts any Map (e.g. Map<dynamic, dynamic> from JSON) to Map<String, dynamic>.
  Map<String, dynamic>? _toPostMap(dynamic v) {
    if (v == null) return null;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  Post _mapBackendPostToFrontendPost(Map<String, dynamic> backendPost) {
    final authorFirstName = backendPost['author_first_name'] as String?;
    final authorLastName = backendPost['author_last_name'] as String?;
    final authorEmail = backendPost['author_email'] as String? ?? '';

    String displayName;
    if (authorFirstName != null && authorLastName != null) {
      displayName = '$authorFirstName $authorLastName';
    } else if (authorFirstName != null) {
      displayName = authorFirstName;
    } else {
      displayName = authorEmail.split('@').first;
    }

    final username = authorEmail.split('@').first;

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(backendPost['created_at'] as String);
    } catch (_) {
      createdAt = DateTime.now();
    }

    final diff = DateTime.now().difference(createdAt);
    final timestampLabel = diff.inMinutes < 1
        ? 'now'
        : diff.inHours < 1
            ? '${diff.inMinutes}m'
            : diff.inDays < 1
                ? '${diff.inHours}h'
                : '${diff.inDays}d';

    final text = backendPost['content'] as String? ?? '';
    // Backend uses snake_case; support both so counts and state always display after reload
    final likeCount = _toInt(backendPost['like_count'] ?? backendPost['likeCount']);
    final repostCount = _toInt(backendPost['repost_count'] ?? backendPost['repostCount']);
    final replyCount = _toInt(backendPost['reply_count'] ?? backendPost['replyCount']);
    final likedByCurrentUser = backendPost['liked_by_current_user'] == true || backendPost['likedByCurrentUser'] == true;
    final repostedByCurrentUser = backendPost['reposted_by_current_user'] == true || backendPost['repostedByCurrentUser'] == true;
    
    // Embedded repost: accept snake_case or camelCase; API layer deep-normalizes so this is Map<String, dynamic>.
    Post? repostedPost;
    final repostedMap = _toPostMap(backendPost['reposted_post']) ?? _toPostMap(backendPost['repostedPost']);
    if (repostedMap != null && repostedMap.isNotEmpty) {
      repostedPost = _mapBackendPostToFrontendPost(repostedMap);
    }

    return Post(
      id: backendPost['post_id'] as String? ?? '',
      author: PostAuthor(
        id: backendPost['user_id'] as String? ?? '',
        displayName: displayName,
        username: username,
        avatarUrl: null,
        isVerified: false, // TODO: Add verified status from backend if available
      ),
      text: text,
      createdAt: createdAt,
      timestampLabel: timestampLabel,
      likeCount: likeCount,
      replyCount: replyCount,
      repostCount: repostCount,
      likedByCurrentUser: likedByCurrentUser,
      repostedByCurrentUser: repostedByCurrentUser,
      repostedPost: repostedPost,
    );
  }

  Future<String?> _getOrCreateDefaultSubthread() async {
    if (_defaultSubthreadId != null) return _defaultSubthreadId;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      apiService.setToken(authProvider.session?.accessToken);

      final subthreads = await apiService.getSubthreads(limit: 10);

      Map<String, dynamic>? chosen;
      for (final s in subthreads) {
        final name = (s['name'] as String? ?? '').toLowerCase();
        if (name == 'general' || name == 'main' || name == 'all') {
          chosen = s;
          break;
        }
      }
      if (chosen == null && subthreads.isNotEmpty) {
        chosen = subthreads.first;
      }

      if (chosen != null) {
        _defaultSubthreadId = chosen['id'] as String?;
        return _defaultSubthreadId;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFeed() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Loading feed...');
      final subthreadId = await _getOrCreateDefaultSubthread();
      print('📌 Subthread ID: $subthreadId');
      
      if (!mounted) return;

      if (subthreadId == null) {
        print('⚠️ No subthread found, using mock posts');
        if (mounted) {
          setState(() {
            _posts.clear();
            _posts.addAll(_generateMockPosts());
            _filteredPosts = List.from(_posts);
            _isLoading = false;
          });
          print('✅ Loaded ${_posts.length} mock posts');
        }
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      apiService.setToken(authProvider.session?.accessToken);

      final postsData = await apiService.getPostsBySubthread(
        subthreadId,
        limit: 20,
        offset: 0,
      );

      if (mounted) {
        print('📥 Received ${postsData.length} posts from API');
        
        // Normalize so each post is Map<String, dynamic> (JSON can give Map<dynamic, dynamic>)
        final normalizedPosts = postsData
            .map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p))
            .toList();
        
        print('📥 Normalized ${normalizedPosts.length} posts');
        
        final posts = normalizedPosts
            .map((p) {
              try {
                return _mapBackendPostToFrontendPost(p);
              } catch (e) {
                print('⚠️ Error mapping post: $e');
                print('⚠️ Post data: $p');
                rethrow;
              }
            })
            .toList();
        
        print('✅ Mapped ${posts.length} posts successfully');
        
        setState(() {
          _posts.clear();
          _posts.addAll(posts);
          _filteredPosts = List.from(_posts);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    await _loadFeed();

    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _handleLike(Post post) async {
    // Optimistically update UI
    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        final currentPost = _posts[index];
        _posts[index] = currentPost.copyWith(
          likedByCurrentUser: !currentPost.likedByCurrentUser,
          likeCount: currentPost.likedByCurrentUser
              ? currentPost.likeCount - 1
              : currentPost.likeCount + 1,
        );
        // Update filtered posts to keep them in sync
        final filteredIndex = _filteredPosts.indexWhere((p) => p.id == post.id);
        if (filteredIndex != -1) {
          _filteredPosts[filteredIndex] = _posts[index];
        }
      }
    });

    // Call backend API
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      apiService.setToken(authProvider.session?.accessToken);

      final response = await apiService.toggleLike(post.id);
      
      // Update with actual response
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            _posts[index] = _posts[index].copyWith(
              likedByCurrentUser: response['liked'] as bool,
              likeCount: response['like_count'] as int,
            );
            final filteredIndex = _filteredPosts.indexWhere((p) => p.id == post.id);
            if (filteredIndex != -1) {
              _filteredPosts[filteredIndex] = _posts[index];
            }
          }
        });
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            final currentPost = _posts[index];
            _posts[index] = currentPost.copyWith(
              likedByCurrentUser: !currentPost.likedByCurrentUser,
              likeCount: currentPost.likedByCurrentUser
                  ? currentPost.likeCount + 1
                  : currentPost.likeCount - 1,
            );
            final filteredIndex = _filteredPosts.indexWhere((p) => p.id == post.id);
            if (filteredIndex != -1) {
              _filteredPosts[filteredIndex] = _posts[index];
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleRepost(Post post) async {
    // Get current subthread ID
    final subthreadId = await _getOrCreateDefaultSubthread();
    if (subthreadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to repost: No subthread available')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repost'),
        content: const Text('Create a repost of this thread?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Repost'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creating repost...')),
      );
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      apiService.setToken(authProvider.session?.accessToken);

      final repostData = await apiService.createRepost(
        postId: post.id,
        subthreadId: subthreadId,
      );

      // Map repost to Post model and add to feed
      if (mounted) {
        final repost = _mapBackendPostToFrontendPost(repostData);
        setState(() {
          _posts.insert(0, repost);
          _filteredPosts.insert(0, repost);
        });

        // Update original post repost count
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = _posts[index].copyWith(
            repostCount: _posts[index].repostCount + 1,
            repostedByCurrentUser: true,
          );
          final filteredIndex = _filteredPosts.indexWhere((p) => p.id == post.id);
          if (filteredIndex != -1) {
            _filteredPosts[filteredIndex] = _posts[index];
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repost created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create repost: ${e.toString()}')),
        );
      }
    }
  }

  void _handleReply(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reply functionality coming soon'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleShare(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handlePostTap(Post post) {
    setState(() {
      _expandedPostId = _expandedPostId == post.id ? null : post.id;
    });
  }

  void _handleMoreOptions(Post post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SyntrakColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete_outline, color: SyntrakColors.error),
                title: Text(
                  'Remove post',
                  style: SyntrakTypography.bodyLarge.copyWith(
                    color: SyntrakColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRemovePost(post);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemovePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove post'),
        content: const Text(
          'Are you sure you want to remove this post? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: SyntrakColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      apiService.setToken(authProvider.session?.accessToken);

      await apiService.deletePost(post.id);

      if (mounted) {
        setState(() {
          _posts.removeWhere((p) => p.id == post.id);
          _filteredPosts.removeWhere((p) => p.id == post.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove post: ${e.toString()}')),
        );
      }
    }
  }

  List<Post> _generateMockPosts() {
    final random = Random();
    final authors = [
      PostAuthor(id: '1', displayName: 'Alex Johnson', username: 'alexj', isVerified: true),
      PostAuthor(id: '2', displayName: 'Sarah Chen', username: 'sarahc', isVerified: false),
      PostAuthor(id: '3', displayName: 'Mike Davis', username: 'miked', isVerified: true),
      PostAuthor(id: '4', displayName: 'Emma Wilson', username: 'emmaw', isVerified: false),
    ];

    final messages = [
      'Just hit the slopes at Whistler! Fresh powder day ❄️🎿',
      'Anyone know if Park City has good snow conditions this week?',
      'New personal best on the black diamond run! 💪',
      'Looking for ski buddies in the Tahoe area this weekend.',
      'The views from the summit were incredible today 🏔️',
      'Finally landed my first 360! Months of practice paid off 🎉',
    ];

    return List.generate(6, (index) {
      final author = authors[random.nextInt(authors.length)];
      final hasReplies = random.nextBool();
      final replies = hasReplies
          ? List.generate(
              random.nextInt(2) + 1,
              (i) {
                final replyAuthor = authors[random.nextInt(authors.length)];
                return Post(
                  id: '${index}_reply_$i',
                  author: PostAuthor(
                    id: replyAuthor.id,
                    displayName: replyAuthor.displayName,
                    username: replyAuthor.username,
                    avatarUrl: replyAuthor.avatarUrl,
                    isVerified: replyAuthor.isVerified,
                  ),
                  text: 'Awesome! Keep shredding! 🤙',
                  createdAt: DateTime.now().subtract(Duration(hours: i)),
                  timestampLabel: '${i + 1}h',
                );
              },
            )
          : null;

      return Post(
        id: index.toString(),
        author: PostAuthor(
          id: author.id,
          displayName: author.displayName,
          username: author.username,
          avatarUrl: author.avatarUrl,
          isVerified: random.nextBool(), // Random verified status for mock data
        ),
        text: messages[index],
        createdAt: DateTime.now().subtract(Duration(hours: index)),
        timestampLabel: index == 0 ? 'now' : '${index}h',
        likeCount: random.nextInt(50),
        replyCount: replies?.length ?? 0,
        repostCount: random.nextInt(20),
        likedByCurrentUser: random.nextBool(),
        repostedByCurrentUser: false,
        replies: replies,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _posts.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(SyntrakColors.primary),
        ),
      );
    }

    return Column(
      children: [
        // Search bar - fixed at top
        _buildSearchBar(),
        // Content list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: SyntrakColors.primary,
            child: _filteredPosts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: SyntrakColors.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No posts yet',
                            style: SyntrakTypography.headlineSmall.copyWith(
                              color: SyntrakColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull down to refresh or create a new post',
                            style: SyntrakTypography.bodyMedium.copyWith(
                              color: SyntrakColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SyntrakSpacing.md,
                      vertical: SyntrakSpacing.sm,
                    ),
                    itemCount: _filteredPosts.length,
                    itemBuilder: (context, index) {
                      final post = _filteredPosts[index];
                      return ThreadCard(
                        post: post,
                        onTap: () => _handlePostTap(post),
                        onLike: _handleLike,
                        onRepost: _handleRepost,
                        onReply: _handleReply,
                        onShare: _handleShare,
                        onMoreOptions: _handleMoreOptions,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // Modern search bar at top
  Widget _buildSearchBar() {
    final hasText = _searchController.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: SyntrakColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: SyntrakSpacing.md,
        vertical: SyntrakSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SyntrakRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: 48,
          decoration: BoxDecoration(
            color: _isSearchFocused
                ? SyntrakColors.surface
                : SyntrakColors.surfaceVariant,
            borderRadius: BorderRadius.circular(SyntrakRadius.lg),
            border: Border.all(
              color: _isSearchFocused
                  ? SyntrakColors.primary
                  : SyntrakColors.divider,
              width: _isSearchFocused ? 1.5 : 1,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                fillColor: Colors.transparent,
                filled: false,
              ),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (_) => _filterPosts(),
              style: SyntrakTypography.bodyMedium.copyWith(
                color: SyntrakColors.textPrimary,
                height: 1.5, // Ensure consistent line height
              ),
              decoration: InputDecoration(
                hintText: 'Search threads...',
                hintStyle: SyntrakTypography.bodyMedium.copyWith(
                  color: SyntrakColors.textTertiary,
                  height: 1.5, // Match text line height
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Icon(
                    Icons.search_rounded,
                    color: _isSearchFocused
                        ? SyntrakColors.primary
                        : SyntrakColors.textTertiary,
                    size: 20,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 48,
                ),
                suffixIcon: hasText
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: SyntrakColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterPosts();
                          _searchFocusNode.unfocus();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SyntrakSpacing.md,
                  vertical: 14,
                ),
                isDense: false, // Changed to false for better alignment
              ),
              cursorColor: SyntrakColors.primary,
              showCursor: true,
            ),
          ),
        ),
      ),
    );
  }
}
