// lib/screens/notifications/preferences.dart
//
// Ecran "Preferences notifications" partner.
//
// Consomme `notificationPreferencesProvider` :
//   - GET  /v1/partner/notifications/preferences (liste)
//   - PATCH /v1/partner/notifications/preferences/{id} (toggle par canal)
//
// UX :
//  - 1 carte par type de notification (label) avec 4 toggles canaux
//    (Push, In-app, SMS, Email).
//  - Loading skeleton via ZeetStateBuilder.
//  - Erreur typee + retry.
//  - Toggle optimiste : update local immediat, rollback si l'API echoue.
//
// Skills : `zeet-states-elae`, `zeet-notification-strategy`,
// `zeet-pos-ergonomics` (hit target >= 56pt sur les SwitchListTile).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/notification_model.dart';
import 'package:merchant/providers/notifications_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationPreferencesProvider.notifier).load(),
    );
  }

  Future<void> _toggle({
    required NotificationPreference pref,
    required String channel,
    required bool value,
  }) async {
    ZeetHaptics.tap();
    final NotificationPreferencePatch patch;
    switch (channel) {
      case 'push':
        patch = NotificationPreferencePatch(pushEnabled: value);
        break;
      case 'in_app':
        patch = NotificationPreferencePatch(inAppEnabled: value);
        break;
      case 'sms':
        patch = NotificationPreferencePatch(smsEnabled: value);
        break;
      case 'email':
        patch = NotificationPreferencePatch(emailEnabled: value);
        break;
      default:
        return;
    }
    final ok = await ref
        .read(notificationPreferencesProvider.notifier)
        .updatePreference(pref.id, patch);
    if (!mounted) return;
    if (!ok) {
      AppToast.showError(
        context: context,
        message: 'Mise a jour impossible. Reessayez.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationPreferencesProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: ZeetAppBar(
        title: const Text('Preferences notifications'),
      ),
      body: ZeetStateBuilder<List<NotificationPreference>>(
        data: state.preferences.isNotEmpty ? state.preferences : null,
        isLoading: state.isLoading && state.preferences.isEmpty,
        error: state.errorMessage,
        onRetry: () =>
            ref.read(notificationPreferencesProvider.notifier).load(),
        emptyIcon: Icons.notifications_none_outlined,
        emptyTitle: 'Aucune preference disponible',
        emptySubtitle:
            'Le serveur n\'a pas encore configure de canaux pour votre compte.',
        loading: const ZeetSkeletonList(itemCount: 5, itemHeight: 96),
        builder: (List<NotificationPreference> prefs) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            itemCount: prefs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final pref = prefs[index];
              return _PreferenceCard(
                pref: pref,
                surfaceColor: scheme.surfaceContainerHighest,
                onToggle: ({required String channel, required bool value}) =>
                    _toggle(pref: pref, channel: channel, value: value),
                isUpdating: state.isUpdating,
              );
            },
          );
        },
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({
    required this.pref,
    required this.surfaceColor,
    required this.onToggle,
    required this.isUpdating,
  });

  final NotificationPreference pref;
  final Color surfaceColor;
  final void Function({required String channel, required bool value}) onToggle;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = pref.label ?? pref.key ?? 'Notification ${pref.id}';

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 4, right: 8),
            child: Text(
              label,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          _ChannelSwitch(
            icon: Icons.notifications_active_outlined,
            label: 'Push (mobile)',
            value: pref.pushEnabled,
            onChanged: isUpdating
                ? null
                : (v) => onToggle(channel: 'push', value: v),
          ),
          _ChannelSwitch(
            icon: Icons.message_outlined,
            label: 'Dans l\'app',
            value: pref.inAppEnabled,
            onChanged: isUpdating
                ? null
                : (v) => onToggle(channel: 'in_app', value: v),
          ),
          _ChannelSwitch(
            icon: Icons.sms_outlined,
            label: 'SMS',
            value: pref.smsEnabled,
            onChanged: isUpdating
                ? null
                : (v) => onToggle(channel: 'sms', value: v),
          ),
          _ChannelSwitch(
            icon: Icons.email_outlined,
            label: 'E-mail',
            value: pref.emailEnabled,
            onChanged: isUpdating
                ? null
                : (v) => onToggle(channel: 'email', value: v),
          ),
        ],
      ),
    );
  }
}

class _ChannelSwitch extends StatelessWidget {
  const _ChannelSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      dense: true,
      secondary: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
