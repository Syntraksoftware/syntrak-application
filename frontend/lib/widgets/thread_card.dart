import 'package:flutter/material.dart';
import 'package:syntrak/core/theme.dart';
import 'package:syntrak/models/post.dart';

/// Reusable thread card component matching social media feed design
/// All elements are left-aligned as per design requirements
class ThreadCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;
  final Function(Post post)? onLike;
  final Function(Post post)? onRepost;
  final Function(Post post)? onReply;
  final Function(Post post)? onShare;
  final Function(Post post)? onMoreOptions;

  const ThreadCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAvatarTap,
    this.onLike,
    this.onRepost,
    this.onReply,
    this.onShare,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: SyntrakColors.surface,
          border: Border(
            bottom: BorderSide(
              color: SyntrakColors.divider,
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Profile picture, username, verified badge, timestamp, more options
            _buildHeader(),
            const SizedBox(height: 0),
            // Content: Post text
            _buildContent(),
            const SizedBox(height: 9),
            // Engagement: Action icons
            _buildActions(),
            const SizedBox(height: 9),
            // Interaction summary: Profile pictures + reply/like counts
            _buildInteractionSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Profile picture
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: SyntrakColors.surfaceVariant,
            backgroundImage: post.author.avatarUrl != null
                ? NetworkImage(post.author.avatarUrl!)
                : null,
            child: post.author.avatarUrl == null
                ? Text(
                    post.author.displayName.isNotEmpty
                        ? post.author.displayName[0].toUpperCase()
                        : '?',
                    style: SyntrakTypography.bodyMedium.copyWith(
                      color: SyntrakColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        // Username with verified badge
        Expanded(
          child: Row(
            children: [
              Text(
                post.author.username,
                style: SyntrakTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SyntrakColors.textPrimary,
                ),
              ),
              if (post.author.isVerified) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.verified,
                  size: 16,
                  color: SyntrakColors.primary,
                ),
              ],
            ],
          ),
        ),
        // Timestamp
        Text(
          post.timestampLabel,
          style: SyntrakTypography.bodySmall.copyWith(
            color: SyntrakColors.textTertiary,
          ),
        ),
        const SizedBox(width: 8),
        // More options icon
        GestureDetector(
          onTap: () => onMoreOptions?.call(post),
          child: Icon(
            Icons.more_horiz,
            size: 20,
            color: SyntrakColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.only(left: 52), // Align with username (avatar 40px + spacing 12px)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main post content
          if (post.text.isNotEmpty)
            Text(
              post.text,
              style: SyntrakTypography.bodyLarge.copyWith(
                color: SyntrakColors.textPrimary,
                height: 1.4,
              ),
            ),
          // Embedded reposted post
          if (post.repostedPost != null) ...[
            if (post.text.isNotEmpty) const SizedBox(height: 12),
            _buildRepostedPost(post.repostedPost!),
          ],
        ],
      ),
    );
  }

  Widget _buildRepostedPost(Post repostedPost) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SyntrakColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SyntrakColors.divider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reposted post header
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: SyntrakColors.surface,
                backgroundImage: repostedPost.author.avatarUrl != null
                    ? NetworkImage(repostedPost.author.avatarUrl!)
                    : null,
                child: repostedPost.author.avatarUrl == null
                    ? Text(
                        repostedPost.author.displayName.isNotEmpty
                            ? repostedPost.author.displayName[0].toUpperCase()
                            : '?',
                        style: SyntrakTypography.bodySmall.copyWith(
                          color: SyntrakColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                repostedPost.author.username,
                style: SyntrakTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SyntrakColors.textPrimary,
                ),
              ),
              if (repostedPost.author.isVerified) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.verified,
                  size: 12,
                  color: SyntrakColors.primary,
                ),
              ],
              const Spacer(),
              Text(
                repostedPost.timestampLabel,
                style: SyntrakTypography.bodySmall.copyWith(
                  color: SyntrakColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reposted post content
          Text(
            repostedPost.text,
            style: SyntrakTypography.bodyMedium.copyWith(
              color: SyntrakColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.only(left: 52), // Align with content
      child: Row(
        children: [
          // Heart icon
          _buildActionIcon(
            icon: post.likedByCurrentUser
                ? Icons.favorite
                : Icons.favorite_border,
            isActive: post.likedByCurrentUser,
            onTap: () => onLike?.call(post),
          ),
          const SizedBox(width: 24),
          // Comment icon
          _buildActionIcon(
            icon: Icons.chat_bubble_outline,
            onTap: () => onReply?.call(post),
          ),
          const SizedBox(width: 24),
          // Repost icon
          _buildActionIcon(
            icon: Icons.repeat,
            isActive: post.repostedByCurrentUser,
            onTap: () => onRepost?.call(post),
          ),
          const SizedBox(width: 24),
          // Bookmark icon
          _buildActionIcon(
            icon: Icons.bookmark_border,
            onTap: () => onShare?.call(post),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        icon,
        size: 22,
        color: isActive
            ? (icon == Icons.favorite
                ? Colors.red
                : SyntrakColors.primary)
            : SyntrakColors.textTertiary,
      ),
    );
  }

  Widget _buildInteractionSummary() {
    // Always show when any count is not zero (persists after reload from backend)
    if (post.replyCount == 0 && post.likeCount == 0 && post.repostCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 52), // Align with content
      child: Row(
        children: [
          // Small profile picture placeholders for users who interacted
          // In a real implementation, these would be actual user avatars
          _buildInteractionAvatars(),
          const SizedBox(width: 8),
          // Reply and like counts
          Text(
            _buildInteractionText(),
            style: SyntrakTypography.bodySmall.copyWith(
              color: SyntrakColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionAvatars() {
    final avatars = <Widget>[];
    
    // Add avatar for likes if there are any
    if (post.likeCount > 0) {
      avatars.add(_buildSmallAvatar(Icons.favorite, Colors.red));
    }
    
    // Add avatar for replies if there are any
    if (post.replyCount > 0) {
      avatars.add(_buildSmallAvatar(Icons.chat_bubble_outline, SyntrakColors.primary));
    }
    
    // Add avatar for reposts if there are any
    if (post.repostCount > 0) {
      avatars.add(_buildSmallAvatar(Icons.repeat, SyntrakColors.primary));
    }

    if (avatars.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: avatars.asMap().entries.map((entry) {
        final index = entry.key;
        final avatar = entry.value;
        return Container(
          margin: EdgeInsets.only(
            right: index < avatars.length - 1 ? 4 : 0,
          ),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: SyntrakColors.surface,
              width: 1.5,
            ),
          ),
          child: avatar,
        );
      }).toList(),
    );
  }

  Widget _buildSmallAvatar(IconData icon, Color color) {
    return CircleAvatar(
      radius: 8,
      backgroundColor: color.withOpacity(0.1),
      child: Icon(
        icon,
        size: 10,
        color: color,
      ),
    );
  }

  String _buildInteractionText() {
    final parts = <String>[];
    if (post.replyCount > 0) {
      parts.add('${post.replyCount} ${post.replyCount == 1 ? 'reply' : 'replies'}');
    }
    if (post.likeCount > 0) {
      parts.add('${post.likeCount} ${post.likeCount == 1 ? 'like' : 'likes'}');
    }
    if (post.repostCount > 0) {
      parts.add('${post.repostCount} ${post.repostCount == 1 ? 'repost' : 'reposts'}');
    }
    return parts.join(' · ');
  }
}
