import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/support_hub_design.dart';
import '../../core/widgets/support_hub_widgets.dart';
import '../auth/user_model.dart';
import '../conversations/conversation_model.dart';
import '../conversations/conversation_realtime_client.dart';
import '../conversations/conversation_service.dart';
import '../conversations/conversations_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.api,
    required this.user,
    this.onCountChanged,
  });

  final ApiClient api;
  final UserModel user;
  final ValueChanged<int>? onCountChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final ConversationService service;
  late final ConversationRealtimeClient realtime;
  StreamSubscription<Map<String, dynamic>>? subscription;
  Timer? debounce;
  List<ConversationModel> items = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    service = ConversationService(widget.api);
    realtime = ConversationRealtimeClient(widget.api);
    subscription = realtime.events.listen((event) {
      if (event['type'] == 'heartbeat' || event['type'] == 'connected') return;
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), _load);
    });
    realtime.start();
    _load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    subscription?.cancel();
    realtime.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final fresh = await service.list(unreadOnly: true);
      if (!mounted) return;
      setState(() {
        items = fresh;
        loading = false;
        error = null;
      });
      widget.onCountChanged
          ?.call(fresh.fold(0, (sum, item) => sum + item.unreadCount));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.hubScheme.surfaceContainerLowest,
        body: SafeArea(
          child: Column(
            children: [
              HubPageHeader(
                title: tr('التنبيهات'),
                subtitle: tr('الرسائل التي تحتاج انتباهك'),
                leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.hubScheme.primary.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_active_rounded, color: context.hubScheme.primary),
              ),
                actions: [
                  HubIconButton(
                    icon: Icons.refresh_rounded,
                    onPressed: _load,
                    tooltip: tr('تحديث'),
                  ),
                ],
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return HubEmptyState(
        icon: Icons.cloud_off_rounded,
        title: tr('تعذر تحميل التنبيهات'),
        body: error!,
        action:
            FilledButton(onPressed: _load, child: Text(tr('إعادة المحاولة'))),
      );
    }
    if (items.isEmpty) {
      return HubEmptyState(
        icon: Icons.notifications_none_rounded,
        title: tr('لا توجد تنبيهات جديدة'),
        body:
            tr('أنت على اطلاع بكل الرسائل. ستظهر هنا المحادثات غير المقروءة.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        itemCount: items.length,
        itemBuilder: (_, index) {
          final item = items[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: context.hubScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.hubScheme.outlineVariant.withValues(alpha: .12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => ConversationsScreen(
                      api: widget.api,
                      user: widget.user,
                      manualConversationsEnabled: false,
                      aiEnabled: widget.user.hasPermission('ai.draft'),
                      initialConversationId: item.id,
                    ),
                  ));
                  if (mounted) await _load();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      HubAvatar(name: item.customer.name, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.customer.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              item.lastMessagePreview ?? tr('رسالة جديدة'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.hubScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: context.hubScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.unreadCount}',
                          style: TextStyle(
                            color: context.hubScheme.onPrimaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
