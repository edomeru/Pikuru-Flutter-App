import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/widgets/event_card_full.dart';
import 'package:pikuru/screens/calendar_events_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'Upcoming';

  // ── Filter modal options ──────────────────────────────────────────────────
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

  // ── Show filter bottom sheet ──────────────────────────────────────────────
  void _showFilterModal() {
    // Temp selection inside modal
    String tempFilter = _selectedFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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
                  // ── Drag handle ───────────────────────────────────────
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Header ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D0D0D),
                          letterSpacing: -0.4,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 34,
                          height: 34,
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

                  // ── Section label ─────────────────────────────────────
                  const Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF888A90),
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Filter options ────────────────────────────────────
                  ..._filterOptions.map((opt) {
                    final label = opt.$1;
                    final icon  = opt.$2;
                    final isSelected = tempFilter == label;
                    return GestureDetector(
                      onTap: () => setModalState(() => tempFilter = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.12)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon,
                                  size: 17,
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFF888A90)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFF0D0D0D),
                                ),
                              ),
                            ),
                            // Radio-style indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22,
                              height: 22,
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
                                  width: 10,
                                  height: 10,
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

                  // ── Choose a date row ─────────────────────────────────
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CalendarEventsScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_month_rounded,
                                size: 17, color: Color(0xFF888A90)),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Choose a date',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D0D0D),
                              ),
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.primary, width: 1.5),
                            ),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 16, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Action buttons ────────────────────────────────────
                  Row(
                    children: [
                      // Clear
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() => tempFilter = 'Upcoming');
                          },
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.primary, width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Apply
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedFilter = tempFilter);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'APPLY',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final daysUntilSaturday = (DateTime.saturday - now.weekday + 7) % 7;
    final saturday =
    today.add(Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
    final sunday = saturday.add(const Duration(days: 1));
    // This week = today through Sunday
    final endOfWeek = today.add(Duration(days: 7 - now.weekday));

    final searchQuery = _searchController.text.toLowerCase().trim();
    List<Map<String, dynamic>> filtered = events.where((e) {
      if (searchQuery.isEmpty) return true;
      final title = (e['event_title'] ?? '').toString().toLowerCase();
      final type = (e['event_type'] ?? '').toString().toLowerCase();
      return title.contains(searchQuery) || type.contains(searchQuery);
    }).toList();

    return filtered.where((e) {
      final raw = e['event_date'];
      DateTime? eventDate;
      if (raw is Timestamp) {
        eventDate = raw.toDate();
      } else if (raw is String && raw.isNotEmpty) {
        try {
          eventDate = DateTime.parse(raw);
        } catch (_) {}
      }
      if (eventDate == null) return false;
      final eventDay =
      DateTime(eventDate.year, eventDate.month, eventDate.day);
      switch (_selectedFilter) {
        case 'Today':
          return eventDay.isAtSameMomentAs(today);
        case 'Tomorrow':
          return eventDay.isAtSameMomentAs(tomorrow);
        case 'This Week':
          return !eventDay.isBefore(today) && !eventDay.isAfter(endOfWeek);
        case 'Weekend':
          return eventDay.isAtSameMomentAs(saturday) ||
              eventDay.isAtSameMomentAs(sunday);
        default:
          return !eventDay.isBefore(today);
      }
    }).toList();
  }

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
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(child: _buildAddEventButton()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Show active filter badge if not default
    final isFiltered = _selectedFilter != 'Upcoming';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Events',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D0D0D),
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  // ── Filter button ─────────────────────────────────────
                  GestureDetector(
                    onTap: _showFilterModal,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
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
                        // Active filter dot
                        if (isFiltered)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ── Calendar button ───────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CalendarEventsScreen()),
                    ),
                    child: Container(
                      width: 42,
                      height: 42,
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

          // ── Search Bar ─────────────────────────────────────────────────
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style:
              const TextStyle(fontSize: 15, color: Color(0xFF0D0D0D)),
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

          // ── Filter chips (quick access) ────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _filterChip('Upcoming', icon: Icons.bolt_rounded),
                _filterChip('Today', icon: Icons.wb_sunny_rounded),
                _filterChip('Tomorrow', icon: Icons.arrow_forward_rounded),
                _filterChip('This Week', icon: Icons.date_range_rounded),
                _filterChip('Weekend', icon: Icons.weekend_rounded),
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
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, bottom: 12),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color:
          isSelected ? AppColors.primary : Colors.transparent,
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
            Icon(icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF888A90)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF555760),
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
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
          final emptyMessages = {
            'Today': 'No events today.',
            'Tomorrow': 'No events tomorrow.',
            'This Week': 'No events this week.',
            'Weekend': 'No events this weekend.',
            'Upcoming': 'No upcoming events in the next 30 days.',
          };
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy_rounded,
                    size: 56,
                    color: Colors.black.withOpacity(0.12)),
                const SizedBox(height: 14),
                Text(
                  emptyMessages[_selectedFilter] ?? 'No events found.',
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
            color: AppColors.primary, strokeWidth: 2.5),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Something went wrong.\n$error',
            textAlign: TextAlign.center,
            style:
            const TextStyle(color: Colors.black45, fontSize: 14),
          ),
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
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Add an Event',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: () =>
            ref.read(showAddEventButtonProvider.notifier).state =
            false,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF0D0D0D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
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