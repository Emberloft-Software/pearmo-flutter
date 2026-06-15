import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/report.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// Reports a user (optionally tied to a connection). The primary,
/// schema-backed safety mechanism — moderation happens off-device.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.reportedId, this.connectionId});

  final String reportedId;
  final String? connectionId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _descriptionController = TextEditingController();
  ReportCategory _category = ReportCategory.harassment;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(String reporterId) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(reportsRepositoryProvider).submitReport(Report(
            reporterId: reporterId,
            reportedId: widget.reportedId,
            connectionId: widget.connectionId,
            category: _category,
            description: _descriptionController.text.trim(),
          ));
      setState(() => _submitted = true);
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: _submitted
          ? const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Report submitted',
              message: "Thanks for letting us know — our team will review this. You're not "
                  'alone, and your safety matters to us.',
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Tell us what happened. Reports are confidential and help keep Pearmo safe.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Reason'),
                RadioGroup<ReportCategory>(
                  groupValue: _category,
                  onChanged: (value) => setState(() => _category = value!),
                  child: Column(
                    children: ReportCategory.values
                        .map((category) => RadioListTile<ReportCategory>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(category.label),
                              value: category,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Details'),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Share any details that will help our team review this...',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 24),
                PearmoButton(
                  label: 'Submit report',
                  variant: PearmoButtonVariant.danger,
                  icon: Icons.flag_outlined,
                  isLoading: _isSubmitting,
                  onPressed: (_isSubmitting || userId == null) ? null : () => _submit(userId),
                ),
              ],
            ),
    );
  }
}
