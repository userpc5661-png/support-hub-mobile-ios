import 'package:flutter/material.dart';

/// The single icon vocabulary used by Support Hub navigation and page headers.
abstract final class AppIcons {
  static const overview = Icons.space_dashboard_outlined;
  static const conversations = Icons.forum_outlined;
  static const customers = Icons.people_alt_outlined;
  static const team = Icons.groups_outlined;
  static const store = Icons.store_outlined;
  static const whatsApp = Icons.chat_outlined;
  static const metaUsage = Icons.insights_outlined;
  static const subscriptions = Icons.workspace_premium_outlined;
  static const ai = Icons.smart_toy_outlined;
  static const audit = Icons.history_outlined;
  static const privacy = Icons.privacy_tip_outlined;
  static const support = Icons.support_agent_outlined;
  static const settings = Icons.settings_outlined;
  static const account = Icons.account_circle_outlined;
  static const platformStores = Icons.storefront_outlined;

  static IconData back(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.arrow_forward_rounded
          : Icons.arrow_back_rounded;

  static IconData forward(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left_rounded
          : Icons.chevron_right_rounded;
}
