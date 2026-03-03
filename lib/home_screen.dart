import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/widgets/event_card.dart';
import 'package:pikuru/widgets/group_card.dart';
import 'package:pikuru/widgets/court_card.dart';
import 'package:pikuru/utils/date_formatter.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/screens/chats_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            onPressed: () => Navigator.push(          // ← changed from SnackBar
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

              // ── UPCOMING EVENTS ─────────────────────────────────
              _sectionHeader('Upcoming events'),
              const SizedBox(height: 16),
              SizedBox(
                height: 265,
                child: _buildEventsSection(ref),
              ),

              const SizedBox(height: 30),
              _divider(),
              const SizedBox(height: 20),

              // ── LOCAL GROUPS ────────────────────────────────────
              _sectionHeader('Local groups'),
              const SizedBox(height: 16),
              SizedBox(
                height: 235,
                child: _buildGroupsSection(ref),
              ),

              const SizedBox(height: 30),
              _divider(),
              const SizedBox(height: 20),

              // ── PICKLEBALL COURTS ───────────────────────────────
              _sectionHeader('Pickleball courts'),
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: _buildCourtsSection(ref),
              ),

              const SizedBox(height: 30),

              // ── WELCOME ─────────────────────────────────────────
              const Text(
                'Welcome to Pikuru!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find pickleball courts and events near you 🎾',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _actionButton('What is Pickleball?'),
                  const SizedBox(height: 12),
                  _actionButton('About Pikuru'),
                  const SizedBox(height: 30),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Events Section ──────────────────────────────────────────────────
  Widget _buildEventsSection(WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const Center(child: Text('No events yet'));
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: events.length,
          itemBuilder: (context, index) {
            final data = events[index];
            final Timestamp startDate = data['event_start_date'];
            final Timestamp startTime = data['event_start_time'];
            final formattedDateTime = DateFormatter.formatDateTime(
              startDate.toDate(),
              startTime.toDate(),
            );
            final eventLocId = (data['event_loc_id'] ?? '').toString();

            return Consumer(
              builder: (context, ref, child) {
                final locationAsync = ref.watch(
                  locationResolverProvider(eventLocId),
                );
                return locationAsync.when(
                  data: (location) => EventCard(
                    imageUrl: (data['event_image'] ?? '').toString(),
                    title: (data['event_title'] ?? 'Untitled').toString(),
                    dateTime: formattedDateTime,
                    location: location,
                  ),
                  loading: () => EventCard(
                    imageUrl: (data['event_image'] ?? '').toString(),
                    title: (data['event_title'] ?? 'Untitled').toString(),
                    dateTime: formattedDateTime,
                    location: '...',
                  ),
                  error: (_, __) => EventCard(
                    imageUrl: (data['event_image'] ?? '').toString(),
                    title: (data['event_title'] ?? 'Untitled').toString(),
                    dateTime: formattedDateTime,
                    location: 'Unknown location',
                  ),
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

  // ── Groups Section ──────────────────────────────────────────────────
  Widget _buildGroupsSection(WidgetRef ref) {
    final orgsAsync = ref.watch(organizationsProvider);

    return orgsAsync.when(
      data: (orgs) {
        if (orgs.isEmpty) {
          return const Center(child: Text('No groups yet'));
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: orgs.length,
          itemBuilder: (context, index) {
            final data = orgs[index];
            final orgLocId = (data['org_loc_id'] ?? '').toString();

            return Consumer(
              builder: (context, ref, child) {
                final locationAsync = ref.watch(
                  locationResolverProvider(orgLocId),
                );
                return locationAsync.when(
                  data: (location) => GroupCard(
                    imageUrl: (data['org_image'] ?? '').toString(),
                    name: (data['org_name'] ?? 'Unnamed Group').toString(),
                    location: location,
                  ),
                  loading: () => GroupCard(
                    imageUrl: (data['org_image'] ?? '').toString(),
                    name: (data['org_name'] ?? 'Unnamed Group').toString(),
                    location: '...',
                  ),
                  error: (_, __) => GroupCard(
                    imageUrl: (data['org_image'] ?? '').toString(),
                    name: (data['org_name'] ?? 'Unnamed Group').toString(),
                    location: 'Unknown location',
                  ),
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

  // ── Courts Section ──────────────────────────────────────────────────
  Widget _buildCourtsSection(WidgetRef ref) {
    final courtsAsync = ref.watch(locationsProvider);

    return courtsAsync.when(
      data: (courts) {
        if (courts.isEmpty) {
          return const Center(child: Text('No courts yet'));
        }
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

  // ── UI Helpers ──────────────────────────────────────────────────────
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

  Widget _actionButton(String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {},
      child: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }
}