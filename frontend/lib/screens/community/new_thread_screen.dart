import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syntrak/core/theme.dart';
import 'package:syntrak/providers/auth_provider.dart';
import 'package:syntrak/services/api_service.dart';

/// Full-screen composer for creating a new thread/post. Layout matches the
/// "New thread" reference: Cancel (single line), topic, body, media row,
/// Add to thread, Reply options + toggle + Post. Connects to community backend.
class NewThreadScreen extends StatefulWidget {
  final VoidCallback? onPostCreated;

  const NewThreadScreen({super.key, this.onPostCreated});

  @override
  State<NewThreadScreen> createState() => _NewThreadScreenState();
}

class _NewThreadScreenState extends State<NewThreadScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  bool _isPosting = false;
  bool _replyToggle = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<String?> _getDefaultSubthread() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final api = ApiService();
      api.setToken(auth.session?.accessToken);
      final list = await api.getSubthreads(limit: 10);
      for (final s in list) {
        final name = (s['name'] as String? ?? '').toLowerCase();
        if (name == 'general' || name == 'main' || name == 'all') {
          return s['id'] as String?;
        }
      }
      if (list.isNotEmpty) return list.first['id'] as String?;
    } catch (_) {}
    return null;
  }

  bool get _canPost {
    return _bodyController.text.trim().isNotEmpty && !_isPosting;
  }

  Future<void> _post() async {
    if (!_canPost) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to post')),
        );
      }
      return;
    }

    final subthreadId = await _getDefaultSubthread();
    if (!mounted) return;
    if (subthreadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No subthread available. Please try again later.')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final api = ApiService();
      api.setToken(auth.session?.accessToken);
      final title = _titleController.text.trim();
      final content = _bodyController.text.trim();
      await api.createCommunityPost(
        subthreadId: subthreadId,
        title: title.isEmpty
            ? (content.length > 50 ? content.substring(0, 50) : content)
            : title,
        content: content,
      );
      if (!mounted) return;
      widget.onPostCreated?.call();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final username = user?.email.split('@').first ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SyntrakColors.darkBackground : SyntrakColors.background;
    final surface = isDark ? SyntrakColors.darkSurface : SyntrakColors.surface;
    final onSurf =
        isDark ? SyntrakColors.darkTextPrimary : SyntrakColors.textPrimary;
    final muted =
        isDark ? SyntrakColors.darkTextSecondary : SyntrakColors.textTertiary;

    // Cancel: single line, plain text, no wrap. Use leadingWidth + minimal leading.
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  child: Text(
                    'Cancel',
                    style: SyntrakTypography.bodyLarge.copyWith(
                      color: onSurf,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'New thread',
          style: SyntrakTypography.headlineSmall.copyWith(
            color: onSurf,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: surface,
        foregroundColor: onSurf,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            onPressed: () {},
            iconSize: 22,
            color: onSurf,
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
            iconSize: 22,
            color: onSurf,
          ),
        ],
      ),
      body: Listener(
        onPointerDown: (_) => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: SyntrakSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // —— Composer: avatar | thread line | username > Add a topic + What's new?
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + short vertical line
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: muted.withAlpha(100),
                        child: user?.firstName != null &&
                                user!.firstName!.isNotEmpty
                            ? Text(
                                user.firstName![0].toUpperCase(),
                                style: TextStyle(
                                  color: onSurf,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              )
                            : Icon(Icons.person, color: muted, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 2,
                        height: 32,
                        color: muted.withAlpha(100),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Topic + body
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // username > Add a topic (one line)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              username.isNotEmpty ? '$username > ' : '',
                              style: SyntrakTypography.bodyLarge.copyWith(
                                color: onSurf,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _titleController,
                                onChanged: (_) => setState(() {}),
                                maxLines: 1,
                                style: SyntrakTypography.bodyLarge.copyWith(
                                  color: onSurf,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Add a topic',
                                  hintStyle: SyntrakTypography.bodyLarge
                                      .copyWith(color: muted),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _bodyController,
                          onChanged: (_) => setState(() {}),
                          maxLines: 6,
                          minLines: 2,
                          style: SyntrakTypography.bodyLarge.copyWith(
                            color: onSurf,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: "What's new?",
                            hintStyle: SyntrakTypography.bodyLarge.copyWith(
                              color: muted,
                              height: 1.4,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // —— Media row: Image, GIF, List, Quote, More
              Row(
                children: [
                  _MediaIcon(
                      icon: Icons.image_outlined,
                      onTap: () => _snack('Image upload coming soon')),
                  const SizedBox(width: 2),
                  _MediaIcon(
                      icon: Icons.gif_outlined,
                      label: 'GIF',
                      onTap: () => _snack('GIF picker coming soon')),
                  const SizedBox(width: 2),
                  _MediaIcon(
                      icon: Icons.format_list_bulleted,
                      onTap: () => _snack('Lists coming soon')),
                  const SizedBox(width: 2),
                  _MediaIcon(
                      icon: Icons.format_quote_outlined,
                      onTap: () => _snack('Quote coming soon')),
                  const SizedBox(width: 2),
                  _MediaIcon(
                      icon: Icons.more_horiz,
                      onTap: () => _snack('More options coming soon')),
                ],
              ),
              const SizedBox(height: 12),
              // —— Add to thread (small line + person icon + text)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _snack('Add to thread coming soon'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 2,
                          height: 20,
                          color: muted.withAlpha(80),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.person_outline, size: 18, color: muted),
                        const SizedBox(width: 8),
                        Text(
                          'Add to thread',
                          style: SyntrakTypography.bodyMedium
                              .copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // —— Bottom: Reply options | Toggle | Post
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 18, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    'Reply options',
                    style: SyntrakTypography.labelMedium.copyWith(color: muted),
                  ),
                  const Spacer(),
                  Icon(Icons.person_outline, size: 18, color: muted),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 28,
                    child: Switch.adaptive(
                      value: _replyToggle,
                      onChanged: (v) => setState(() => _replyToggle = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _canPost ? _post : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SyntrakColors.primary,
                        disabledBackgroundColor: muted.withAlpha(120),
                        foregroundColor: SyntrakColors.textOnPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: _isPosting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: SyntrakColors.textOnPrimary,
                              ),
                            )
                          : const Text('Post'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _MediaIcon extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const _MediaIcon({required this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c =
        isDark ? SyntrakColors.darkTextSecondary : SyntrakColors.textTertiary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: label != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: c),
                    const SizedBox(width: 4),
                    Text(
                      label!,
                      style: SyntrakTypography.labelMedium.copyWith(color: c),
                    ),
                  ],
                )
              : Icon(icon, size: 22, color: c),
        ),
      ),
    );
  }
}
