import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/widgets/event_card_full.dart';
import 'package:pikuru/screens/calendar_events_screen.dart';
import 'package:pikuru/screens/choose_date_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── Filter state ──────────────────────────────────────────────────────────
  String _selectedFilter = 'Upcoming';
  DateTime? _customStart;
  DateTime? _customEnd;

  bool get _hasCustomRange => _customStart != null;

  static const _filterOptions = [
    ('Upcoming',  Icons.bolt_rounded),
    ('Today',     Icons.wb_sunny_rounded),
    ('Tomorrow',  Icons.arrow_forward_rounded),
    ('This Week', Icons.date_range_rounded),
    ('Weekend',   Icons.weekend_rounded),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Filter modal ──────────────────────────────────────────────────────────
  void _showFilterModal() {
    String tempFilter      = _selectedFilter;
    DateTime? tempStart    = _customStart;
    DateTime? tempEnd      = _customEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final hasRange = tempStart != null;
          final fmt = DateFormat('MM/dd/yyyy');

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter',
                        style: TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D0D0D),
                            letterSpacing: -0.4)),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded,
                            color: AppColors.primary, size: 18),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text('DATE',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF888A90),
                        letterSpacing: 1.0)),

                const SizedBox(height: 12),

                // Quick filter options
                ..._filterOptions.map((opt) {
                  final label = opt.$1;
                  final icon  = opt.$2;
                  final isSelected = !hasRange && tempFilter == label;
                  return GestureDetector(
                    onTap: () => setModalState(() {
                      tempFilter = label;
                      tempStart  = null;
                      tempEnd    = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.07)
                            : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.4)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(icon, size: 16,
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFF888A90)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFF0D0D0D),
                                )),
                          ),
                          // Radio circle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFFCCCDD0),
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                              child: Container(
                                width: 9, height: 9,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // ── Choose a date row ──────────────────────────────────────
                GestureDetector(
                  onTap: () async {
                    // Push ChooseDateScreen and wait for result
                    final result = await Navigator.push<Map<String, DateTime?>>(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => ChooseDateScreen(
                          initialStart: tempStart,
                          initialEnd: tempEnd,
                        ),
                      ),
                    );
                    if (result != null) {
                      setModalState(() {
                        tempStart  = result['start'];
                        tempEnd    = result['end'];
                        tempFilter = 'Upcoming'; // deselect chips
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: hasRange
                          ? AppColors.primary.withOpacity(0.07)
                          : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasRange
                            ? AppColors.primary.withOpacity(0.4)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: hasRange
                                ? AppColors.primary.withOpacity(0.12)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(Icons.calendar_month_rounded,
                              size: 16,
                              color: hasRange
                                  ? AppColors.primary
                                  : const Color(0xFF888A90)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: hasRange
                              ? Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text('Custom date range',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                tempEnd != null &&
                                    !_isSameDay(
                                        tempStart!, tempEnd!)
                                    ? '${fmt.format(tempStart!)}  →  ${fmt.format(tempEnd!)}'
                                    : fmt.format(tempStart!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary
                                      .withOpacity(0.7),
                                ),
                              ),
                            ],
                          )
                              : const Text('Choose a date',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D0D0D),
                              )),
                        ),
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: hasRange
                                    ? AppColors.primary
                                    : const Color(0xFFCCCDD0),
                                width: 1.5),
                          ),
                          child: Icon(
                            hasRange
                                ? Icons.edit_rounded
                                : Icons.arrow_forward_rounded,
                            size: 14,
                            color: hasRange
                                ? AppColors.primary
                                : const Color(0xFF888A90),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Action buttons ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() {
                          tempFilter = 'Upcoming';
                          tempStart  = null;
                          tempEnd    = null;
                        }),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.primary, width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text('Clear',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                )),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilter = tempFilter;
                            _customStart    = tempStart;
                            _customEnd      = tempEnd;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color:
                                AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('APPLY',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Filter logic ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilter(
      List<Map<String, dynamic>> events) {
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final daysUntilSat = (DateTime.saturday - now.weekday + 7) % 7;
    final saturday =
    today.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
    final sunday     = saturday.add(const Duration(days: 1));
    final endOfWeek  = today.add(Duration(days: 7 - now.weekday));

    final q = _searchController.text.toLowerCase().trim();
    final searched = events.where((e) {
      if (q.isEmpty) return true;
      return (e['event_title'] ?? '').toString().toLowerCase().contains(q) ||
          (e['event_type'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return searched.where((e) {
      final raw = e['event_date'];
      DateTime? d;
      if (raw is Timestamp) d = raw.toDate();
      else if (raw is String && raw.isNotEmpty) {
        try { d = DateTime.parse(raw); } catch (_) {}
      }
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);

      // Custom date range takes priority
      if (_hasCustomRange) {
        final start = _customStart!;
        final end   = _customEnd ?? start;
        return !day.isBefore(start) && !day.isAfter(end);
      }

      switch (_selectedFilter) {
        case 'Today':     return _isSameDay(day, today);
        case 'Tomorrow':  return _isSameDay(day, tomorrow);
        case 'This Week': return !day.isBefore(today) && !day.isAfter(endOfWeek);
        case 'Weekend':   return _isSameDay(day, saturday) || _isSameDay(day, sunday);
        default:          return !day.isBefore(today);
      }
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showAddButton = ref.watch(showAddEventButtonProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildEventsList()),
              ],
            ),
            if (showAddButton)
              Positioned(
                bottom: 24, left: 0, right: 0,
                child: Center(child: _buildAddEventButton()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isFiltered = _selectedFilter != 'Upcoming' || _hasCustomRange;
    final fmt = DateFormat('MMM d');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title + active range badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Events',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D0D0D),
                          letterSpacing: -0.5,
                        )),
                    if (_hasCustomRange) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => setState(() {
                          _customStart = null;
                          _customEnd   = null;
                          _selectedFilter = 'Upcoming';
                        }),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 11,
                                      color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    _customEnd != null &&
                                        !_isSameDay(
                                            _customStart!, _customEnd!)
                                        ? '${fmt.format(_customStart!)} – ${fmt.format(_customEnd!)}'
                                        : fmt.format(_customStart!),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(Icons.close_rounded,
                                      size: 11,
                                      color: AppColors.primary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  // Filter button
                  GestureDetector(
                    onTap: _showFilterModal,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: isFiltered
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tune_rounded,
                              color: isFiltered
                                  ? Colors.white
                                  : AppColors.primary,
                              size: 20),
                        ),
                        if (isFiltered)
                          Positioned(
                            top: -3, right: -3,
                            child: Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Container(
                                  width: 7, height: 7,
                                  decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Calendar button
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const CalendarEventsScreen())),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  fontSize: 15, color: Color(0xFF0D0D0D)),
              decoration: InputDecoration(
                hintText: 'Search events, type...',
                hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.35),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.black.withOpacity(0.35), size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                  onTap: () =>
                      setState(() => _searchController.clear()),
                  child: Icon(Icons.close_rounded,
                      color: Colors.black.withOpacity(0.35),
                      size: 20),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _filterChip('Upcoming',  icon: Icons.bolt_rounded),
                _filterChip('Today',     icon: Icons.wb_sunny_rounded),
                _filterChip('Tomorrow',  icon: Icons.arrow_forward_rounded),
                _filterChip('This Week', icon: Icons.date_range_rounded),
                _filterChip('Weekend',   icon: Icons.weekend_rounded),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 1, color: const Color(0xFFEEEFF1)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, {required IconData icon}) {
    final isSelected = !_hasCustomRange && _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilter = label;
        _customStart    = null;
        _customEnd      = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : const Color(0xFFDDDEE1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF888A90)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF555760),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    final eventsAsync = ref.watch(eventsProvider);
    return eventsAsync.when(
      data: (events) {
        final filtered = _applyFilter(events);
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy_rounded,
                    size: 56,
                    color: Colors.black.withOpacity(0.12)),
                const SizedBox(height: 14),
                Text(
                  _hasCustomRange
                      ? 'No events in this date range.'
                      : {
                    'Today':     'No events today.',
                    'Tomorrow':  'No events tomorrow.',
                    'This Week': 'No events this week.',
                    'Weekend':   'No events this weekend.',
                    'Upcoming':  'No upcoming events in the next 30 days.',
                  }[_selectedFilter] ?? 'No events found.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black.withOpacity(0.35),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              EventCardFull(event: filtered[index]),
        );
      },
      loading: () => Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5)),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Something went wrong.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.black45, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildAddEventButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 36),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Add an Event',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  )),
            ],
          ),
        ),
        Positioned(
          top: -8, right: -8,
          child: GestureDetector(
            onTap: () => ref
                .read(showAddEventButtonProvider.notifier)
                .state = false,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF0D0D0D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Color(0xFF0D0D0D)),
            ),
          ),
        ),
      ],
    );
  }
}