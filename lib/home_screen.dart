import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/widgets/event_card.dart';
import 'package:pikuru/widgets/group_card.dart';
import 'package:pikuru/widgets/court_card.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/screens/chats_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _formatEventDateTime(Map<String, dynamic> data) {
    final rawDate = data['event_date'];
    final rawTime = data['event_time'];

    String dateStr = '';
    if (rawDate is Timestamp) {
      dateStr = DateFormat('EEE, MMM d').format(rawDate.toDate());
    }

    String timeStr = '';
    if (rawTime is Timestamp) {
      timeStr = DateFormat('h:mm a').format(rawTime.toDate());
    } else if (rawTime is String && rawTime.isNotEmpty) {
      timeStr = rawTime;
    }

    if (dateStr.isNotEmpty && timeStr.isNotEmpty) return '$dateStr · $timeStr';
    if (dateStr.isNotEmpty) return dateStr;
    return 'Date TBD';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: SizedBox(
          height: 132,
          child: Image.asset('assets/pikuru_logo.png', fit: BoxFit.contain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline,
                color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // ── UPCOMING EVENTS ────────────────────────────────────────
              _sectionHeader('Upcoming events'),
              const SizedBox(height: 16),
              SizedBox(height: 265, child: _buildEventsSection(ref)),

              const SizedBox(height: 30),
              _divider(),
              const SizedBox(height: 20),

              // ── LOCAL GROUPS ───────────────────────────────────────────
              _sectionHeader('Local groups'),
              const SizedBox(height: 16),
              SizedBox(height: 235, child: _buildGroupsSection(ref)),

              const SizedBox(height: 30),
              _divider(),
              const SizedBox(height: 20),

              // ── PICKLEBALL COURTS ──────────────────────────────────────
              _sectionHeader('Pickleball courts'),
              const SizedBox(height: 16),
              SizedBox(height: 240, child: _buildCourtsSection(ref)),

              const SizedBox(height: 30),

              // ── WELCOME CARD ───────────────────────────────────────────
              _buildWelcomeCard(),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modern Welcome Card ───────────────────────────────────────────────────
  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, const Color(0xFF0D3D26), 0.55)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Decorative circles ─────────────────────────────────────────
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: 20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pill badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    '🎾  Japan\'s #1 Pickleball App',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Headline
                const Text(
                  'Welcome to\nPikuru!',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -1.0,
                  ),
                ),

                const SizedBox(height: 10),

                // Subtitle
                Text(
                  'Find courts, join events, and connect\nwith players across Japan.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.white.withOpacity(0.75),
                    height: 1.55,
                    letterSpacing: 0.1,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Quick action strips ──────────────────────────────
                _quickActionStrip(
                  icon: Icons.location_on_rounded,
                  label: 'Find courts near you',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _quickActionStrip(
                  icon: Icons.event_rounded,
                  label: 'Browse upcoming events',
                  onTap: () {},
                ),

                const SizedBox(height: 20),

                // Buttons row
                Row(
                  children: [
                    Expanded(
                      child: _cardButton(
                        label: 'What is Pickleball?',
                        isPrimary: true,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _cardButton(
                        label: 'About Pikuru',
                        isPrimary: false,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionStrip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.5),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardButton({
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.2,
          ),
          boxShadow: isPrimary
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isPrimary ? AppColors.primary : Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  // ── Events Section ─────────────────────────────────────────────────────────
  Widget _buildEventsSection(WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) return const Center(child: Text('No events yet'));
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: events.length,
          itemBuilder: (context, index) {
            final data = events[index];
            final imageUrl = (data['event_pic'] ??
                data['event_pic_thumbnail'] ??
                data['event_image'] ??
                '')
                .toString();
            final title = (data['event_title'] ?? 'Untitled').toString();
            final formattedDateTime = _formatEventDateTime(data);
            final eventLocId = (data['event_loc_id'] ?? '').toString();
            return Consumer(
              builder: (context, ref, child) {
                final locationAsync =
                ref.watch(locationResolverProvider(eventLocId));
                return locationAsync.when(
                  data: (location) => EventCard(
                      imageUrl: imageUrl,
                      title: title,
                      dateTime: formattedDateTime,
                      location: location),
                  loading: () => EventCard(
                      imageUrl: imageUrl,
                      title: title,
                      dateTime: formattedDateTime,
                      location: '...'),
                  error: (_, __) => EventCard(
                      imageUrl: imageUrl,
                      title: title,
                      dateTime: formattedDateTime,
                      location: 'Unknown location'),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // ── Groups Section ─────────────────────────────────────────────────────────
  Widget _buildGroupsSection(WidgetRef ref) {
    final orgsAsync = ref.watch(organizationsProvider);
    return orgsAsync.when(
      data: (orgs) {
        if (orgs.isEmpty) return const Center(child: Text('No groups yet'));
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: orgs.length,
          itemBuilder: (context, index) {
            final data = orgs[index];
            final orgLocId = (data['org_loc_id'] ?? '').toString();
            return Consumer(
              builder: (context, ref, child) {
                final locationAsync =
                ref.watch(locationResolverProvider(orgLocId));
                return locationAsync.when(
                  data: (location) => GroupCard(
                      imageUrl: (data['org_image'] ?? '').toString(),
                      name: (data['org_name'] ?? 'Unnamed Group').toString(),
                      location: location),
                  loading: () => GroupCard(
                      imageUrl: (data['org_image'] ?? '').toString(),
                      name: (data['org_name'] ?? 'Unnamed Group').toString(),
                      location: '...'),
                  error: (_, __) => GroupCard(
                      imageUrl: (data['org_image'] ?? '').toString(),
                      name: (data['org_name'] ?? 'Unnamed Group').toString(),
                      location: 'Unknown location'),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // ── Courts Section ─────────────────────────────────────────────────────────
  Widget _buildCourtsSection(WidgetRef ref) {
    final courtsAsync = ref.watch(locationsProvider);
    return courtsAsync.when(
      data: (courts) {
        if (courts.isEmpty) return const Center(child: Text('No courts yet'));
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: courts.length,
          itemBuilder: (context, index) {
            final data = courts[index];
            final city = (data['loc_city'] ?? '').toString();
            final country = (data['loc_country'] ?? '').toString();
            final location = city.isNotEmpty
                ? (country.isNotEmpty ? '$city, $country' : city)
                : 'Unknown location';
            return CourtCard(
              imageUrl: (data['loc_image'] ?? '').toString(),
              name: (data['loc_name'] ?? 'Unnamed Court').toString(),
              location: location,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // ── UI Helpers ─────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        const Text(
          'See all',
          style: TextStyle(
            fontSize: 18,
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
    height: 1,
    color: AppColors.primary.withOpacity(0.5),
  );
}