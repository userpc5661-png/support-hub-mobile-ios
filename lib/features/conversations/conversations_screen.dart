import '../../core/localization/app_locale_controller.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/notifications/browser_notification_service.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/support_hub_design.dart';
import '../../core/theme/chat_appearance_controller.dart';
import '../../core/theme/theme_contrast_validator.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/widgets/support_hub_widgets.dart';
import '../auth/user_model.dart';
import '../employees/employee_model.dart';
import 'conversation_model.dart';
import 'conversation_service.dart';
import 'conversation_realtime_client.dart';
import 'conversation_collaboration_model.dart';
import 'message_media.dart';
import '../settings/chat_appearance_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    required this.api,
    required this.user,
    required this.manualConversationsEnabled,
    required this.aiEnabled,
    this.realtime,
    this.initialConversationId,
  });
  final ApiClient api;
  final UserModel user;
  final bool manualConversationsEnabled;
  final bool aiEnabled;
  final ConversationRealtimeClient? realtime;
  final String? initialConversationId;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late final ConversationService service;
  final search = TextEditingController();
  Timer? debounce;
  Timer? refreshTimer;
  Timer? realtimeDebounce;
  StreamSubscription<Map<String, dynamic>>? realtimeSubscription;
  StreamSubscription<ConversationModel>? cacheSubscription;
  late final ConversationRealtimeClient realtime;
  late final bool ownsRealtime;
  final notifications = BrowserNotificationService();
  List<ConversationModel> items = const [];
  bool loading = true;
  String? error;
  String filter = '';
  String inbox = 'all';
  String tagFilter = '';
  bool unreadOnly = false;
  bool assignedToMe = false;
  bool followUpDue = false;
  String? selectedId;
  bool firstLoadComplete = false;
  bool refreshing = false;
  bool mobileSearchVisible = false;

  bool get canReply => widget.user.hasPermission('conversations.reply');
  bool get canCreateManual => canReply && widget.manualConversationsEnabled;

  @override
  void initState() {
    super.initState();
    service = ConversationService(widget.api);
    ownsRealtime = widget.realtime == null;
    realtime = widget.realtime ?? ConversationRealtimeClient(widget.api);
    selectedId = widget.initialConversationId;
    cacheSubscription = ChatCache.changes.listen(_handleCachedConversation);
    realtimeSubscription = realtime.events.listen((event) {
      final type = event['type']?.toString();
      if (type != 'heartbeat' && type != 'connected') {
        realtimeDebounce?.cancel();
        realtimeDebounce =
            Timer(const Duration(milliseconds: 300), () => _load(silent: true));
      }
    });
    if (ownsRealtime) realtime.start();
    _load();
    refreshTimer =
        Timer.periodic(const Duration(seconds: 45), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    search.dispose();
    debounce?.cancel();
    refreshTimer?.cancel();
    realtimeDebounce?.cancel();
    realtimeSubscription?.cancel();
    cacheSubscription?.cancel();
    if (ownsRealtime) realtime.dispose();
    super.dispose();
  }

  void _handleCachedConversation(ConversationModel item) {
    if (!mounted || search.text.trim().isNotEmpty || filter.isNotEmpty) return;
    final belongsHere = inbox == 'closed'
        ? item.status == 'closed'
        : inbox == 'all' && item.status != 'closed';
    if (!belongsHere) return;
    setState(() {
      items = [item, ...items.where((value) => value.id != item.id)];
    });
  }

  Future<void> _load({bool keepSelection = true, bool silent = false}) async {
    if (refreshing) return;
    refreshing = true;
    final cacheKey =
        '$inbox:$filter:$tagFilter:$unreadOnly:$assignedToMe:$followUpDue:${search.text}';
    if (!silent && items.isEmpty) {
      final cached = ChatCache.getList(cacheKey);
      if (cached != null) items = cached;
    }
    if (!silent && mounted) {
      setState(() {
        loading = items.isEmpty;
        error = null;
      });
    }
    final previousUnread = {
      for (final item in items) item.id: item.unreadCount
    };
    try {
      final fresh = await service.list(
        status: filter.isEmpty ? null : filter,
        search: search.text,
        tag: tagFilter,
        unreadOnly: unreadOnly,
        assignedToMe: assignedToMe,
        followUpDue: followUpDue,
        inbox: inbox,
      );
      ChatCache.setList(cacheKey, fresh);
      if (firstLoadComplete) {
        for (final item in fresh) {
          final before = previousUnread[item.id] ?? 0;
          if (item.unreadCount > before) {
            notifications.show(
              title: tr('رسالة جديدة من ${item.customer.name}'),
              body: item.lastMessagePreview ?? tr('لديك رسالة جديدة في Wasl'),
              tag: 'conversation-${item.id}',
            );
          }
        }
      }
      items = fresh;
      firstLoadComplete = true;
      if (!keepSelection) {
        selectedId = null;
      } else if (widget.initialConversationId == null &&
          selectedId != null &&
          !items.any((item) => item.id == selectedId)) {
        selectedId = null;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  void _toggleAssignedToMe() {
    setState(() {
      if (inbox == 'mine') {
        inbox = 'all';
        assignedToMe = false;
      } else {
        inbox = 'mine';
        assignedToMe = false;
      }
      filter = '';
      unreadOnly = false;
      followUpDue = false;
    });
    _load(keepSelection: false);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    if (compact && selectedId != null && widget.initialConversationId != null) {
      return Scaffold(
        backgroundColor: context.hubScheme.surface,
        body: ConversationDetailPane(
          api: widget.api,
          user: widget.user,
          conversationId: selectedId!,
          initial: ChatCache.get(selectedId!),
          onChanged: _load,
          aiEnabled: widget.aiEnabled,
          realtime: realtime,
        ),
      );
    }
    if (compact) return _buildMobileInbox(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('صندوق الدردشات')),
        actions: [
          AnimatedBuilder(
            animation: realtime,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Chip(
                avatar: Icon(
                  realtime.state == RealtimeConnectionState.connected
                      ? Icons.bolt
                      : Icons.sync,
                  size: 17,
                  color: realtime.state == RealtimeConnectionState.connected
                      ? Colors.green
                      : null,
                ),
                label: Text(realtime.state == RealtimeConnectionState.connected
                    ? tr('مباشر')
                    : tr('إعادة اتصال')),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          if (notifications.isSupported)
            IconButton(
              onPressed: _enableNotifications,
              icon: Icon(notifications.isGranted
                  ? Icons.notifications_active
                  : Icons.notifications_outlined),
              tooltip: tr('تفعيل إشعارات المتصفح'),
            ),
          if (canCreateManual)
            IconButton(
                onPressed: _createConversation,
                icon: const Icon(Icons.add_comment),
                tooltip: tr('دردشة يدوية جديدة')),
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: tr('تحديث')),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          if (!wide) return _listPane(false);
          return Row(
            children: [
              SizedBox(width: 390, child: _listPane(true)),
              const VerticalDivider(width: 1),
              Expanded(
                child: selectedId == null
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.forum_outlined, size: 70),
                        SizedBox(height: 12),
                        Text(tr('اختر دردشة من القائمة'))
                      ]))
                    : ConversationDetailPane(
                        key: ValueKey(selectedId),
                        api: widget.api,
                        user: widget.user,
                        conversationId: selectedId!,
                        onChanged: _load,
                        aiEnabled: widget.aiEnabled,
                        realtime: realtime,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileInbox(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = context.hubScheme.surface;
    final background = context.hubScheme.surfaceContainerLowest;
    final accent = context.hubScheme.primary;
    final border = context.hubScheme.outlineVariant.withValues(alpha: .38);

    return Scaffold(
      backgroundColor: background,
      floatingActionButton: canCreateManual
          ? FloatingActionButton(
              onPressed: _createConversation,
              tooltip: tr('دردشة جديدة'),
              backgroundColor: accent,
              foregroundColor: ThemeContrastValidator.readableText(accent),
              child: const Icon(Icons.add_comment_rounded),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 12),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: realtime,
                    builder: (_, __) => HubAvatar(
                      name: widget.user.name,
                      imageUrl: widget.user.avatarUrl,
                      api: widget.api,
                      size: 48,
                      online:
                          realtime.state == RealtimeConnectionState.connected,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('الدردشات'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.hubScheme.onSurface,
                        fontSize: 23,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _InboxSquareButton(
                    icon: inbox == 'mine'
                        ? Icons.check_box_rounded
                        : Icons.check_box_outlined,
                    selected: inbox == 'mine',
                    tooltip: tr('مسندة إليّ'),
                    onPressed: _toggleAssignedToMe,
                  ),
                  const SizedBox(width: 8),
                  _InboxSquareButton(
                    icon: Icons.filter_list_rounded,
                    selected:
                        unreadOnly || followUpDue || inbox == 'unassigned',
                    tooltip: tr('تصفية'),
                    onPressed: _showMobileFilters,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 18, 10),
              child: TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: tr('البحث في المحادثات'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr('مسح'),
                          onPressed: () {
                            search.clear();
                            setState(() {});
                            _load(keepSelection: false);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  setState(() {});
                  debounce?.cancel();
                  debounce = Timer(
                    const Duration(milliseconds: 350),
                    () => _load(keepSelection: false),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _ReferenceInboxTab(
                      selected: inbox != 'closed',
                      label: tr('الدردشات'),
                      onTap: () => _selectMobileInbox('all'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReferenceInboxTab(
                      selected: inbox == 'closed',
                      label: tr('الملغاة'),
                      onTap: () => _selectMobileInbox('closed'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _mobileConversationList()),
          ],
        ),
      ),
    );
  }

  Widget _mobileConversationList() {
    if (loading) return const _ChatListSkeleton();
    if (error != null) {
      return HubEmptyState(
        icon: Icons.cloud_off_rounded,
        title: tr('تعذر تحميل الدردشات'),
        body: error!,
        action:
            FilledButton(onPressed: _load, child: Text(tr('إعادة المحاولة'))),
      );
    }
    if (items.isEmpty) {
      return HubEmptyState(
        icon: inbox == 'closed'
            ? Icons.inventory_2_outlined
            : Icons.chat_bubble_outline_rounded,
        title: inbox == 'closed'
            ? tr('لا توجد دردشات مغلقة')
            : tr('لا توجد دردشات هنا'),
        body: inbox == 'mine'
            ? tr('الدردشات التي تستلمها ستظهر في هذا القسم.')
            : tr('ستظهر الرسائل الجديدة هنا فور وصولها.'),
      );
    }

    final accent = context.hubScheme.primary;
    final surface = context.hubScheme.surface;
    final divider = context.hubScheme.outlineVariant.withValues(alpha: .26);
    final isArabic = AppLocaleController.isArabic;
    return RefreshIndicator(
      onRefresh: _load,
      color: accent,
      child: Material(
        color: surface,
        child: ListView.separated(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 112),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 1,
            indent: isArabic ? 14 : 78,
            endIndent: isArabic ? 78 : 14,
            color: divider,
          ),
          itemBuilder: (_, index) {
            final item = items[index];
            final hasUnread = item.unreadCount > 0;
            final followUp = item.followUpAt;
            final visibleTags = item.tags.take(2).toList();
            return InkWell(
              onTap: () => _open(item.id, false),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 13, 10, 13),
                child: Directionality(
                  textDirection:
                      isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          HubAvatar(
                            name: item.customer.name,
                            imageUrl: item.customer.avatarUrl,
                            api: widget.api,
                            size: 53,
                          ),
                          if (hasUnread)
                            PositionedDirectional(
                              end: -4,
                              bottom: -3,
                              child: Container(
                                constraints: const BoxConstraints(
                                    minWidth: 21, minHeight: 21),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: surface, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.unreadCount > 99
                                      ? '99+'
                                      : '${item.unreadCount}',
                                  style: TextStyle(
                                    color: ThemeContrastValidator.readableText(
                                        accent),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.customer.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.hubScheme.onSurface,
                                      fontSize: 16.5,
                                      height: 1.18,
                                      fontWeight: hasUnread
                                          ? FontWeight.w900
                                          : FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _conversationTime(item.lastMessageAt),
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    color: hasUnread
                                        ? accent
                                        : context.hubScheme.onSurfaceVariant,
                                    fontSize: 11.8,
                                    fontWeight: hasUnread
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (item.channel == 'whatsapp') ...[
                                  Icon(Icons.chat_bubble_outline_rounded,
                                      size: 14,
                                      color:
                                          context.hubScheme.onSurfaceVariant),
                                  const SizedBox(width: 5),
                                ],
                                Expanded(
                                  child: Text(
                                    item.lastMessagePreview ?? tr('بدون رسائل'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.hubScheme.onSurfaceVariant,
                                      fontSize: 13.7,
                                      height: 1.3,
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.assignedToName?.isNotEmpty == true ||
                                visibleTags.isNotEmpty ||
                                followUp != null) ...[
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 6,
                                runSpacing: 5,
                                children: [
                                  if (item.assignedToName?.isNotEmpty == true)
                                    _ConversationMetaChip(
                                      icon: Icons.person_outline_rounded,
                                      label: item.assignedToName!,
                                    ),
                                  for (final tag in visibleTags)
                                    _ConversationMetaChip(
                                      icon: Icons.sell_outlined,
                                      label: tag,
                                      accent: accent,
                                    ),
                                  if (followUp != null)
                                    _ConversationMetaChip(
                                      icon: Icons.alarm_outlined,
                                      label: item.followUpNote
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? item.followUpNote!.trim()
                                          : _formatDate(followUp),
                                      accent: context.hubColors.warning,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showMobileFilters() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  tr('تصفية'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                trailing: (unreadOnly || assignedToMe || followUpDue)
                    ? TextButton(
                        onPressed: () => Navigator.pop(sheetContext, 'reset'),
                        child: Text(tr('إعادة الضبط')),
                      )
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.all_inbox_outlined),
                title: Text(tr('الكل')),
                trailing: inbox == 'all' &&
                        !unreadOnly &&
                        !assignedToMe &&
                        !followUpDue
                    ? Icon(Icons.check_rounded,
                        color: context.hubScheme.secondary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'all'),
              ),
              ListTile(
                leading: const Icon(Icons.inbox_rounded),
                title: Text(tr('غير مسندة')),
                trailing: inbox == 'unassigned'
                    ? Icon(Icons.check_rounded,
                        color: context.hubScheme.secondary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'unassigned'),
              ),
              ListTile(
                leading: const Icon(Icons.person_pin_outlined),
                title: Text(tr('مسندة لي')),
                trailing: inbox == 'mine'
                    ? Icon(Icons.check_rounded,
                        color: context.hubScheme.secondary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'mine'),
              ),
              ListTile(
                leading: const Icon(Icons.mark_chat_unread_outlined),
                title: Text(tr('غير المقروءة')),
                trailing: unreadOnly
                    ? Icon(Icons.check_rounded,
                        color: context.hubScheme.secondary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'unread'),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: Text(tr('متابعة مستحقة')),
                trailing: followUpDue
                    ? Icon(Icons.check_rounded,
                        color: context.hubScheme.secondary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'follow_up'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    filter = '';
    tagFilter = '';
    unreadOnly = selected == 'unread';
    assignedToMe = false;
    followUpDue = selected == 'follow_up';
    inbox = switch (selected) {
      'unassigned' => 'unassigned',
      'mine' => 'mine',
      _ => 'all',
    };
    await _load(keepSelection: false);
  }

  void _selectMobileInbox(String value) {
    inbox = value;
    filter = '';
    unreadOnly = false;
    assignedToMe = false;
    followUpDue = false;
    _load(keepSelection: false);
  }

  String _conversationTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute ${local.hour >= 12 ? tr('م') : tr('ص')}';
    }
    return '${local.day}/${local.month}';
  }

  Widget _listPane(bool wide) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (canCreateManual) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _createConversation,
                    icon: const Icon(Icons.add_comment),
                    label: Text(tr('بدء دردشة يدوية جديدة')),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: search,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: tr('البحث داخل الدردشات والرسائل')),
                onChanged: (_) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 350), _load);
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilterChip(
                    selected: inbox == 'unassigned',
                    label: Text(tr('غير مسندة')),
                    avatar: const Icon(Icons.inbox_rounded, size: 18),
                    onSelected: (_) => _selectInbox('unassigned'),
                  ),
                  FilterChip(
                    selected: inbox == 'mine',
                    label: Text(tr('مسندة لي')),
                    avatar: const Icon(Icons.person_pin_outlined, size: 18),
                    onSelected: (_) => _selectInbox('mine'),
                  ),
                  FilterChip(
                    selected: inbox == 'closed',
                    label: Text(tr('المغلقة')),
                    avatar: const Icon(Icons.archive_outlined, size: 18),
                    onSelected: (_) => _selectInbox('closed'),
                  ),
                  if (widget.user.role == 'store_owner' ||
                      widget.user.role == 'store_admin' ||
                      widget.user.role == 'supervisor')
                    FilterChip(
                      selected: inbox == 'all',
                      label: Text(tr('الكل')),
                      avatar: const Icon(Icons.all_inbox_outlined, size: 18),
                      onSelected: (_) => _selectInbox('all'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? ListView(children: [
                      const SizedBox(height: 100),
                      Text(error!, textAlign: TextAlign.center)
                    ])
                  : items.isEmpty
                      ? ListView(children: [
                          SizedBox(height: 120),
                          Center(child: Text(tr('لا توجد دردشات مطابقة.')))
                        ])
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, index) {
                              final item = items[index];
                              return Card(
                                color: wide && selectedId == item.id
                                    ? Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                    : null,
                                child: ListTile(
                                  onTap: () => _open(item.id, wide),
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                          child: Text(item.customer.name.isEmpty
                                              ? '?'
                                              : item.customer.name
                                                  .substring(0, 1))),
                                      if (item.channel == 'whatsapp')
                                        const Positioned(
                                            bottom: -4,
                                            left: -4,
                                            child: CircleAvatar(
                                                radius: 10,
                                                child: Icon(Icons.phone,
                                                    size: 12))),
                                    ],
                                  ),
                                  title: Row(children: [
                                    Expanded(
                                        child: Text(item.customer.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                    if (item.unreadCount > 0)
                                      Badge(label: Text('${item.unreadCount}')),
                                  ]),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          item.lastMessagePreview ??
                                              tr('بدون رسائل'),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 5,
                                        children: [
                                          _MiniChip(_statusLabel(item.status)),
                                          if (item.priority != 'normal')
                                            _MiniChip(
                                                _priorityLabel(item.priority)),
                                          if (item.assignedToName != null)
                                            _MiniChip(item.assignedToName!),
                                          ...item.tags
                                              .take(2)
                                              .map(_MiniChip.new),
                                          if (item.followUpAt != null)
                                            _MiniChip(tr(
                                                'متابعة ${_formatDate(item.followUpAt!)}')),
                                        ],
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  void _selectInbox(String value) {
    inbox = value;
    filter = '';
    tagFilter = '';
    unreadOnly = false;
    assignedToMe = false;
    followUpDue = false;
    _load(keepSelection: false);
  }

  Future<void> _enableNotifications() async {
    final granted = await notifications.requestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(granted
          ? tr('تم تفعيل إشعارات المتصفح للرسائل الجديدة.')
          : tr(
              'لم يتم السماح بإشعارات المتصفح. يمكنك تفعيلها من إعدادات الموقع.')),
    ));
    setState(() {});
  }

  void _open(String id, bool wide) {
    if (wide) {
      setState(() => selectedId = id);
    } else {
      final initial =
          items.where((item) => item.id == id).firstOrNull ?? ChatCache.get(id);
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          backgroundColor: context.hubScheme.surface,
          body: ConversationDetailPane(
            api: widget.api,
            user: widget.user,
            conversationId: id,
            initial: initial,
            onChanged: _load,
            aiEnabled: widget.aiEnabled,
            realtime: realtime,
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ));
    }
  }

  Future<void> _createConversation() async {
    final created = await showDialog<ConversationModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateConversationDialog(service: service),
    );
    if (created == null || !mounted) return;
    ChatCache.set(created);
    setState(() {
      items = [created, ...items.where((item) => item.id != created.id)];
      selectedId = created.id;
    });
    if (MediaQuery.sizeOf(context).width < 760) {
      _open(created.id, false);
    }
    unawaited(_load());
  }
}

class _InboxSquareButton extends StatelessWidget {
  const _InboxSquareButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(48, 48),
          foregroundColor: selected
              ? context.hubScheme.primary
              : context.hubScheme.onSurface,
          backgroundColor: selected
              ? context.hubScheme.primaryContainer.withValues(alpha: .62)
              : context.hubScheme.surface,
          side: BorderSide(
            color: selected
                ? context.hubScheme.primary.withValues(alpha: .40)
                : context.hubScheme.outlineVariant.withValues(alpha: .52),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 23),
      );
}

class _ReferenceInboxTab extends StatelessWidget {
  const _ReferenceInboxTab({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: HubMotion.fast,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? context.hubScheme.primaryContainer.withValues(alpha: .56)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? context.hubScheme.primary
                  : context.hubScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      );
}

class _MobileChatTab extends StatelessWidget {
  const _MobileChatTab({
    required this.selected,
    required this.label,
    required this.activeColor,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: .58),
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 72 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? activeColor : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(999),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ChatListSkeleton extends StatelessWidget {
  const _ChatListSkeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 1),
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              const _SkeletonBox(width: 56, height: 56, circle: true),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 125 + (index % 3) * 24, height: 13),
                    const SizedBox(height: 10),
                    _SkeletonBox(width: 190 + (index % 2) * 45, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.circle = false,
  });

  final double width;
  final double height;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color:
              context.hubScheme.surfaceContainerHighest.withValues(alpha: .72),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(999),
        ),
      );
}

class _InboxFilter extends StatelessWidget {
  const _InboxFilter(
      {required this.selected,
      required this.label,
      required this.icon,
      required this.onTap});
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onTap(),
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        checkmarkColor: scheme.primary,
        labelStyle: TextStyle(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          fontSize: 13.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
      ),
    );
  }
}

class ConversationDetailPane extends StatefulWidget {
  const ConversationDetailPane({
    super.key,
    required this.api,
    required this.user,
    required this.conversationId,
    required this.onChanged,
    required this.aiEnabled,
    required this.realtime,
    this.initial,
  });
  final ApiClient api;
  final UserModel user;
  final String conversationId;
  final Future<void> Function() onChanged;
  final bool aiEnabled;
  final ConversationRealtimeClient realtime;
  final ConversationModel? initial;

  @override
  State<ConversationDetailPane> createState() => _ConversationDetailPaneState();
}

class _ConversationDetailPaneState extends State<ConversationDetailPane> {
  late final ConversationService service;
  final reply = TextEditingController();
  final replyFocus = FocusNode();
  final messageScroll = ScrollController();
  final imagePicker = ImagePicker();
  final recorder = AudioRecorder();
  Timer? refreshTimer;
  Timer? heartbeatTimer;
  Timer? realtimeDebounce;
  Timer? recordingTimer;
  StreamSubscription<Map<String, dynamic>>? realtimeSubscription;
  ConversationModel? conversation;
  ConversationCollaborationModel? collaboration;
  late final String sessionId;
  List<EmployeeModel> employees = const [];
  List<QuickReplyModel> quickReplies = const [];
  bool quickRepliesLoading = false;
  bool loading = true;
  bool sending = false;
  bool recording = false;
  bool newMessagesBelow = false;
  bool refreshing = false;
  Duration recordingDuration = Duration.zero;
  String? error;

  bool get canReply => widget.user.hasPermission('conversations.reply');
  bool get canAssign => widget.user.hasPermission('conversations.assign');
  bool get canManage => widget.user.hasPermission('conversations.manage');
  bool get canOverrideLock =>
      widget.user.hasPermission('conversations.lock.override');

  @override
  void initState() {
    super.initState();
    service = ConversationService(widget.api);
    conversation = widget.initial;
    if (conversation != null) loading = false;

    reply.addListener(_replyChanged);
    messageScroll.addListener(_messageScrollChanged);
    final random = Random.secure();
    sessionId = List.generate(
            20, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    realtimeSubscription = widget.realtime.events.listen((event) {
      final type = event['type']?.toString();
      final conversationId = event['conversationId']?.toString();
      if (type == 'poll.changed' || conversationId == widget.conversationId) {
        if (type == 'presence.updated' || type == 'lock.updated') {
          _loadCollaboration();
          return;
        }
        final messageId = event['messageId']?.toString();
        if (type == 'message.created' &&
            messageId != null &&
            conversation?.messages.any((message) => message.id == messageId) ==
                true) {
          return;
        }
        realtimeDebounce?.cancel();
        realtimeDebounce = Timer(const Duration(milliseconds: 180), () {
          _load(silent: true);
          _loadCollaboration();
        });
      }
    });
    _load();
    _loadQuickReplies();
    _enterCollaboration();
    heartbeatTimer =
        Timer.periodic(const Duration(seconds: 25), (_) => _heartbeat());
    refreshTimer =
        Timer.periodic(const Duration(seconds: 45), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    unawaited(
        service.leave(widget.conversationId, sessionId).catchError((_) {}));
    if (recording) unawaited(recorder.cancel().catchError((_) {}));
    recorder.dispose();
    reply.removeListener(_replyChanged);
    reply.dispose();
    replyFocus.dispose();
    messageScroll.removeListener(_messageScrollChanged);
    messageScroll.dispose();
    heartbeatTimer?.cancel();
    refreshTimer?.cancel();
    realtimeDebounce?.cancel();
    recordingTimer?.cancel();
    realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _enterCollaboration() async {
    try {
      collaboration = await service.enter(widget.conversationId, sessionId);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _heartbeat() async {
    try {
      collaboration = await service.heartbeat(widget.conversationId, sessionId);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadCollaboration() async {
    try {
      collaboration = await service.collaboration(widget.conversationId);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _load({bool silent = false}) async {
    if (refreshing) return;
    refreshing = true;
    if (!silent && conversation == null) {
      if (mounted) setState(() => loading = true);
    }
    final wasNearBottom = _isNearBottom;
    final previousCount = conversation?.messages.length ?? 0;
    try {
      final loaded = await service.get(widget.conversationId);
      ChatCache.set(loaded, notify: false, promote: false);
      if (canAssign && employees.isEmpty) {
        employees = await service.assignees();
      }
      final localMessages = (conversation?.messages ?? const <MessageModel>[])
          .where((message) => message.id.startsWith('local-'))
          .toList();
      final remoteIds = loaded.messages.map((message) => message.id).toSet();
      final merged = [
        ...loaded.messages,
        ...localMessages.where((message) => !remoteIds.contains(message.id)),
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      conversation = loaded.copyWith(messages: merged);
      if (loaded.unreadCount > 0) {
        unawaited(service.markRead(widget.conversationId).catchError((_) {}));
      }
      final receivedNewMessage = merged.length > previousCount;
      if (receivedNewMessage) {
        if (wasNearBottom || previousCount == 0) {
          _scheduleScrollToBottom(animate: previousCount > 0);
        } else {
          newMessagesBelow = true;
        }
      } else if (previousCount == 0) {
        _scheduleScrollToBottom(animate: false);
      }
    } catch (e) {
      if (conversation == null) error = e.toString();
    } finally {
      refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  bool get _isNearBottom {
    if (!messageScroll.hasClients) return true;
    return messageScroll.position.maxScrollExtent - messageScroll.offset < 120;
  }

  void _replyChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadQuickReplies() async {
    if (quickRepliesLoading) return;
    quickRepliesLoading = true;
    try {
      final values = await service.quickReplies();
      if (mounted) setState(() => quickReplies = values);
    } catch (_) {
      // Messaging remains available when quick replies are temporarily offline.
    } finally {
      quickRepliesLoading = false;
    }
  }

  List<QuickReplyModel> get _matchingQuickReplies {
    final value = reply.text.trimLeft();
    if (!value.startsWith('/')) return const [];
    final query = value.substring(1).trim().toLowerCase();
    final matches = quickReplies.where((item) {
      final shortcut =
          (item.shortcut ?? '').replaceFirst(RegExp(r'^/+'), '').toLowerCase();
      return query.isEmpty ||
          shortcut.contains(query) ||
          item.title.toLowerCase().contains(query) ||
          item.body.toLowerCase().contains(query);
    }).toList();
    return matches.take(6).toList();
  }

  void _applyQuickReply(QuickReplyModel item) {
    reply.text = item.body;
    reply.selection = TextSelection.collapsed(offset: reply.text.length);
    replyFocus.requestFocus();
    setState(() {});
  }

  Future<void> _showQuickReplies() async {
    if (quickReplies.isEmpty) await _loadQuickReplies();
    if (!mounted) return;
    final selected = await showModalBottomSheet<QuickReplyModel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: min(MediaQuery.sizeOf(sheetContext).height * .62, 520),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.bolt_rounded),
                title: Text(tr('الردود المخصصة'),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(tr('يضيفها صاحب المتجر من لوحة وصل.')),
              ),
              Expanded(
                child: quickReplies.isEmpty
                    ? Center(child: Text(tr('لا توجد ردود مخصصة بعد.')))
                    : ListView.separated(
                        itemCount: quickReplies.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final item = quickReplies[index];
                          return ListTile(
                            title: Text(item.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            subtitle: Text(item.body,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: (item.shortcut ?? '').isEmpty
                                ? null
                                : Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                        '/${item.shortcut!.replaceFirst(RegExp(r'^/+'), '')}'),
                                  ),
                            onTap: () => Navigator.pop(sheetContext, item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) _applyQuickReply(selected);
  }

  Widget _quickReplySuggestions() {
    final matches = _matchingQuickReplies;
    if (matches.isEmpty) return const SizedBox.shrink();
    return Material(
      color: context.hubScheme.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 250),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: matches.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: context.hubScheme.outlineVariant.withValues(alpha: .32),
          ),
          itemBuilder: (_, index) {
            final item = matches[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.bolt_rounded),
              title: Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle:
                  Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: (item.shortcut ?? '').isEmpty
                  ? null
                  : Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                          '/${item.shortcut!.replaceFirst(RegExp(r'^/+'), '')}'),
                    ),
              onTap: () => _applyQuickReply(item),
            );
          },
        ),
      ),
    );
  }

  void _messageScrollChanged() {
    if (newMessagesBelow && _isNearBottom && mounted) {
      setState(() => newMessagesBelow = false);
    }
  }

  void _scheduleScrollToBottom({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !messageScroll.hasClients) return;
      final target = messageScroll.position.maxScrollExtent;
      if (animate) {
        messageScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        messageScroll.jumpTo(target);
      }
      if (newMessagesBelow) setState(() => newMessagesBelow = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading && conversation == null) return const _ConversationLoading();
    if (error != null && conversation == null) {
      return HubEmptyState(
        icon: Icons.cloud_off_rounded,
        title: tr('تعذر تحميل الدردشة'),
        body: error!,
        action: FilledButton(
          onPressed: _load,
          child: Text(tr('إعادة المحاولة')),
        ),
      );
    }

    final item = conversation!;
    final appearance = ChatAppearanceController.instance;
    return AnimatedBuilder(
      animation: appearance,
      builder: (context, _) {
        final brightness = Theme.of(context).brightness;
        final dark = brightness == Brightness.dark;
        final compact = MediaQuery.sizeOf(context).width < 920;
        final headerColor = context.hubScheme.surfaceContainerLowest;
        final headerForeground = context.hubScheme.onSurface;
        final headerBorder =
            context.hubScheme.outlineVariant.withValues(alpha: .42);
        final accent = context.hubScheme.primary;
        final replyEnabled = collaboration?.canReply == true &&
            item.status != 'closed' &&
            !sending;

        return Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
              decoration: BoxDecoration(
                color: headerColor,
                border: Border(bottom: BorderSide(color: headerBorder)),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(2, 6, 4, 8),
                child: Row(
                  children: [
                    if (compact)
                      BackButton(
                        color: headerForeground,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    HubAvatar(
                      name: item.customer.name,
                      imageUrl: item.customer.avatarUrl,
                      api: widget.api,
                      size: 43,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _showCustomer,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.customer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: headerForeground,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _statusLabel(item.status),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.hubScheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: context.hubScheme.surface,
                      iconColor: headerForeground,
                      onSelected: (value) async {
                        switch (value) {
                          case 'customer':
                            await _showCustomer();
                          case 'assignee':
                            await _chooseAssignee();
                          case 'appearance':
                            if (mounted) {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ChatAppearanceScreen(),
                                ),
                              );
                            }
                          case 'reminder':
                            await _setFollowUp();
                          case 'close':
                            await _closeConversation();
                          case 'reopen':
                            await _reopenConversation();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'customer',
                          child: ListTile(
                            leading: const Icon(Icons.person_outline_rounded),
                            title: Text(tr('عرض العميل')),
                          ),
                        ),
                        if (canAssign)
                          PopupMenuItem(
                            value: 'assignee',
                            child: ListTile(
                              leading:
                                  const Icon(Icons.person_add_alt_1_rounded),
                              title: Text(tr('إسناد الدردشة')),
                            ),
                          ),
                        PopupMenuItem(
                          value: 'appearance',
                          child: ListTile(
                            leading: const Icon(Icons.palette_outlined),
                            title: Text(tr('مظهر الدردشة')),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reminder',
                          child: ListTile(
                            leading: const Icon(Icons.alarm_add_outlined),
                            title: Text(tr('تذكير')),
                          ),
                        ),
                        if (item.status == 'closed' && canManage)
                          PopupMenuItem(
                            value: 'reopen',
                            child: ListTile(
                              leading: const Icon(Icons.lock_open_outlined),
                              title: Text(tr('إعادة فتح الدردشة')),
                            ),
                          )
                        else if (item.status != 'closed')
                          PopupMenuItem(
                            value: 'close',
                            child: ListTile(
                              leading: const Icon(Icons.cancel_outlined),
                              title: Text(tr('إلغاء الدردشة')),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_collaborationNotice(item) case final notice?)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                color: item.status == 'closed'
                    ? context.hubScheme.errorContainer
                    : context.hubScheme.secondaryContainer,
                child: Row(
                  children: [
                    Icon(
                      item.status == 'closed'
                          ? Icons.lock_rounded
                          : Icons.info_outline_rounded,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notice,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: appearance.background(
                        brightness,
                        fallback: context.hubScheme.surfaceContainerLowest,
                      ),
                    ),
                  ),
                  if (appearance.patternEnabled)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ChatWallpaperPainter(
                            color: dark
                                ? Colors.white.withValues(alpha: .025)
                                : const Color(0xFF4F7C70)
                                    .withValues(alpha: .035),
                          ),
                        ),
                      ),
                    ),
                  ListView.builder(
                    controller: messageScroll,
                    padding: const EdgeInsets.fromLTRB(10, 14, 10, 18),
                    itemCount: item.messages.length,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemBuilder: (_, index) => _MessageBubble(
                      key: ValueKey(item.messages[index].id),
                      message: item.messages[index],
                      api: widget.api,
                    ),
                  ),
                  if (newMessagesBelow)
                    PositionedDirectional(
                      end: 16,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        backgroundColor: accent,
                        foregroundColor:
                            ThemeContrastValidator.readableText(accent),
                        onPressed: () => _scheduleScrollToBottom(animate: true),
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ),
                ],
              ),
            ),
            if (canReply && _matchingQuickReplies.isNotEmpty)
              _quickReplySuggestions(),
            if (canReply)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: recording
                    ? _RecordingComposer(
                        key: const ValueKey('recording'),
                        duration: recordingDuration,
                        onCancel: _cancelRecording,
                        onSend: _stopAndSendRecording,
                      )
                    : Container(
                        key: const ValueKey('composer'),
                        color: context.hubScheme.surface,
                        padding: EdgeInsets.fromLTRB(
                          7,
                          7,
                          7,
                          7 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 48),
                                decoration: BoxDecoration(
                                  color: context.hubScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: context.hubScheme.outlineVariant
                                        .withValues(alpha: .28),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: replyEnabled
                                          ? _showAttachmentMenu
                                          : null,
                                      tooltip: tr('إرفاق'),
                                      icon: const Icon(Icons.add_rounded),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: reply,
                                        focusNode: replyFocus,
                                        enabled: item.status != 'closed',
                                        minLines: 1,
                                        maxLines: 5,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        decoration: InputDecoration(
                                          hintText: item.status == 'closed'
                                              ? tr('الدردشة مغلقة')
                                              : tr('اكتب رسالة...'),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 2,
                                          ),
                                        ),
                                        onSubmitted: (_) {
                                          if (replyEnabled) _send();
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: replyEnabled
                                          ? _showQuickReplies
                                          : null,
                                      tooltip: tr('الردود المخصصة'),
                                      icon: const Icon(Icons.bolt_rounded),
                                    ),
                                    if (widget.aiEnabled)
                                      IconButton(
                                        onPressed: replyEnabled
                                            ? _insertAiDraft
                                            : null,
                                        tooltip:
                                            tr('اقتراح رد بالذكاء الاصطناعي'),
                                        icon: const Icon(
                                            Icons.auto_awesome_rounded),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Semantics(
                              button: true,
                              label: reply.text.trim().isEmpty
                                  ? tr('تسجيل رسالة صوتية')
                                  : tr('إرسال'),
                              child: Material(
                                color: accent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: !replyEnabled
                                      ? null
                                      : reply.text.trim().isEmpty
                                          ? _startRecording
                                          : _send,
                                  child: SizedBox(
                                    width: 49,
                                    height: 49,
                                    child: sending
                                        ? Padding(
                                            padding: const EdgeInsets.all(13),
                                            child: CircularProgressIndicator(
                                              color: ThemeContrastValidator
                                                  .readableText(accent),
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            reply.text.trim().isEmpty
                                                ? Icons.mic_rounded
                                                : Icons.send_rounded,
                                            color: ThemeContrastValidator
                                                .readableText(accent),
                                            size: 23,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }

  String? _collaborationNotice(ConversationModel item) {
    if (item.status == 'closed') {
      return conversation?.closedByName?.isNotEmpty == true
          ? tr(
              'أغلق ${conversation!.closedByName} الدردشة ويمكن عرض الرسائل دون تعديل.')
          : tr('هذه الدردشة مغلقة ويمكن عرض رسائلها دون تعديل.');
    }
    final lock = collaboration?.lock;
    if (lock != null && !lock.ownedByMe) {
      return tr('الدردشة قيد المعالجة بواسطة ${lock.userName}');
    }
    final others = (collaboration?.presences ?? const [])
        .where((presence) => presence.userId != widget.user.id)
        .map((presence) => presence.userName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    if (others.isNotEmpty) return tr('${others.join('، ')} داخل الدردشة الآن');
    return null;
  }

  Future<void> _showCustomer() async {
    final customer = conversation!.customer;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(customer.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: Text(customer.phone)),
            if (customer.email?.isNotEmpty == true)
              ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(customer.email!)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(tr('إغلاق')))
        ],
      ),
    );
  }

  Future<void> _chooseAssignee() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(tr('إسناد الدردشة')),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(tr('غير مسندة'))),
          for (final employee in employees)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, employee.id),
                child: Text(employee.name)),
        ],
      ),
    );
    if (selected == null) return;
    await _assign(selected.isEmpty ? null : selected);
  }

  Future<void> _closeConversation() async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('إغلاق الدردشة')),
        content: TextField(
            controller: reason,
            maxLines: 3,
            decoration:
                InputDecoration(labelText: tr('سبب الإغلاق — اختياري'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('إغلاق الدردشة'))),
        ],
      ),
    );
    final value = reason.text.trim();
    reason.dispose();
    if (confirmed != true) return;
    await service.close(widget.conversationId,
        reason: value.isEmpty ? null : value);
    await _load();
    await _loadCollaboration();
    await widget.onChanged();
  }

  Future<void> _reopenConversation() async {
    await service.reopen(widget.conversationId);
    await _load();
    await _enterCollaboration();
    await widget.onChanged();
  }

  Future<void> _overrideLock() async {
    collaboration =
        await service.overrideLock(widget.conversationId, sessionId);
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final body = reply.text.trim();
    if (body.isEmpty ||
        collaboration?.canReply != true ||
        conversation?.status == 'closed') {
      return;
    }
    final pendingId = _appendPending(type: 'text', body: body);
    reply.clear();
    _scheduleScrollToBottom(animate: true);
    try {
      final sent = await service.send(widget.conversationId, body);
      realtimeDebounce?.cancel();
      _replacePending(pendingId, sent);
      unawaited(widget.onChanged());
    } catch (e) {
      _failPending(pendingId, e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _pickAndSendImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    if (sending) return;
    try {
      final image = await imagePicker.pickImage(
        source: source,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final mimeType = _imageMimeType(image.name, image.mimeType);
      final caption = reply.text.trim();
      if (caption.isNotEmpty) reply.clear();
      await _sendMediaBytes(
        bytes: bytes,
        fileName: image.name,
        mimeType: mimeType,
        type: 'image',
        body: caption,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _showAttachmentMenu() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('إرفاق'),
                style: context.hubText.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AttachmentAction(
                    icon: Icons.photo_library_rounded,
                    label: tr('صورة'),
                    color: const Color(0xFF7F66DC),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndSendImage();
                    },
                  ),
                  _AttachmentAction(
                    icon: Icons.camera_alt_rounded,
                    label: tr('الكاميرا'),
                    color: const Color(0xFFE35D6A),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndSendImage(source: ImageSource.camera);
                    },
                  ),
                  _AttachmentAction(
                    icon: Icons.videocam_rounded,
                    label: tr('فيديو'),
                    color: const Color(0xFF2C89D9),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndSendVideo();
                    },
                  ),
                  _AttachmentAction(
                    icon: Icons.insert_drive_file_rounded,
                    label: tr('ملف'),
                    color: const Color(0xFF23A37A),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndSendFile();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendVideo() async {
    if (sending) return;
    try {
      final video = await imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (video == null) return;
      final bytes = await video.readAsBytes();
      await _sendMediaBytes(
        bytes: bytes,
        fileName: video.name,
        mimeType:
            _fileMimeType(video.name, video.mimeType, fallback: 'video/mp4'),
        type: 'video',
        body: video.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    if (sending) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw StateError(tr('تعذر قراءة الملف المحدد'));
      }
      await _sendMediaBytes(
        bytes: bytes,
        fileName: file.name,
        mimeType: _fileMimeType(file.name, null),
        type: 'document',
        body: file.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _insertAiDraft() async {
    if (sending) return;
    setState(() => sending = true);
    try {
      final draft = await service.aiDraft(widget.conversationId);
      if (draft.trim().isNotEmpty) {
        reply.text = draft.trim();
        reply.selection = TextSelection.collapsed(offset: reply.text.length);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _startRecording() async {
    if (sending || recording) return;
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(tr('اسمح للتطبيق باستخدام الميكروفون أولاً.'))),
          );
        }
        return;
      }
      final fileName =
          'wasl-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = kIsWeb
          ? fileName
          : '${(await getTemporaryDirectory()).path}/$fileName';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      recordingTimer?.cancel();
      recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => recordingDuration += const Duration(seconds: 1));
        }
      });
      if (mounted) {
        setState(() {
          recording = true;
          recordingDuration = Duration.zero;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _cancelRecording() async {
    recordingTimer?.cancel();
    await recorder.cancel();
    if (mounted) {
      setState(() {
        recording = false;
        recordingDuration = Duration.zero;
      });
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!recording || sending) return;
    recordingTimer?.cancel();
    final duration = recordingDuration;
    final path = await recorder.stop();
    if (mounted) {
      setState(() {
        recording = false;
        recordingDuration = Duration.zero;
      });
    }
    if (path == null || duration < const Duration(seconds: 1)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(tr('التسجيل قصير جدًا. سجل ثانية واحدة على الأقل.'))),
        );
      }
      return;
    }
    try {
      final file = XFile(path, mimeType: 'audio/mp4');
      await _sendMediaBytes(
        bytes: await file.readAsBytes(),
        fileName: file.name.endsWith('.m4a') ? file.name : 'voice-message.m4a',
        mimeType: 'audio/mp4',
        type: 'audio',
        body: '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _sendMediaBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    required String type,
    required String body,
  }) async {
    final maxBytes = switch (type) {
      'image' => 5 * 1024 * 1024,
      'video' => 32 * 1024 * 1024,
      'document' => 100 * 1024 * 1024,
      _ => 16 * 1024 * 1024,
    };
    if (bytes.length > maxBytes) {
      final message = switch (type) {
        'image' => tr('حجم الصورة يتجاوز 5 ميجابايت.'),
        'video' => tr(
            '\u062D\u062C\u0645 \u0627\u0644\u0641\u064A\u062F\u064A\u0648 \u064A\u062A\u062C\u0627\u0648\u0632 32 \u0645\u064A\u062C\u0627\u0628\u0627\u064A\u062A.'),
        'document' => tr('حجم المستند يتجاوز 100 ميجابايت.'),
        _ => tr('الملف أكبر من الحجم المسموح.'),
      };
      throw StateError(message);
    }
    final pendingId = _appendPending(
      type: type,
      body: body.isNotEmpty
          ? body
          : switch (type) {
              'image' => tr('جارٍ رفع الصورة…'),
              'video' => tr('جارٍ رفع الفيديو…'),
              'document' => tr('جارٍ رفع الملف…'),
              _ => tr('جارٍ إرسال الرسالة الصوتية…'),
            },
    );
    _scheduleScrollToBottom(animate: true);
    try {
      final sent = await service.sendMedia(
        widget.conversationId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        caption: body,
      );
      realtimeDebounce?.cancel();
      _replacePending(pendingId, sent);
      unawaited(widget.onChanged());
    } catch (e) {
      _failPending(pendingId, e.toString());
      rethrow;
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String _appendPending({required String type, required String body}) {
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final pending = MessageModel(
      id: id,
      senderType: 'employee',
      direction: 'outbound',
      type: type,
      status: 'queued',
      senderName: widget.user.name,
      body: body,
      createdAt: DateTime.now(),
    );
    final current = conversation!;
    setState(() {
      sending = true;
      conversation = current.copyWith(
        lastMessagePreview: body,
        lastMessageAt: pending.createdAt,
        messages: [...current.messages, pending],
      );
    });
    return id;
  }

  void _replacePending(String pendingId, MessageModel sent) {
    if (!mounted || conversation == null) return;
    final current = conversation!;
    setState(() {
      conversation = current.copyWith(
        lastMessagePreview: sent.body ??
            switch (sent.type) {
              'image' => tr('صورة'),
              'video' => tr('فيديو'),
              'document' => tr('ملف'),
              _ => tr('رسالة صوتية'),
            },
        lastMessageAt: sent.createdAt,
        messages: current.messages
            .where(
                (message) => message.id == pendingId || message.id != sent.id)
            .map((message) => message.id == pendingId ? sent : message)
            .toList(),
      );
    });
    _scheduleScrollToBottom(animate: true);
  }

  void _failPending(String pendingId, String reason) {
    if (!mounted || conversation == null) return;
    final current = conversation!;
    setState(() {
      conversation = current.copyWith(
        messages: current.messages
            .map((message) => message.id == pendingId
                ? message.copyWith(status: 'failed', error: reason)
                : message)
            .toList(),
      );
    });
  }

  Future<void> _assign(String? id) async {
    try {
      await service.assign(widget.conversationId, id);
      await _load();
      await widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _setFollowUp() async {
    var date = DateTime.now().add(const Duration(hours: 1));
    final note = TextEditingController(text: conversation?.followUpNote ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('تذكير متابعة')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(_formatDate(date)),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate == null || !context.mounted) return;
                  final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(date));
                  if (pickedTime == null) return;
                  setDialogState(() => date = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute));
                },
              ),
              TextField(
                  controller: note,
                  maxLines: 3,
                  decoration:
                      InputDecoration(labelText: tr('ملاحظة المتابعة'))),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(tr('إلغاء'))),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(tr('حفظ'))),
          ],
        ),
      ),
    );
    if (saved == true) {
      await service.update(widget.conversationId,
          followUpAt: date, followUpNote: note.text.trim());
      await _load();
      await widget.onChanged();
    }
    note.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.api,
  });

  final MessageModel message;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final internal = message.internal;
    final inbound = message.inbound;
    final type = message.type.toLowerCase();
    final isImage = type == 'image' || type == 'photo';
    final isVideo = type == 'video';
    final isAudio = type == 'audio' || type == 'voice' || type == 'voice_note';
    final isDocument = type == 'document' || type == 'file';
    final brightness = Theme.of(context).brightness;
    final appearance = ChatAppearanceController.instance;
    final background = internal
        ? context.hubScheme.tertiaryContainer
        : inbound
            ? appearance.received(
                brightness,
                fallback: Theme.of(context)
                    .extension<SupportHubThemeColors>()!
                    .receivedMessageBubble,
              )
            : appearance.sent(
                brightness,
                fallback: Theme.of(context)
                    .extension<SupportHubThemeColors>()!
                    .sentMessageBubble,
              );
    final foreground = background.computeLuminance() > .48
        ? const Color(0xFF17191C)
        : Colors.white;
    final local = message.createdAt.toLocal();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: false,
    );
    final maxWidth = min(MediaQuery.sizeOf(context).width * .78, 520.0);

    return Align(
      alignment: internal
          ? Alignment.center
          : inbound
              ? Alignment.centerLeft
              : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: EdgeInsets.fromLTRB(
          inbound || internal ? 0 : 46,
          2,
          inbound || internal ? 46 : 0,
          5,
        ),
        padding: const EdgeInsets.fromLTRB(11, 8, 10, 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: internal
              ? BorderRadius.circular(13)
              : BorderRadius.only(
                  topLeft: const Radius.circular(15),
                  topRight: const Radius.circular(15),
                  bottomLeft: Radius.circular(inbound ? 3 : 15),
                  bottomRight: Radius.circular(inbound ? 15 : 3),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .07),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (internal) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 13, color: foreground.withValues(alpha: .68)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      tr('ملاحظة داخلية — ${message.senderName ?? 'موظف'}'),
                      style: TextStyle(
                        color: foreground.withValues(alpha: .72),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
            ],
            if (isImage && message.mediaUrl?.isNotEmpty == true) ...[
              ConversationImage(api: api, mediaUrl: message.mediaUrl!),
              if ((message.body ?? '').trim().isNotEmpty)
                const SizedBox(height: 6),
            ],
            if (isVideo && message.mediaUrl?.isNotEmpty == true) ...[
              ConversationVideo(api: api, mediaUrl: message.mediaUrl!),
              if ((message.body ?? '').trim().isNotEmpty)
                const SizedBox(height: 6),
            ],
            if (isAudio && message.mediaUrl?.isNotEmpty == true)
              ConversationAudio(
                api: api,
                mediaUrl: message.mediaUrl!,
                foreground: foreground,
              ),
            if (isDocument && message.mediaUrl?.isNotEmpty == true)
              ConversationDocument(
                api: api,
                mediaUrl: message.mediaUrl!,
                fileName: (message.body ?? '').trim().isEmpty
                    ? tr('ملف مرفق')
                    : message.body!.trim(),
                foreground: foreground,
              ),
            if ((message.body ?? '').trim().isNotEmpty && !isDocument)
              Text(
                message.body!.trim(),
                style: TextStyle(
                  color: foreground,
                  fontSize: 15.4 * appearance.fontScale,
                  height: 1.42,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 3),
            Align(
              widthFactor: 1,
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: foreground.withValues(alpha: .55),
                      fontSize: 10.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!inbound && !internal) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.status == 'read'
                          ? Icons.done_all_rounded
                          : message.status == 'failed'
                              ? Icons.error_outline_rounded
                              : message.status == 'queued'
                                  ? Icons.schedule_rounded
                                  : message.status == 'delivered'
                                      ? Icons.done_all_rounded
                                      : Icons.done_rounded,
                      size: 15,
                      color: message.status == 'read'
                          ? const Color(0xFF34B7F1)
                          : message.status == 'failed'
                              ? const Color(0xFFD94B4B)
                              : foreground.withValues(alpha: .48),
                    ),
                  ],
                ],
              ),
            ),
            if ((message.error ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  tr('فشل الإرسال. اضغط وحاول مرة أخرى.'),
                  style: const TextStyle(
                    color: Color(0xFFD94B4B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConversationLoading extends StatelessWidget {
  const _ConversationLoading();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            height: MediaQuery.paddingOf(context).top + 62,
            color: context.hubScheme.surfaceContainerLowest,
          ),
          Expanded(
            child: ColoredBox(
              color: context.hubScheme.surfaceContainerLowest,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      );
}

class _RecordingComposer extends StatelessWidget {
  const _RecordingComposer({
    super.key,
    required this.duration,
    required this.onCancel,
    required this.onSend,
  });

  final Duration duration;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
        color: context.hubScheme.surface,
        padding: EdgeInsets.fromLTRB(
          8,
          7,
          8,
          7 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onCancel,
              tooltip: tr('إلغاء التسجيل'),
              icon: const Icon(Icons.delete_outline_rounded),
              color: context.hubScheme.error,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.fiber_manual_record_rounded,
                color: Color(0xFFE14E58), size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _durationLabel(duration),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(tr('جارٍ التسجيل…'),
                style: TextStyle(color: context.hubScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              tooltip: tr('إرسال التسجيل'),
              style: IconButton.styleFrom(
                backgroundColor: context.hubScheme.primary,
                foregroundColor: ThemeContrastValidator.readableText(
                    context.hubScheme.primary),
              ),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      );
}

class _AttachmentAction extends StatelessWidget {
  const _AttachmentAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 27),
              ),
              const SizedBox(height: 7),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _ChatWallpaperPainter extends CustomPainter {
  const _ChatWallpaperPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const step = 74.0;
    for (double y = 22; y < size.height + step; y += step) {
      for (double x = 18; x < size.width + step; x += step) {
        final offset = ((y / step).round().isEven ? 0.0 : step / 2);
        final center = Offset(x + offset, y);
        canvas.drawCircle(center, 6, paint);
        canvas.drawArc(
          Rect.fromCenter(
              center: center + const Offset(20, 17), width: 20, height: 14),
          .2,
          3.8,
          false,
          paint,
        );
        canvas.drawLine(center + const Offset(-19, 20),
            center + const Offset(-8, 30), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatWallpaperPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ConversationMetaChip extends StatelessWidget {
  const _ConversationMetaChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? context.hubScheme.primary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 8, 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tone),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone,
                fontSize: 10.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateConversationDialog extends StatefulWidget {
  const _CreateConversationDialog({required this.service});
  final ConversationService service;

  @override
  State<_CreateConversationDialog> createState() =>
      _CreateConversationDialogState();
}

class _CreateConversationDialogState extends State<_CreateConversationDialog> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final message = TextEditingController();
  String priority = 'normal';
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr('إنشاء دردشة يدوية')),
        content: SizedBox(
          width: 520,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(children: [
                TextFormField(
                    controller: name,
                    decoration: InputDecoration(labelText: tr('اسم العميل')),
                    validator: (v) => v == null || v.trim().length < 2
                        ? tr('أدخل اسم العميل')
                        : null),
                const SizedBox(height: 10),
                TextFormField(
                    controller: phone,
                    decoration: InputDecoration(labelText: tr('رقم الهاتف')),
                    validator: (v) =>
                        v == null || v.replaceAll(RegExp(r'\D'), '').length < 6
                            ? tr('رقم غير صالح')
                            : null),
                const SizedBox(height: 10),
                TextFormField(
                    controller: message,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: tr('أول رسالة')),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? tr('اكتب الرسالة')
                        : null),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: InputDecoration(labelText: tr('الأولوية')),
                  items: [
                    DropdownMenuItem(value: 'low', child: Text(tr('منخفضة'))),
                    DropdownMenuItem(value: 'normal', child: Text(tr('عادية'))),
                    DropdownMenuItem(value: 'high', child: Text(tr('عالية'))),
                    DropdownMenuItem(value: 'urgent', child: Text(tr('عاجلة'))),
                  ],
                  onChanged: (value) => priority = value ?? 'normal',
                ),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: Text(tr('إلغاء'))),
          FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const CircularProgressIndicator()
                  : Text(tr('إنشاء'))),
        ],
      );

  Future<void> _save() async {
    if (key.currentState?.validate() != true) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.service.create(
          name: name.text,
          phone: phone.text,
          message: message.text,
          priority: priority);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero);
}

String _statusLabel(String value) => switch (value) {
      'new' => tr('جديدة'),
      'open' => tr('مفتوحة'),
      'waiting' => tr('انتظار'),
      'closed' => tr('مغلقة'),
      _ => value,
    };
String _priorityLabel(String value) => switch (value) {
      'low' => tr('منخفضة'),
      'normal' => tr('عادية'),
      'high' => tr('عالية'),
      'urgent' => tr('عاجلة'),
      _ => value,
    };
String _messageStatus(String value) => switch (value) {
      'received' => tr('مستلمة'),
      'queued' => tr('بالانتظار'),
      'sent' => tr('مرسلة'),
      'delivered' => tr('تم التسليم'),
      'read' => tr('مقروءة'),
      'failed' => tr('فشلت'),
      _ => value,
    };
String _durationLabel(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _imageMimeType(String fileName, String? reported) {
  final normalized = reported?.split(';').first.trim().toLowerCase();
  if (normalized == 'image/jpeg' ||
      normalized == 'image/png' ||
      normalized == 'image/webp') {
    return normalized!;
  }
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String _fileMimeType(
  String fileName,
  String? reported, {
  String fallback = 'application/octet-stream',
}) {
  final normalized = reported?.split(';').first.trim().toLowerCase();
  if (normalized != null && normalized.contains('/')) return normalized;
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg') || lower.endsWith('.opus')) return 'audio/ogg';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.txt')) return 'text/plain';
  return fallback;
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)} ${local.year}-${two(local.month)}-${two(local.day)}';
}
