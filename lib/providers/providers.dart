import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── UI State Providers ───────────────────────────────────────────────
// Controls visibility of "Add Event" button in Events screen
final showAddEventButtonProvider = StateProvider<bool>((ref) => true);

// Controls visibility of "Add Group" button in Groups screen
final showAddGroupButtonProvider = StateProvider<bool>((ref) => true);

// Controls visibility of "Add Court" button in Courts screen
final showAddCourtButtonProvider = StateProvider<bool>((ref) => true);

// ── Events Provider ──────────────────────────────────────────────────
final eventsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('events')
      .orderBy('event_start_date')
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

// ── Organizations Provider ───────────────────────────────────────────
final organizationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('organizations')
      .orderBy('org_created_at')
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

// ── Locations (Courts) Provider ──────────────────────────────────────
final locationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('locations')
      .orderBy('loc_created_at')
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

// ── Location Resolver Provider ───────────────────────────────────────
// Resolves a location ID to city + country
final locationResolverProvider = FutureProvider.family<String, String>((ref, locId) async {
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