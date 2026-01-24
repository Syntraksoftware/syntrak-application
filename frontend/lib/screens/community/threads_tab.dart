import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syntrak/core/theme.dart';
import 'package:syntrak/providers/auth_provider.dart';
import 'package:syntrak/models/post.dart';
import 'package:syntrak/services/api_service.dart';
import 'package:syntrak/widgets/compact_composer.dart';
import 'package:syntrak/widgets/message_card.dart';

class ThreadsTab extends StatefulWidget {
  const ThreadsTab({super.key});

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

  @override
  void dispose() {
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

    return Post(
      id: backendPost['post_id'] as String? ?? '',
      author: PostAuthor(
        id: backendPost['user_id'] as String? ?? '',
        displayName: displayName,
        username: username,
        avatarUrl: null,
      ),
      text: text,
      createdAt: createdAt,
      timestampLabel: timestampLabel,
      likeCount: 0,
      replyCount: 0,
      repostCount: 0,
      likedByCurrentUser: false,
      repostedByCurrentUser: false,
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
      final subthreadId = await _getOrCreateDefaultSubthread();
      if (!mounted) return;

      if (subthreadId == null) {
        if (mounted) {
          setState(() {
            _posts.clear();
            _posts.addAll(_generateMockPosts());
            _filteredPosts = List.from(_posts);
            _isLoading = false;
          });
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
        final posts = postsData
            .map((p) => _mapBackendPostToFrontendPost(p))
            .toList();
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

  Future<void> _handlePost(String text) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to post')),
      );
      return;
    }

    final subthreadId = await _getOrCreateDefaultSubthread();
    if (!mounted) return;
    if (subthreadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No subthread available. Please try again later.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService();
      apiService.setToken(authProvider.session?.accessToken);

      final response = await apiService.createCommunityPost(
        subthreadId: subthreadId,
        title: text.length > 50 ? text.substring(0, 50) : text,
        content: text,
      );

      // Create response has no author_*; use current user for author.
      DateTime createdAt;
      try {
        createdAt = DateTime.parse(response['created_at'] as String);
      } catch (_) {
        createdAt = DateTime.now();
      }
      final newPost = Post(
        id: response['post_id'] as String? ?? '',
        author: PostAuthor(
          id: user.id,
          displayName: user.firstName != null && user.lastName != null
              ? '${user.firstName} ${user.lastName}'
              : user.email.split('@').first,
          username: user.email.split('@').first,
          avatarUrl: null,
        ),
        text: response['content'] as String? ?? text,
        createdAt: createdAt,
        timestampLabel: 'now',
        likeCount: 0,
        replyCount: 0,
        repostCount: 0,
        likedByCurrentUser: false,
        repostedByCurrentUser: false,
      );

      if (mounted) {
        setState(() {
          _posts.insert(0, newPost);
          _filteredPosts = List.from(_posts);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.toString()}')),
        );
      }
    }
  }

  void _handleLike(Post post) {
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
      }
    });
  }

  void _handleRepost(Post post) {
    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        final currentPost = _posts[index];
        _posts[index] = currentPost.copyWith(
          repostedByCurrentUser: !currentPost.repostedByCurrentUser,
          repostCount: currentPost.repostedByCurrentUser
              ? currentPost.repostCount - 1
              : currentPost.repostCount + 1,
        );
      }
    });
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

  List<Post> _generateMockPosts() {
    final random = Random();
    final authors = [
      PostAuthor(id: '1', displayName: 'Alex Johnson', username: 'alexj'),
      PostAuthor(id: '2', displayName: 'Sarah Chen', username: 'sarahc'),
      PostAuthor(id: '3', displayName: 'Mike Davis', username: 'miked'),
      PostAuthor(id: '4', displayName: 'Emma Wilson', username: 'emmaw'),
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
              (i) => Post(
                id: '${index}_reply_$i',
                author: authors[random.nextInt(authors.length)],
                text: 'Awesome! Keep shredding! 🤙',
                createdAt: DateTime.now().subtract(Duration(hours: i)),
                timestampLabel: '${i + 1}h',
              ),
            )
          : null;

      return Post(
        id: index.toString(),
        author: author,
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
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: SyntrakSpacing.md,
                vertical: SyntrakSpacing.sm,
              ),
              itemCount: _filteredPosts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: SyntrakSpacing.md),
                    child: CompactComposer(
                      onPost: _handlePost,
                      maxCharacters: 280,
                    ),
                  );
                }
                final post = _filteredPosts[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: SyntrakSpacing.sm),
                  child: MessageCard(
                    post: post,
                    isExpanded: _expandedPostId == post.id,
                    onTap: () => _handlePostTap(post),
                    onLike: _handleLike,
                    onRepost: _handleRepost,
                    onReply: _handleReply,
                    onShare: _handleShare,
                  ),
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
