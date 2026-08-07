import '../../core/localization/app_locale_controller.dart';
import 'package:flutter/material.dart';
import '../../core/icons/app_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/workspace_page.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final model = TextEditingController();
  final prompt = TextEditingController();
  final keywords = TextEditingController();
  bool enabled = true;
  bool autoReply = false;
  String provider = 'mock';
  int contextMessages = 12;
  List<Map<String, dynamic>> knowledge = const [];
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    model.dispose();
    prompt.dispose();
    keywords.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.api.getMap('/ai/settings'),
        widget.api.getList('/ai/knowledge'),
      ]);
      final settings = values[0] as Map<String, dynamic>;
      enabled = settings['enabled'] == true;
      autoReply = settings['autoReplyEnabled'] == true;
      provider = settings['provider']?.toString() ?? 'mock';
      model.text = settings['model']?.toString() ?? '';
      prompt.text = settings['systemPrompt']?.toString() ?? '';
      contextMessages = (settings['maxContextMessages'] as num?)?.toInt() ?? 12;
      keywords.text =
          (settings['handoffKeywords'] as List? ?? const []).join(tr('، '));
      knowledge = List<Map<String, dynamic>>.from(values[1] as List);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspacePage(
        title: tr('الذكاء الاصطناعي'),
        subtitle: tr('إعداد المساعد وقاعدة المعرفة وسياسة التحويل للموظف'),
        icon: AppIcons.ai,
        accent: const Color(0xFF7C3AED),
        actions: [
          IconButton(
              onPressed: _load,
              tooltip: tr('تحديث'),
              icon: const Icon(Icons.refresh_rounded))
        ],
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(tr('إعدادات المساعد'),
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                SwitchListTile(
                                    value: enabled,
                                    onChanged: (v) =>
                                        setState(() => enabled = v),
                                    title: Text(tr('تفعيل المساعد'))),
                                SwitchListTile(
                                    value: autoReply,
                                    onChanged: (v) =>
                                        setState(() => autoReply = v),
                                    title: Text(tr(
                                        'الرد التلقائي على الرسائل الواردة')),
                                    subtitle: Text(tr(
                                        'ابدأ به مغلقًا حتى تراجع قاعدة المعرفة.'))),
                                DropdownButtonFormField<String>(
                                  initialValue: provider,
                                  decoration:
                                      InputDecoration(labelText: tr('المزود')),
                                  items: [
                                    DropdownMenuItem(
                                        value: 'mock',
                                        child: Text(
                                            tr('محلي تجريبي — بدون تكلفة'))),
                                    DropdownMenuItem(
                                        value: 'openai', child: Text('OpenAI')),
                                    DropdownMenuItem(
                                        value: 'gemini', child: Text('Gemini')),
                                  ],
                                  onChanged: (value) => setState(() {
                                    provider = value ?? 'mock';
                                    if (provider == 'mock') {
                                      model.text = 'mock-support-v1';
                                    }
                                    if (provider == 'openai' &&
                                        model.text.startsWith('mock')) {
                                      model.text = 'gpt-5';
                                    }
                                    if (provider == 'gemini' &&
                                        (model.text.startsWith('mock') ||
                                            model.text.startsWith('gpt'))) {
                                      model.text = 'gemini-3.6-flash';
                                    }
                                  }),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                    controller: model,
                                    decoration: InputDecoration(
                                        labelText: tr('اسم النموذج'))),
                                const SizedBox(height: 12),
                                TextField(
                                    controller: prompt,
                                    maxLines: 5,
                                    decoration: InputDecoration(
                                        labelText: tr('تعليمات المساعد'))),
                                const SizedBox(height: 12),
                                TextField(
                                    controller: keywords,
                                    decoration: InputDecoration(
                                        labelText: tr(
                                            'كلمات التحويل لموظف — مفصولة بفاصلة'))),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Text(tr('عدد رسائل السياق:')),
                                  Expanded(
                                    child: Slider(
                                      value: contextMessages.toDouble(),
                                      min: 2,
                                      max: 30,
                                      divisions: 28,
                                      label: '$contextMessages',
                                      onChanged: (value) => setState(() =>
                                          contextMessages = value.round()),
                                    ),
                                  ),
                                  Text('$contextMessages'),
                                ]),
                                FilledButton.icon(
                                    onPressed: saving ? null : _saveSettings,
                                    icon: const Icon(Icons.save),
                                    label: Text(tr('حفظ الإعدادات'))),
                              ]),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                            child: Text(tr('قاعدة المعرفة'),
                                style: Theme.of(context).textTheme.titleLarge)),
                        FilledButton.tonalIcon(
                            onPressed: () => _editKnowledge(),
                            icon: const Icon(Icons.add),
                            label: Text(tr('إضافة معلومة'))),
                      ]),
                      const SizedBox(height: 8),
                      if (knowledge.isEmpty)
                        Card(
                            child: Padding(
                                padding: EdgeInsets.all(18),
                                child: Text(tr(
                                    'أضف سياسات الشحن والاسترجاع والأسئلة المتكررة.'))))
                      else
                        ...knowledge.map((item) => Card(
                              child: ListTile(
                                leading: Icon(item['isActive'] == true
                                    ? Icons.menu_book
                                    : Icons.visibility_off),
                                title: Text(item['title']?.toString() ?? ''),
                                subtitle: Text(
                                    item['content']?.toString() ?? '',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) => value == 'edit'
                                      ? _editKnowledge(item)
                                      : _deleteKnowledge(item),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: Text(tr('تعديل'))),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: Text(tr('حذف'))),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
      );

  List<String> _parseKeywords() => keywords.text
      .split(RegExp(r'[,،]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _saveSettings() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.patchMap('/ai/settings', {
        'enabled': enabled,
        'autoReplyEnabled': autoReply,
        'provider': provider,
        'model': model.text.trim(),
        'systemPrompt': prompt.text.trim(),
        'maxContextMessages': contextMessages,
        'handoffKeywords': _parseKeywords(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('تم حفظ إعدادات المساعد.'))));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _editKnowledge([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final content =
        TextEditingController(text: item?['content']?.toString() ?? '');
    bool active = item?['isActive'] != false;
    String? dialogError;
    bool busy = false;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: Text(
                    item == null ? tr('إضافة معلومة') : tr('تعديل المعلومة')),
                content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                        child: Column(children: [
                      TextField(
                          controller: title,
                          decoration:
                              InputDecoration(labelText: tr('العنوان'))),
                      const SizedBox(height: 10),
                      TextField(
                          controller: content,
                          maxLines: 8,
                          decoration: InputDecoration(
                              labelText:
                                  tr('المحتوى الدقيق الذي سيستخدمه المساعد'))),
                      SwitchListTile(
                          value: active,
                          onChanged: (v) => setDialogState(() => active = v),
                          title: Text(tr('نشطة'))),
                      if (dialogError != null)
                        Text(dialogError!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.pop(dialogContext, false),
                      child: Text(tr('إلغاء'))),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (title.text.trim().length < 2 ||
                                content.text.trim().length < 2) {
                              setDialogState(() => dialogError =
                                  tr('أدخل عنوانًا ومحتوى صحيحين.'));
                              return;
                            }
                            setDialogState(() {
                              busy = true;
                              dialogError = null;
                            });
                            try {
                              final body = {
                                'title': title.text.trim(),
                                'content': content.text.trim(),
                                'isActive': active
                              };
                              if (item == null) {
                                await widget.api.postMap('/ai/knowledge', body);
                              } else {
                                await widget.api.patchMap(
                                    '/ai/knowledge/${item['id']}', body);
                              }
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } catch (e) {
                              setDialogState(() {
                                busy = false;
                                dialogError = e.toString();
                              });
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(tr('حفظ')),
                  ),
                ],
              )),
    );
    title.dispose();
    content.dispose();
    if (saved == true) await _load();
  }

  Future<void> _deleteKnowledge(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('حذف المعلومة')),
        content: Text(tr('حذف "${item['title']}" من قاعدة المعرفة؟')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('حذف'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.api.deleteMap('/ai/knowledge/${item['id']}');
    await _load();
  }
}
