import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/discord_gateway.dart';
import '../services/discord_service.dart';
import '../theme/discord_feedback_theme.dart';
import 'create_feedback_sheet.dart';
import 'discord_header.dart';
import 'forum_post_card.dart';
import 'forum_post_detail_screen.dart';
import 'sort_tag_bar.dart';
import 'theme_customizer_sheet.dart';

class ForumPostListScreen extends StatefulWidget {
  final DiscordService service;
  final String channelId;
  final String title;
  final bool enableRealtime;
  final String? appName;
  final DiscordFeedbackTheme theme;
  final ValueChanged<DiscordFeedbackTheme>? onThemeChanged;
  final Widget? leading;
  final Widget? channelIcon;
  final String? channelEmoji;

  const ForumPostListScreen({
    super.key,
    required this.service,
    required this.channelId,
    this.title = 'bug-and-suggestions',
    this.enableRealtime = false,
    this.appName,
    this.theme = DiscordFeedbackTheme.dark,
    this.onThemeChanged,
    this.leading,
    this.channelIcon,
    this.channelEmoji,
  });

  @override
  State<ForumPostListScreen> createState() => _ForumPostListScreenState();
}

class _ForumPostListScreenState extends State<ForumPostListScreen> {
  List<ForumThread> _threads = [];
  List<ForumTag> _availableTags = [];
  Set<String> _selectedTagIds = {};
  bool _isLoading = true;
  String? _error;

  SortBy _sortBy = SortBy.creationTime;
  SortOrder _sortOrder = SortOrder.newest;

  DiscordGateway? _gateway;
  final List<StreamSubscription> _subs = [];
  bool _realtimeConnected = false;

  late DiscordFeedbackTheme _currentTheme;
  DiscordFeedbackTheme get t => _currentTheme;

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.theme;
    _loadData();
    if (widget.enableRealtime) _initGateway();
  }

  @override
  void didUpdateWidget(covariant ForumPostListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      setState(() => _currentTheme = widget.theme);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _gateway?.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.service.getChannel(widget.channelId),
        widget.service.getForumPosts(channelId: widget.channelId),
      ]);
      if (!mounted) return;
      final channel = results[0] as ForumChannel;
      final threads = results[1] as List<ForumThread>;
      setState(() {
        _availableTags = channel.availableTags;
        _threads = threads;
        _isLoading = false;
      });
      _loadStarterMessages(threads);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStarterMessages(List<ForumThread> threads) async {
    for (final thread in threads) {
      if (thread.starterMessage != null) continue;
      widget.service.getStarterMessage(thread.id).then((msg) {
        if (!mounted || msg == null) return;
        setState(() {
          final i = _threads.indexWhere((t) => t.id == thread.id);
          if (i != -1) {
            _threads[i] = _threads[i].copyWith(starterMessage: msg);
          }
        });
      });
    }
  }

  void _initGateway() {
    _gateway = DiscordGateway(
      botToken: widget.service.botToken,
      channelId: widget.channelId,
    );
    _subs.addAll([
      _gateway!.onConnectionChanged.listen((c) {
        if (mounted) setState(() => _realtimeConnected = c);
      }),
      _gateway!.onThreadCreate.listen((thread) {
        if (!mounted) return;
        setState(() => _threads.insert(0, thread));
        _loadStarterMessages([thread]);
      }),
      _gateway!.onThreadUpdate.listen((thread) {
        if (!mounted) return;
        setState(() {
          final i = _threads.indexWhere((t) => t.id == thread.id);
          if (i != -1) {
            _threads[i] =
                thread.copyWith(starterMessage: _threads[i].starterMessage);
          }
        });
      }),
      _gateway!.onThreadDelete.listen((id) {
        if (!mounted) return;
        setState(() => _threads.removeWhere((t) => t.id == id));
      }),
    ]);
    _gateway!.connect();
  }

  List<ForumThread> get _filteredAndSorted {
    var list = _threads.toList();
    if (_selectedTagIds.isNotEmpty) {
      list = list
          .where(
              (t) => t.appliedTags.any((id) => _selectedTagIds.contains(id)))
          .toList();
    }
    list.sort((a, b) => _sortOrder == SortOrder.newest
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bgPrimary,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            DiscordHeader(
              theme: t,
              title: widget.title,
              realtimeConnected: _realtimeConnected,
              showRealtimeIndicator: widget.enableRealtime,
              leading: widget.leading,
              channelIcon: widget.channelIcon,
              channelEmoji: widget.channelEmoji,
              onBack: () => Navigator.maybePop(context),
              onThemeTap: _showThemeCustomizer,
            ),
            SortTagBar(
              theme: t,
              sortBy: _sortBy,
              sortOrder: _sortOrder,
              selectedTagIds: _selectedTagIds,
              availableTags: _availableTags,
              onSortByChanged: (v) => setState(() => _sortBy = v),
              onSortOrderChanged: (v) => setState(() => _sortOrder = v),
              onTagsChanged: (v) => setState(() => _selectedTagIds = v),
            ),
            Divider(height: 1, thickness: 1, color: t.dividerColor),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: _openCreateFeedback,
              backgroundColor: t.accent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded, size: 28),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, color: t.accent.withValues(alpha: 0.7)));
    }
    if (_error != null) return _errorView();

    final threads = _filteredAndSorted;
    if (threads.isEmpty) return _emptyView();

    final now = DateTime.now();
    final recent = <ForumThread>[];
    final older = <ForumThread>[];
    for (final thread in threads) {
      (now.difference(thread.createdAt).inDays > 7 ? older : recent)
          .add(thread);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: t.accent,
      backgroundColor: t.bgTertiary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 88),
        children: [
          ...recent.map(_card),
          if (older.isNotEmpty) ...[
            _sectionDivider('OLDER POSTS'),
            ...older.map(_card),
          ],
        ],
      ),
    );
  }

  Widget _card(ForumThread thread) {
    return ForumPostCard(
      thread: thread,
      availableTags: _availableTags,
      theme: t,
      onTap: () => _openDetail(thread),
    );
  }

  Widget _sectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: t.dividerColor, thickness: 1)),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: t.textMuted),
            const SizedBox(height: 16),
            Text('Không thể kết nối',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textMuted, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined,
              size: 56, color: t.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No posts yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: t.textSecondary)),
          const SizedBox(height: 6),
          Text(
            _selectedTagIds.isNotEmpty
                ? 'No posts match selected tags'
                : 'Be the first to post!',
            style: TextStyle(color: t.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _showThemeCustomizer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ThemeCustomizerSheet(
        currentTheme: _currentTheme,
        onThemeChanged: (newTheme) {
          setState(() => _currentTheme = newTheme);
          widget.onThemeChanged?.call(newTheme);
        },
      ),
    );
  }

  void _openCreateFeedback() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateFeedbackSheet(
        service: widget.service,
        channelId: widget.channelId,
        availableTags: _availableTags,
        theme: t,
        appName: widget.appName,
      ),
    );
    if (created == true) _loadData();
  }

  void _openDetail(ForumThread thread) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForumPostDetailScreen(
          service: widget.service,
          thread: thread,
          availableTags: _availableTags,
          theme: t,
          gateway: _gateway,
        ),
      ),
    ).then((_) => _loadData());
  }
}
