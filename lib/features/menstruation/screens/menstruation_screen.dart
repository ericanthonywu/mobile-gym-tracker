import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/menstruation/models/menstruation_log_model.dart';
import 'package:gym_tracker/features/menstruation/providers/menstruation_provider.dart';
import 'package:intl/intl.dart';

class MenstruationScreen extends ConsumerWidget {
  const MenstruationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(menstruationLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Period Tracker',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
      body: logsAsync.when(
        data: (logs) {
          // Find any ongoing cycle (no end date)
          MenstruationLogModel? activeCycle;
          try {
            activeCycle = logs.firstWhere((l) => l.endDate == null);
          } catch (_) {
            activeCycle = null;
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceCard,
            onRefresh: () async => ref.invalidate(menstruationLogsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // ── Hero Status Card ──
                _CycleStatusCard(
                  activeCycle: activeCycle,
                  onStartCycle: () => _startCycle(context, ref),
                  onEndCycle: () => _endCycle(context, ref, activeCycle!),
                ),

                const SizedBox(height: 28),

                // ── History section ──
                if (logs.isNotEmpty) ...[
                  Text(
                    'CYCLE HISTORY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...logs.map((log) => _CycleHistoryTile(
                        log: log,
                        onDelete: () => _deleteLog(context, ref, log.id),
                        onEdit: () => _editLog(context, ref, log),
                      )),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }

  Future<void> _startCycle(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(menstruationControllerProvider.notifier).addLog(
            startDate: DateTime.now(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Period started — take care of yourself! 💗'),
            backgroundColor: AppColors.surfaceCard,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log cycle: $e')),
        );
      }
    }
  }

  Future<void> _endCycle(BuildContext context, WidgetRef ref, MenstruationLogModel activeCycle) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(menstruationControllerProvider.notifier).updateLog(
            id: activeCycle.id,
            endDate: DateTime.now(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Period ended — logged successfully! 🌸'),
            backgroundColor: AppColors.surfaceCard,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end cycle: $e')),
        );
      }
    }
  }

  Future<void> _deleteLog(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Delete Entry?'),
        content: const Text('This will permanently remove this cycle entry.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(menstruationControllerProvider.notifier).deleteLog(id);
    }
  }

  Future<void> _editLog(BuildContext context, WidgetRef ref, MenstruationLogModel log) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditCycleSheet(log: log),
    );
  }
}

// ---------------------------------------------------------------------------
// Cycle Status Hero Card
// ---------------------------------------------------------------------------
class _CycleStatusCard extends StatelessWidget {
  final MenstruationLogModel? activeCycle;
  final VoidCallback onStartCycle;
  final VoidCallback onEndCycle;

