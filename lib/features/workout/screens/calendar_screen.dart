import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/menstruation/models/menstruation_log_model.dart';
import 'package:gym_tracker/features/menstruation/providers/menstruation_provider.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:gym_tracker/features/workout/widgets/session_history_card.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInPeriodRange(DateTime cellDate, MenstruationLogModel log) {
    final start = DateTime(log.startDate.year, log.startDate.month, log.startDate.day);
    final end = log.endDate != null
        ? DateTime(log.endDate!.year, log.endDate!.month, log.endDate!.day)
        : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final cell = DateTime(cellDate.year, cellDate.month, cellDate.day);
    return (cell.isAfter(start) || cell.isAtSameMomentAs(start)) &&
        (cell.isBefore(end) || cell.isAtSameMomentAs(end));
  }

  Widget _buildMonthHeader() {
    final monthFormat = DateFormat('MMMM yyyy');
    final isCurrentMonth = _focusedMonth.year == DateTime.now().year && _focusedMonth.month == DateTime.now().month;

    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
            });
          },
          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
          tooltip: 'Previous month',
        ),
        Expanded(
          child: Center(
            child: Text(
              monthFormat.format(_focusedMonth),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
            ),
          ),
        ),
        if (!isCurrentMonth)
          TextButton(
            onPressed: () {
              setState(() {
                final now = DateTime.now();
                _focusedMonth = DateTime(now.year, now.month, 1);
                _selectedDate = DateTime(now.year, now.month, now.day);
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('TODAY', style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
            });
          },
          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
          tooltip: 'Next month',
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(List<WorkoutSessionModel> sessions, List<MenstruationLogModel> menstruationLogs) {
    const weekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalGridCells = startOffset + daysInMonth;
    final totalRows = ((totalGridCells + 6) / 7).floor();
    final totalCells = totalRows * 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: weekDays
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startOffset + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
              final daySessions = sessions.where((s) => _isSameDay(s.completedAt ?? s.startedAt, cellDate)).toList();
              final periodLogs = menstruationLogs.where((m) => _isInPeriodRange(cellDate, m)).toList();
              final isPeriodDay = periodLogs.isNotEmpty;

              final hasActivity = daySessions.isNotEmpty;
              final hasGym = daySessions.any((s) => !s.isRestDay && !s.isCardio);
              final hasRestDay = daySessions.any((s) => s.isRestDay);
              final hasCardio = daySessions.any((s) => s.isCardio);
              final hasMakeUp = daySessions.any((s) => s.wasMakeUpSession);
              final isToday = _isSameDay(DateTime.now(), cellDate);
              final isSelected = _isSameDay(_selectedDate, cellDate);

              IconData flagIcon = Icons.flag_rounded;
              Color flagColor = AppColors.primary;
              if (hasGym) {
                flagIcon = Icons.flag_rounded;
                flagColor = hasMakeUp ? AppColors.warning : AppColors.primary;
              } else if (hasRestDay) {
                flagIcon = Icons.bed_rounded;
                flagColor = AppColors.info;
              } else if (hasCardio) {
                flagIcon = Icons.directions_run_rounded;
                flagColor = AppColors.warning;
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = cellDate;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryMuted
                        : (isToday ? AppColors.surfaceVariant : (isPeriodDay ? AppColors.error.withValues(alpha: 0.08) : AppColors.background)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isPeriodDay ? AppColors.error.withValues(alpha: 0.4) : (isToday ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.5))),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontFamily: 'Barlow',
                              fontWeight: isSelected || isToday || hasActivity || isPeriodDay ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isToday ? AppColors.textPrimary : (hasActivity ? AppColors.textPrimary : AppColors.textSecondary)),
                            ),
                          ),
                          if (isPeriodDay) ...[
                            const SizedBox(width: 2),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (hasActivity)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: flagColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(flagIcon, size: 10, color: flagColor),
                              if (daySessions.length > 1) ...[
                                const SizedBox(width: 1),
                                Text(
                                  '${daySessions.length}',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: flagColor),
                                ),
                              ],
                            ],
                          ),
                        )
                      else if (isPeriodDay)
                        const Icon(Icons.water_drop_rounded, size: 10, color: AppColors.error)
                      else
                        const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsForSelectedDate(List<WorkoutSessionModel> sessions, List<MenstruationLogModel> menstruationLogs) {
    final selectedSessions = sessions.where((s) => _isSameDay(s.completedAt ?? s.startedAt, _selectedDate)).toList();
    final periodLogs = menstruationLogs.where((m) => _isInPeriodRange(_selectedDate, m)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (periodLogs.isNotEmpty)
          ...periodLogs.map((log) {
            final isOngoing = log.endDate == null;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: AppColors.error, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menstruation Cycle (${isOngoing ? 'Ongoing' : 'Recorded'})',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                        if (log.flowIntensity != null)
                          Text('Flow: ${log.flowIntensity}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        if (log.notes != null && log.notes!.isNotEmpty)
                          Text('Notes: ${log.notes}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        if (selectedSessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.event_available_outlined, color: AppColors.textDisabled, size: 36),
                const SizedBox(height: 8),
                Text(
                  'No workout logged for this day',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          ...selectedSessions.map((session) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SessionHistoryCard(session: session),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(sessionHistoryProvider);
    final menstruationAsync = ref.watch(menstruationLogsProvider);
    final menstruationLogs = menstruationAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Calendar'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceCard,
        onRefresh: () async {
          ref.invalidate(sessionHistoryProvider);
          ref.invalidate(menstruationLogsProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: historyAsync.when(
          data: (sessions) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthHeader(),
                  const SizedBox(height: 12),
                  _buildCalendarGrid(sessions, menstruationLogs),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMM d, y').format(_selectedDate),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'BarlowCondensed',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailsForSelectedDate(sessions, menstruationLogs),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, __) => const Center(child: Text('Failed to load history')),
        ),
      ),
    );
  }
}
