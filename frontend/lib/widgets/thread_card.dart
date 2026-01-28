import 'package:flutter/material.dart';
import 'package:syntrak/core/theme.dart';
import 'package:syntrak/models/post.dart';

/// Reusable thread card component matching social media feed design
/// All elements are left-aligned as per design requirements
class ThreadCard extends StatefulWidget {
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
  State<ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<ThreadCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
          onTap: widget.onAvatarTap,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: SyntrakColors.surfaceVariant,
            backgroundImage: widget.post.author.avatarUrl != null
                ? NetworkImage(widget.post.author.avatarUrl!)
                : null,
            child: widget.post.author.avatarUrl == null
                ? Text(
                    widget.post.author.displayName.isNotEmpty
                        ? widget.post.author.displayName[0].toUpperCase()
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
                widget.post.author.username,
                style: SyntrakTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SyntrakColors.textPrimary,
                ),
              ),
              if (widget.post.author.isVerified) ...[
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
          widget.post.timestampLabel,
          style: SyntrakTypography.bodySmall.copyWith(
            color: SyntrakColors.textTertiary,
          ),
        ),
        const SizedBox(width: 8),
        // More options icon
        GestureDetector(
          onTap: () => widget.onMoreOptions?.call(widget.post),
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
      child: Text(
        widget.post.text,
        style: SyntrakTypography.bodyLarge.copyWith(
          color: SyntrakColors.textPrimary,
          height: 1.4,
        ),
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
            icon: widget.post.likedByCurrentUser
                ? Icons.favorite
                : Icons.favorite_border,
            isActive: widget.post.likedByCurrentUser,
            onTap: () => widget.onLike?.call(widget.post),
          ),
          const SizedBox(width: 24),
          // Comment icon
          _buildActionIcon(
            icon: Icons.chat_bubble_outline,
            onTap: () => widget.onReply?.call(widget.post),
          ),
          const SizedBox(width: 24),
          // Repost icon
          _buildActionIcon(
            icon: Icons.repeat,
            isActive: widget.post.repostedByCurrentUser,
            onTap: () => widget.onRepost?.call(widget.post),
          ),
          const SizedBox(width: 24),
          // Bookmark icon
          _buildActionIcon(
            icon: Icons.bookmark_border,
            onTap: () => widget.onShare?.call(widget.post),
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
    // Only show if there are replies or likes
    if (widget.post.replyCount == 0 && widget.post.likeCount == 0) {
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
    if (widget.post.likeCount > 0) {
      avatars.add(_buildSmallAvatar(Icons.favorite, Colors.red));
    }
    
    // Add avatar for replies if there are any
    if (widget.post.replyCount > 0) {
      avatars.add(_buildSmallAvatar(Icons.chat_bubble_outline, SyntrakColors.primary));
    }

    if (avatars.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: avatars.asMap().entries.map((entry) {
        final index = entry.key;
        final avatar = entry.value;
        return Container(
          margin: EdgeInsets.only(
            right: index < avatars.length - 1 ? -8 : 0,
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
    if (widget.post.replyCount > 0) {
      parts.add('${widget.post.replyCount} ${widget.post.replyCount == 1 ? 'reply' : 'replies'}');
    }
    if (widget.post.likeCount > 0) {
      parts.add('${widget.post.likeCount} ${widget.post.likeCount == 1 ? 'like' : 'likes'}');
    }
    return parts.join(' · ');
  }
}
