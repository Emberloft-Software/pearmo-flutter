import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/date_checkin.dart';
import '../../../providers/checkin_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// Derives a stable positive int id for the local alarm from a check-in's
/// uuid — `flutter_local_notifications` needs an int, not a string.
int _alarmIdFor(String checkinId) => checkinId.hashCode & 0x7FFFFFFF;

/// Lets either user set a **check-in alarm** for a date: a loud reminder on
/// their own phone to confirm they're okay, on a repeating interval, until
/// they check in or cancel it.
///
/// Deliberately NOT an emergency-contact notification system — nothing in
/// this app contacts the phone number entered below automatically. See the
/// disclaimer text in the UI and CLAUDE.md's "Check-in alarm rework" notes
/// for why this was reframed from the earlier "we'll check on you" framing.
class CheckinPanel extends ConsumerStatefulWidget {
  const CheckinPanel({super.key, required this.connectionId});

  final String connectionId;

  @override
  ConsumerState<CheckinPanel> createState() => _CheckinPanelState();
}

class _CheckinPanelState extends ConsumerState<CheckinPanel> {
  final _contactController = TextEditingController();
  DateTime? _scheduledFor;
  bool _isSaving = false;
  String? _busyCheckinId;
  String? _error;

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;

    setState(() {
      _scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  /// (Re)schedules the local alarm for [checkin]'s next deadline, replacing
  /// any previously scheduled alarm for the same check-in (same id).
  Future<void> _scheduleAlarmFor(DateCheckin checkin) async {
    await NotificationService.instance.scheduleAlarm(
      id: _alarmIdFor(checkin.id),
      dateTime: checkin.nextDeadline,
      title: 'Check-in time',
      body: "Tap to confirm you're okay — this alarm is just for you, no one else is notified.",
    );
  }

  Future<void> _create() async {
    final scheduledFor = _scheduledFor;
    final contact = _contactController.text.trim();
    if (scheduledFor == null) {
      setState(() => _error = 'Pick a date and time for your check-in.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(checkinRepositoryProvider).create(
            connectionId: widget.connectionId,
            scheduledFor: scheduledFor,
            emergencyContact: contact,
          );
      ref.invalidate(checkinsProvider(widget.connectionId));

      // Find the row we just created to read back its real
      // `check_in_interval` (DB-set, not something the client chooses) and
      // schedule the alarm against it.
      final checkins = await ref.read(checkinsProvider(widget.connectionId).future);
      final created = checkins.where((c) => c.scheduledFor == scheduledFor).firstOrNull;
      if (created != null) await _scheduleAlarmFor(created);

      setState(() {
        _scheduledFor = null;
        _contactController.clear();
      });
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _acknowledge(String checkinId) async {
    setState(() {
      _busyCheckinId = checkinId;
      _error = null;
    });
    try {
      await ref.read(checkinRepositoryProvider).acknowledge(checkinId);
      ref.invalidate(checkinsProvider(widget.connectionId));

      // Extend the alarm to the next interval rather than leaving the old
      // (now-passed) one scheduled.
      final checkins = await ref.read(checkinsProvider(widget.connectionId).future);
      final updated = checkins.where((c) => c.id == checkinId).firstOrNull;
      if (updated != null && updated.status == 'active') {
        await _scheduleAlarmFor(updated);
      } else {
        await NotificationService.instance.cancelScheduled(_alarmIdFor(checkinId));
      }
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _busyCheckinId = null);
    }
  }

  Future<void> _cancel(String checkinId) async {
    setState(() {
      _busyCheckinId = checkinId;
      _error = null;
    });
    try {
      await ref.read(checkinRepositoryProvider).cancel(checkinId);
      await NotificationService.instance.cancelScheduled(_alarmIdFor(checkinId));
      ref.invalidate(checkinsProvider(widget.connectionId));
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _busyCheckinId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkinsAsync = ref.watch(checkinsProvider(widget.connectionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Check-in alarm',
          subtitle: "Set a loud reminder on your own phone to confirm you're okay during a date.",
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "This alarm only sounds on your own phone. Pearmo does not call, text, or notify "
                  "anyone — including the contact below — automatically. If you don't check in, "
                  "your check-in is simply marked missed in the app.",
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        checkinsAsync.when(
          data: (checkins) => Column(
            children: checkins.map((c) => _CheckinTile(
                  checkin: c,
                  isBusy: _busyCheckinId == c.id,
                  onAcknowledge: () => _acknowledge(c.id),
                  onCancel: () => _cancel(c.id),
                )).toList(),
          ),
          loading: () => const LoadingIndicator(),
          error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
        ),
        const SizedBox(height: 12),
        PearmoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set a check-in alarm', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        _scheduledFor == null
                            ? 'Pick date & time'
                            : DateFormat('EEE d MMM, HH:mm').format(_scheduledFor!),
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'Optional — a personal note of who you\'d call',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "For your own reference only — Pearmo never contacts this number.",
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              PearmoButton(
                label: 'Set check-in alarm',
                icon: Icons.alarm_add_outlined,
                variant: PearmoButtonVariant.outline,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _create,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(message: _error!),
        ],
      ],
    );
  }
}

class _CheckinTile extends StatelessWidget {
  const _CheckinTile({
    required this.checkin,
    required this.isBusy,
    required this.onAcknowledge,
    required this.onCancel,
  });

  final DateCheckin checkin;
  final bool isBusy;
  final VoidCallback onAcknowledge;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final canAct = checkin.status == 'active';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PearmoCard(
        child: Row(
          children: [
            Icon(
              checkin.status == 'checked_in'
                  ? Icons.check_circle_outline
                  : checkin.status == 'cancelled'
                      ? Icons.cancel_outlined
                      : checkin.status == 'escalated'
                          ? Icons.warning_amber_outlined
                          : checkin.needsAcknowledgement
                              ? Icons.notifications_active_outlined
                              : Icons.schedule_outlined,
              color: checkin.status == 'checked_in'
                  ? AppColors.success
                  : checkin.status == 'cancelled'
                      ? AppColors.textSecondary
                      : checkin.status == 'escalated'
                          ? AppColors.danger
                          : checkin.needsAcknowledgement
                              ? AppColors.warning
                              : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEE d MMM, HH:mm').format(checkin.scheduledFor),
                      style: AppTextStyles.bodyMedium),
                  Text(
                    checkin.status == 'escalated' ? 'Missed check-in' : checkin.status,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (canAct)
              if (isBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onAcknowledge,
                      icon: const Icon(Icons.check, color: AppColors.success),
                      tooltip: "I'm okay",
                    ),
                    IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, color: AppColors.danger),
                      tooltip: 'Cancel',
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