  const _CycleStatusCard({
    required this.activeCycle,
    required this.onStartCycle,
    required this.onEndCycle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeCycle != null;
    final accentColor = isActive ? const Color(0xFFFF6B8A) : AppColors.textSecondary;
    final startedAt = activeCycle?.startDate;
    final dayCount = startedAt != null ? DateTime.now().difference(startedAt).inDays + 1 : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFF2A1520), const Color(0xFF1A0D14)]
              : [AppColors.surfaceCard, AppColors.surfaceVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? accentColor.withOpacity(0.4) : AppColors.border,
          width: 1.5,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 6))]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'CYCLE IN PROGRESS' : 'NO ACTIVE CYCLE',
                      style: TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.5,
                        color: accentColor,
                      ),
                    ),
                    if (isActive && startedAt != null)
                      Text(
                        'Day $dayCount — started ${DateFormat('MMM d').format(startedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: accentColor.withOpacity(0.7),
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Big day counter (when active)
          if (isActive) ...[
            Center(
              child: Column(
                children: [
                  Text(
                    'Day',
                    style: TextStyle(
                      color: accentColor.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$dayCount',
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontSize: 80,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      height: 0.9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Action button
          SizedBox(
            width: double.infinity,
            child: isActive
                ? ElevatedButton.icon(
                    onPressed: onEndCycle,
                    icon: const Icon(Icons.stop_circle_outlined, size: 20),
                    label: const Text('END PERIOD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: onStartCycle,
                    icon: const Icon(Icons.water_drop_rounded, size: 20),
                    label: const Text('START PERIOD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
          ),

          if (!isActive) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Tap when your period begins — the calendar will update automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textDisabled,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cycle History Tile
// ---------------------------------------------------------------------------
class _CycleHistoryTile extends StatelessWidget {
  final MenstruationLogModel log;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CycleHistoryTile({
    required this.log,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isOngoing = log.endDate == null;
    final duration = log.endDate != null
        ? '${log.endDate!.difference(log.startDate).inDays + 1} days'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOngoing ? const Color(0xFFFF6B8A).withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOngoing
                  ? const Color(0xFFFF6B8A).withOpacity(0.15)
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOngoing ? Icons.water_drop_rounded : Icons.check_circle_outline_rounded,
              size: 20,
              color: isOngoing ? const Color(0xFFFF6B8A) : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d').format(log.startDate) +
                      (log.endDate != null
                          ? ' – ${DateFormat('MMM d, yyyy').format(log.endDate!)}'
                          : ' – Ongoing'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (duration != null)
                  Text(
                    duration,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                if (log.flowIntensity != null)
                  Text(
                    'Flow: ${log.flowIntensity}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textDisabled,
                        ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
            color: AppColors.surfaceCard,
            onSelected: (val) {
              if (val == 'edit') onEdit();
              if (val == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit Cycle Sheet (bottom sheet for editing start/end dates)
// ---------------------------------------------------------------------------
class _EditCycleSheet extends ConsumerStatefulWidget {
  final MenstruationLogModel log;

  const _EditCycleSheet({required this.log});

  @override
  ConsumerState<_EditCycleSheet> createState() => _EditCycleSheetState();
}

class _EditCycleSheetState extends ConsumerState<_EditCycleSheet> {
  late DateTime _startDate;
  DateTime? _endDate;
  String? _flow;
  late TextEditingController _notesCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.log.startDate;
    _endDate = widget.log.endDate;
    _flow = widget.log.flowIntensity;
    _notesCtrl = TextEditingController(text: widget.log.notes);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Edit Cycle Entry',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Start date
          _DateRow(
            label: 'Start Date',
            date: _startDate,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _startDate = d);
            },
          ),
          const SizedBox(height: 14),

          // End date
          _DateRow(
            label: 'End Date',
            date: _endDate,
            placeholder: 'Not ended yet',
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _endDate ?? _startDate,
                firstDate: _startDate,
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _endDate = d);
            },
            onClear: _endDate != null ? () => setState(() => _endDate = null) : null,
          ),
          const SizedBox(height: 14),

          // Flow intensity
          DropdownButtonFormField<String>(
            value: _flow,
            decoration: const InputDecoration(labelText: 'Flow Intensity (Optional)'),
            dropdownColor: AppColors.surfaceCard,
            items: ['Light', 'Medium', 'Heavy'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _flow = v),
          ),
          const SizedBox(height: 14),

          // Notes
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () async {
                setState(() => _isSaving = true);
                try {
                  await ref.read(menstruationControllerProvider.notifier).updateLog(
                        id: widget.log.id,
                        startDate: _startDate,
                        endDate: _endDate,
                        flowIntensity: _flow,
                        notes: _notesCtrl.text,
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    setState(() => _isSaving = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700),
              ),
              child: Text(_isSaving ? 'SAVING…' : 'SAVE CHANGES'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? date;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateRow({
    required this.label,
    required this.date,
    this.placeholder = 'Tap to select',
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(
                  date != null ? DateFormat('MMM d, yyyy').format(date!) : placeholder,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: date != null ? AppColors.textPrimary : AppColors.textDisabled,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
