import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/widgets/group_card_list.dart';
import 'package:pikuru/modal/group_filter_modal.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  GroupFilter _filter = GroupFilter.tokyo;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(showAddGroupButtonProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter => !_filter.isDefault;

  Future<void> _openFilter({
    required List<Map<String, dynamic>> allGroups,
    required Map<String, Map<String, dynamic>> locMap,
  }) async {
    final result = await GroupFilterModal.show(
      context,
      currentFilter: _filter,
      allGroups: allGroups,
      locMap: locMap,
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showAddButton  = ref.watch(showAddGroupButtonProvider);
    final groupsAsync    = ref.watch(organizationsProvider);
    final locationsAsync = ref.watch(locationsProvider);

    final locMap    = buildLocMap(locationsAsync.asData?.value ?? []);
    final allGroups = groupsAsync.asData?.value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(allGroups: allGroups, locMap: locMap),
                Expanded(child: _buildGroupsList(groupsAsync, locMap)),
              ],
            ),
            if (showAddButton)
              Positioned(
                bottom: 24, left: 0, right: 0,
                child: Center(child: _buildAddGroupButton()),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader({
    required List<Map<String, dynamic>> allGroups,
    required Map<String, Map<String, dynamic>> locMap,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + filter button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Groups',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D0D0D),
                          letterSpacing: -0.5)),
                  if (_filter.prefecture != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(
                            [_filter.prefecture, if (_filter.city != null) _filter.city]
                                .whereType<String>()
                                .join(', '),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              GestureDetector(
                onTap: () => _openFilter(allGroups: allGroups, locMap: locMap),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: _hasActiveFilter
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.tune_rounded,
                          color: _hasActiveFilter ? Colors.white : AppColors.primary,
                          size: 20),
                    ),
                    if (_hasActiveFilter)
                      Positioned(
                        top: -3, right: -3,
                        child: Container(
                          width: 10, height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
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
              style: const TextStyle(fontSize: 15, color: Color(0xFF0D0D0D)),
              decoration: InputDecoration(
                hintText: 'Search local groups...',
                hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.35),
                    fontSize: 15,
                    fontWeight: FontWeight.w400),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.black.withOpacity(0.35), size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                    onTap: () =>
                        setState(() => _searchController.clear()),
                    child: Icon(Icons.close_rounded,
                        color: Colors.black.withOpacity(0.35), size: 20))
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Active filter chips
          if (_filter.orgType != null ||
              _filter.skillLevel != null ||
              _filter.meetingTime != null) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [..._activeChips(), const SizedBox(width: 4)],
              ),
            ),
            const SizedBox(height: 10),
          ],

          Container(height: 1, color: const Color(0xFFEEEFF1)),
        ],
      ),
    );
  }

  List<Widget> _activeChips() {
    final chips = <Widget>[];

    void add(String label, VoidCallback remove) {
      chips.add(Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: remove,
              child: Icon(Icons.close_rounded,
                  size: 13, color: AppColors.primary),
            ),
          ],
        ),
      ));
    }

    if (_filter.orgType != null) {
      add(_filter.orgType!,
              () => setState(() => _filter = _filter.copyWith(orgType: null)));
    }
    if (_filter.skillLevel != null) {
      add(_filter.skillLevel!,
              () => setState(() => _filter = _filter.copyWith(skillLevel: null)));
    }
    if (_filter.meetingTime != null) {
      add(_filter.meetingTime!,
              () => setState(() => _filter = _filter.copyWith(meetingTime: null)));
    }
    return chips;
  }

  // ── Groups list ────────────────────────────────────────────────────────────
  Widget _buildGroupsList(
      AsyncValue<List<Map<String, dynamic>>> groupsAsync,
      Map<String, Map<String, dynamic>> locMap,
      ) {
    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return _empty(Icons.group_off_rounded, 'No groups found.');
        }

        final query = _searchController.text.toLowerCase().trim();
        var filtered = query.isEmpty
            ? groups
            : groups
            .where((g) => (g['org_name'] ?? '')
            .toString()
            .toLowerCase()
            .contains(query))
            .toList();

        filtered = filtered.where((g) => _filter.matches(g, locMap)).toList();

        if (filtered.isEmpty) {
          return _empty(
            Icons.search_off_rounded,
            query.isNotEmpty
                ? 'No groups match "$query".'
                : 'No groups match the selected filters.',
            sub: 'Try adjusting your filters.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          itemCount: filtered.length,
          itemBuilder: (context, i) => GroupCardList(group: filtered[i]),
        );
      },
      loading: () => Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Something went wrong.\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String msg, {String? sub}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Colors.black.withOpacity(0.1)),
          const SizedBox(height: 14),
          Text(msg,
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withOpacity(0.35),
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub,
                style: TextStyle(
                    fontSize: 13, color: Colors.black.withOpacity(0.25))),
          ],
        ],
      ),
    );
  }

  // ── Add group button ────────────────────────────────────────────────────────
  Widget _buildAddGroupButton() {
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
              Text('Add a Group',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2)),
            ],
          ),
        ),
        Positioned(
          top: -8, right: -8,
          child: GestureDetector(
            onTap: () =>
            ref.read(showAddGroupButtonProvider.notifier).state = false,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0D0D0D), width: 1.5),
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