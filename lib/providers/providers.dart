import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── UI State Providers ───────────────────────────────────────────────
final showAddEventButtonProvider = StateProvider<bool>((ref) => true);
final showAddGroupButtonProvider = StateProvider<bool>((ref) => true);
final showAddCourtButtonProvider = StateProvider<bool>((ref) => true);

// ── Events Provider (list screen — limited) ──────────────────────────
final eventsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('events')
      .orderBy('event_start_date')
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
});

// ── Calendar Events Provider (upcoming only, no limit) ───────────────
// Used by CalendarEventsScreen — fetches all future events so every
// date with an event can be marked on the calendar.
final calendarEventsProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  final todayStart = Timestamp.fromDate(DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  ));
  return FirebaseFirestore.instance
      .collection('events')
      .where('event_start_date', isGreaterThanOrEqualTo: todayStart)
      .orderBy('event_start_date')
      .snapshots()
      .map((s) => s.docs.map((d) {
    final data = d.data();
    data['_doc_id'] = d.id;
    return data;
  }).toList());
});

// ── Organizations Provider ───────────────────────────────────────────
final organizationsProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('organizations')
      .orderBy('org_created_at')
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
});

// ── Locations (Courts) Provider ──────────────────────────────────────
final locationsProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('locations')
      .orderBy('loc_created_at')
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
});

// ── Location Resolver Provider ───────────────────────────────────────
final locationResolverProvider =
FutureProvider.family<String, String>((ref, locId) async {
  if (locId.isEmpty) return 'Unknown location';
  try {
    final q = await FirebaseFirestore.instance
        .collection('locations')
        .where('loc_org_id', isEqualTo: locId)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      final d = q.docs.first.data();
      final city = (d['loc_city'] ?? '').toString();
      final country = (d['loc_country'] ?? '').toString();
      if (city.isNotEmpty) {
        return country.isNotEmpty ? '$city, $country' : city;
      }
      final name = (d['loc_name'] ?? '').toString();
      return name.isNotEmpty ? name : 'Unknown location';
    }
    return 'Unknown location';
  } catch (_) {
    return 'Unknown location';
  }
});