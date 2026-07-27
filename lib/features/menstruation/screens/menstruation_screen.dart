import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/menstruation/providers/menstruation_provider.dart';
import 'package:intl/intl.dart';

class MenstruationScreen extends ConsumerStatefulWidget {
  const MenstruationScreen({super.key});

  @override
  ConsumerState<MenstruationScreen> createState() => _MenstruationScreenState();
}

class _MenstruationScreenState extends ConsumerState<MenstruationScreen> {
  void _showLogDialog({String? id, DateTime? initialStart, DateTime? initialEnd, String? initialFlow, String? initialNotes}) {
    showDialog(
      context: context,
      builder: (context) => _LogDialog(
        id: id,
        initialStart: initialStart,
        initialEnd: initialEnd,
        initialFlow: initialFlow,
        initialNotes: initialNotes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(menstruationLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Menstruation Logging'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLogDialog(),
        backgroundColor: AppColors.primary,
        tooltip: 'Log Cycle',
        child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 26),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(menstruationLogsProvider);
        },
        child: logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.water_drop_outlined, size: 64, color: AppColors.textDisabled),
                        const SizedBox(height: 16),
                        Text('No logs yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Tap + Log Cycle to record your period', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled)),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final log = logs[i];
                final isOngoing = log.endDate == null;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOngoing ? AppColors.accent : AppColors.border,
                      width: isOngoing ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  '${DateFormat('MMM d, yyyy').format(log.startDate)} - ${log.endDate != null ? DateFormat('MMM d, yyyy').format(log.endDate!) : 'Ongoing'}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (isOngoing)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Ongoing',
                                      style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showLogDialog(
                                  id: log.id,
                                  initialStart: log.startDate,
                                  initialEnd: log.endDate,
                                  initialFlow: log.flowIntensity,
                                  initialNotes: log.notes,
                                );
                              } else if (val == 'end_today') {
                                ref.read(menstruationControllerProvider.notifier).updateLog(
                                      id: log.id,
                                      endDate: DateTime.now(),
                                    );
                              } else if (val == 'delete') {
                                ref.read(menstruationControllerProvider.notifier).deleteLog(log.id);
                              }
                            },
                            itemBuilder: (ctx) => [
                              if (isOngoing)
                                const PopupMenuItem(value: 'end_today', child: Text('Mark Ended Today')),
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                            ],
                          ),
                        ],
                      ),
                      if (log.flowIntensity != null) ...[
                        const SizedBox(height: 8),
                        Text('Flow: ${log.flowIntensity}', style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                      if (log.notes != null && log.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Notes: ${log.notes}', style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Failed to load logs: $err',
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogDialog extends ConsumerStatefulWidget {
  final String? id;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final String? initialFlow;
  final String? initialNotes;

  const _LogDialog({this.id, this.initialStart, this.initialEnd, this.initialFlow, this.initialNotes});

  @override
  ConsumerState<_LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends ConsumerState<_LogDialog> {
  late DateTime _startDate;
  DateTime? _endDate;
  String? _flow;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStart ?? DateTime.now();
    _endDate = widget.initialEnd;
    _flow = widget.initialFlow;
    _notesCtrl = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      title: Text(widget.id == null ? 'Log Menstruation' : 'Edit Log'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date'),
              subtitle: Text(DateFormat('MMM d, yyyy').format(_startDate)),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _startDate = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End Date (Optional)'),
              subtitle: Text(_endDate != null ? DateFormat('MMM d, yyyy').format(_endDate!) : 'Ongoing / Not set'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                      onPressed: () => setState(() => _endDate = null),
                      tooltip: 'Clear End Date',
                    ),
                  const Icon(Icons.calendar_today, size: 20),
                ],
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? _startDate,
                  firstDate: _startDate,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _endDate = d);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _flow,
              decoration: const InputDecoration(labelText: 'Flow Intensity'),
              dropdownColor: AppColors.surfaceCard,
              items: ['Light', 'Medium', 'Heavy'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _flow = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final ctrl = ref.read(menstruationControllerProvider.notifier);
            try {
              if (widget.id == null) {
                await ctrl.addLog(
                  startDate: _startDate,
                  endDate: _endDate,
                  flowIntensity: _flow,
                  notes: _notesCtrl.text,
                );
              } else {
                await ctrl.updateLog(
                  id: widget.id!,
                  startDate: _startDate,
                  endDate: _endDate,
                  flowIntensity: _flow,
                  notes: _notesCtrl.text,
                );
              }
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving: $e')),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
