import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:intl/intl.dart';

class CalendarEventsScreen extends ConsumerStatefulWidget {
  const CalendarEventsScreen({super.key});

  @override
  ConsumerState<CalendarEventsScreen> createState() =>
      _CalendarEventsScreenState();
}

class _CalendarEventsScreenState
    extends ConsumerState<CalendarEventsScreen>
    with TickerProviderStateMixin {
  late DateTime _focusedMonth;
  DateTime? _selectedDate;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450))
      ..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Build a map: normalised date → list of events ─────────────────────────
  Map<DateTime, List<Map<String, dynamic>>> _buildEventMap(
      List<Map<String, dynamic>> events) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final e in events) {
      // ✅ Use event_date (new field) — fallback to event_start_date (old)
      final ts = e['event_date'] ?? e['event_start_date'];
      if (ts == null) continue;
      final dt = (ts as Timestamp).toDate();
      final key = DateTime(dt.year, dt.month, dt.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  List<Map<String, dynamic>> _eventsForDate(
      Map<DateTime, List<Map<String, dynamic>>> map, DateTime date) {
    return map[DateTime(date.year, date.month, date.day)] ?? [];
  }

  void _prevMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
  });

  void _nextMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
  });

  String _monthName(int m) => const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ][m - 1];

  Future<void> _openEventLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open link'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Use the calendarEventsProvider from providers.dart (event_date field)
    final eventsAsync = ref.watch(calendarEventsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: eventsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (events) {
          final eventMap = _buildEventMap(events);
          final selectedEvents = _selectedDate != null
              ? _eventsForDate(eventMap, _selectedDate!)
              : <Map<String, dynamic>>[];

          return CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Calendar Events',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        // ── Calendar Card ────────────────────────────────
                        Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Month navigation
                              Padding(
                                padding:
                                const EdgeInsets.fromLTRB(20, 20, 20, 8),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      onPressed: _prevMonth,
                                      icon: const Icon(
                                          Icons.chevron_left_rounded,
                                          color: AppColors.primary,
                                          size: 28),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    Text(
                                      '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A1A1A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _nextMonth,
                                      icon: const Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.primary,
                                          size: 28),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),

                              // Day-of-week headers
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Row(
                                  children: ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA']
                                      .map((d) => Expanded(
                                    child: Center(
                                      child: Text(
                                        d,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade400,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ))
                                      .toList(),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Calendar grid
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                child: _buildCalendarGrid(eventMap),
                              ),
                            ],
                          ),
                        ),

                        // ── Selected date header ─────────────────────────
                        if (_selectedDate != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatSelectedDate(_selectedDate!),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Spacer(),
                                if (selectedEvents.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                      AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${selectedEvents.length} event${selectedEvents.length == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // ── Event cards or empty state ───────────────
                          if (selectedEvents.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                  Border.all(color: Colors.grey.shade100),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.event_available_rounded,
                                        color: Colors.grey.shade300, size: 32),
                                    const SizedBox(width: 16),
                                    Text(
                                      'No events on this day',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...selectedEvents.map(
                                  (e) => _EventCard(
                                event: e,
                                onOpenLink: _openEventLink,
                              ),
                            ),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Calendar Grid ─────────────────────────────────────────────────────────
  Widget _buildCalendarGrid(
      Map<DateTime, List<Map<String, dynamic>>> eventMap) {
    final firstDay =
    DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final List<Widget> cells = [];

    // Leading empty cells
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final dayEvents = _eventsForDate(eventMap, date);
      final hasEvents = dayEvents.isNotEmpty;
      final isToday = date == todayKey;
      final isSelected = _selectedDate != null &&
          date ==
              DateTime(_selectedDate!.year, _selectedDate!.month,
                  _selectedDate!.day);
      final isPast = date.isBefore(todayKey);

      if (hasEvents) {
        cells.add(
          GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: _EventThumbCell(
              day: day,
              events: dayEvents,
              isSelected: isSelected,
              isToday: isToday,
              isPast: isPast,
            ),
          ),
        );
      } else {
        cells.add(
          GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : isPast
                        ? Colors.grey.shade300
                        : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.78,
      children: cells,
    );
  }

  String _formatSelectedDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Event Thumbnail Cell ─────────────────────────────────────────────────────
// Fills the grid cell with the event's image. The day number and event
// count badge are overlaid on top, matching the design screenshot.
class _EventThumbCell extends StatelessWidget {
  final int day;
  final List<Map<String, dynamic>> events;
  final bool isSelected;
  final bool isToday;
  final bool isPast;

  const _EventThumbCell({
    required this.day,
    required this.events,
    required this.isSelected,
    required this.isToday,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final count = events.length;
    // Pick image from first event using new field names with fallback
    final imageUrl = (events.first['event_pic'] ??
        events.first['event_pic_thumbnail'] ??
        events.first['event_image'] ??
        '')
        .toString();

    return Container(
      margin: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background image ───────────────────────────────────
            imageUrl.isNotEmpty
                ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.primary.withOpacity(0.15),
                child: const Icon(Icons.event,
                    size: 16, color: AppColors.primary),
              ),
            )
                : Container(
              color: AppColors.primary.withOpacity(0.15),
              child: const Icon(Icons.event,
                  size: 16, color: AppColors.primary),
            ),

            // ── Dark overlay so text is readable ──────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.08),
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),

            // ── Selected green overlay ─────────────────────────────
            if (isSelected)
              Container(
                color: AppColors.primary.withOpacity(0.55),
              ),

            // ── Day number — bottom left ───────────────────────────
            Positioned(
              left: 5,
              bottom: 4,
              child: Text(
                '$day',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),

            // ── Event count badge — top right ──────────────────────
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? AppColors.primary : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event Card shown below calendar ──────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final Future<void> Function(String url) onOpenLink;

  const _EventCard({required this.event, required this.onOpenLink});

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    DateTime dt;
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else {
      return raw.toString();
    }
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final title = (event['event_title'] ?? 'Untitled Event').toString();

    // ✅ Use new image fields with fallback chain
    final imageUrl = (event['event_pic'] ??
        event['event_pic_thumbnail'] ??
        event['event_image'] ??
        '')
        .toString();

    final url = (event['event_link'] ?? event['event_url'] ?? '').toString();

    final fee = event['event_fee'];
    final feeStr = (fee == null ||
        fee.toString().isEmpty ||
        fee.toString() == '0' ||
        fee.toString() == '0.0')
        ? 'Free'
        : '¥${fee.toString()}';

    // ✅ Use event_time (new field) — fallback to event_start_time (old)
    final time = _formatTime(event['event_time'] ?? event['event_start_time']);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event image
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primary.withOpacity(0.08),
                    child: const Icon(Icons.event,
                        size: 40, color: AppColors.primary),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    // Fee badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: feeStr == 'Free'
                            ? Colors.green.shade50
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        feeStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: feeStr == 'Free'
                              ? Colors.green.shade600
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                if (time.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // More Information button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: url.isNotEmpty ? () => onOpenLink(url) : null,
                    icon: const Icon(Icons.open_in_new_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'More Information',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey.shade200,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}