import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';
import 'package:intl/intl.dart';

class ChooseDateScreen extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const ChooseDateScreen({
    super.key,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<ChooseDateScreen> createState() => _ChooseDateScreenState();
}

class _ChooseDateScreenState extends State<ChooseDateScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  late DateTime _focusedMonth;

  // Which field is being picked: 'start' or 'end'
  String _picking = 'start';

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStart;
    _endDate   = widget.initialEnd;
    final now  = DateTime.now();
    _focusedMonth = DateTime(
      (_startDate ?? now).year,
      (_startDate ?? now).month,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('MM/dd/yyyy').format(d);

  String _monthName(int m) => const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ][m - 1];

  void _prevMonth() => setState(() =>
  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));

  void _nextMonth() => setState(() =>
  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));

  void _onDayTap(DateTime date) {
    setState(() {
      if (_picking == 'start') {
        _startDate = date;
        // If end is before new start, clear it
        if (_endDate != null && _endDate!.isBefore(date)) _endDate = null;
        _picking = 'end';
      } else {
        if (date.isBefore(_startDate ?? date)) {
          // Tapped before start → reset and pick start again
          _startDate = date;
          _endDate   = null;
          _picking   = 'end';
        } else {
          _endDate = date;
          _picking = 'start';
        }
      }
    });
  }

  bool _isInRange(DateTime date) {
    if (_startDate == null || _endDate == null) return false;
    return date.isAfter(_startDate!) && date.isBefore(_endDate!);
  }

  bool _isStart(DateTime date) =>
      _startDate != null && _isSameDay(date, _startDate!);

  bool _isEnd(DateTime date) =>
      _endDate != null && _isSameDay(date, _endDate!);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.primary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Choose a date',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Date range pickers ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _dateField('Start Date', _startDate, 'start')),
                  const SizedBox(width: 16),
                  Expanded(child: _dateField('End Date', _endDate, 'end')),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Hint text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    _picking == 'start'
                        ? Icons.touch_app_rounded
                        : Icons.touch_app_rounded,
                    size: 13,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _picking == 'start'
                        ? 'Tap a day to set the start date'
                        : 'Tap a day to set the end date',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Divider ────────────────────────────────────────────────────
            Container(height: 1, color: const Color(0xFFEEEFF1)),

            // ── Calendar ───────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    // Month nav
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _navButton(Icons.chevron_left_rounded, _prevMonth),
                        Text(
                          '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        _navButton(Icons.chevron_right_rounded, _nextMonth),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Day headers
                    Row(
                      children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                          .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ))
                          .toList(),
                    ),

                    const SizedBox(height: 8),

                    // Calendar grid
                    _buildGrid(),
                  ],
                ),
              ),
            ),

            // ── Divider ────────────────────────────────────────────────────
            Container(height: 1, color: const Color(0xFFEEEFF1)),

            // ── Bottom actions ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  // Reset
                  GestureDetector(
                    onTap: () => setState(() {
                      _startDate = null;
                      _endDate   = null;
                      _picking   = 'start';
                    }),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D0D0D),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Save date range
                  GestureDetector(
                    onTap: _startDate == null
                        ? null
                        : () => Navigator.pop(context, {
                      'start': _startDate,
                      'end': _endDate ?? _startDate,
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: _startDate == null
                            ? Colors.grey.shade200
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: _startDate == null
                            ? []
                            : [
                          BoxShadow(
                            color:
                            AppColors.primary.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Save date range',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _startDate == null
                              ? Colors.grey
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date field widget ─────────────────────────────────────────────────────
  Widget _dateField(String label, DateTime? date, String field) {
    final isActive = _picking == field;
    return GestureDetector(
      onTap: () => setState(() => _picking = field),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? AppColors.primary : const Color(0xFFDDDEE1),
            width: isActive ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.primary : const Color(0xFF888A90),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmt(date),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: date == null
                    ? Colors.grey.shade400
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nav button ────────────────────────────────────────────────────────────
  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }

  // ── Calendar grid ─────────────────────────────────────────────────────────
  Widget _buildGrid() {
    final firstDay  = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final List<Widget> cells = [];
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date    = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final isStart = _isStart(date);
      final isEnd   = _isEnd(date);
      final inRange = _isInRange(date);
      final isToday = _isSameDay(date, todayKey);
      final isPast  = date.isBefore(todayKey);

      // Range highlight background spans full cell width
      Widget rangeHighlight = const SizedBox.shrink();
      if (inRange) {
        rangeHighlight = Positioned.fill(
          child: Container(color: AppColors.primary.withOpacity(0.08)),
        );
      } else if (isStart && _endDate != null) {
        rangeHighlight = Positioned.fill(
          child: Row(
            children: [
              const Expanded(child: SizedBox()),
              Expanded(
                child: Container(
                    color: AppColors.primary.withOpacity(0.08)),
              ),
            ],
          ),
        );
      } else if (isEnd) {
        rangeHighlight = Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: Container(
                    color: AppColors.primary.withOpacity(0.08)),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        );
      }

      cells.add(
        GestureDetector(
          onTap: isPast && !isToday ? null : () => _onDayTap(date),
          child: Stack(
            alignment: Alignment.center,
            children: [
              rangeHighlight,
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isStart || isEnd)
                      ? AppColors.primary
                      : isToday
                      ? AppColors.primary.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: (isStart || isEnd || isToday)
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: (isStart || isEnd)
                          ? Colors.white
                          : isPast
                          ? Colors.grey.shade300
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: cells,
    );
  }
}