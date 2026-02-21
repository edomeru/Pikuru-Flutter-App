import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/widgets/group_card_list.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => false; // Don't keep state when switching tabs

  @override
  void initState() {
    super.initState();
    // Reset button visibility when screen is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(showAddGroupButtonProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final showAddButton = ref.watch(showAddGroupButtonProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main content ─────────────────────────────────────
            Column(
              children: [
                const SizedBox(height: 16),

                // ── Search Bar ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search local groups',
                              hintStyle: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: AppColors.primary,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ── Filter Icon ──────────────────────────────
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Groups List ──────────────────────────────────
                Expanded(
                  child: _buildGroupsList(),
                ),
              ],
            ),

            // ── Floating Add Group Button ───────────────────────
            if (showAddButton)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildAddGroupButton(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Groups List Builder ─────────────────────────────────────────────
  Widget _buildGroupsList() {
    final groupsAsync = ref.watch(organizationsProvider);

    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return const Center(
            child: Text(
              'No groups found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return GroupCardList(group: group);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error'),
      ),
    );
  }

  // ── Floating Add Group Button ───────────────────────────────────────
  Widget _buildAddGroupButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main button
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Add a Group',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Close button
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: () {
              // Hide the Add Group button
              ref.read(showAddGroupButtonProvider.notifier).state = false;
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}