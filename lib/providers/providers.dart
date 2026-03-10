import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── UI State Providers ────────────────────────────────────────────────────────
final showAddEventButtonProvider = StateProvider<bool>((ref) => true);
final showAddGroupButtonProvider = StateProvider<bool>((ref) => true);
final showAddCourtButtonProvider = StateProvider<bool>((ref) => true);

// ── Events Provider ───────────────────────────────────────────────────────────
final eventsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thirtyDaysLater = today.add(const Duration(days: 30));

  return FirebaseFirestore.instance
      .collection('events')
      .where('event_active', isEqualTo: true)
      .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
      .where('event_date', isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysLater))
      .orderBy('event_date')
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) {
    final data = d.data();
    data['_doc_id'] = d.id;
    return data;
  }).toList());
});

// ── Calendar Events Provider ──────────────────────────────────────────────────
final calendarEventsProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return FirebaseFirestore.instance
      .collection('events')
      .where('event_active', isEqualTo: true)
      .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
      .orderBy('event_date')
      .snapshots()
      .map((s) => s.docs.map((d) {
    final data = d.data();
    data['_doc_id'] = d.id;
    return data;
  }).toList());
});

// ── Organizations Provider ────────────────────────────────────────────────────
final organizationsProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('organizations')
      .orderBy('org_created_at')
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map((d) {
    final data = d.data();
    data['_doc_id'] = d.id;
    return data;
  }).toList());
});

// ── Locations (Courts) Provider ───────────────────────────────────────────────
// Fetches ALL location docs then filters active client-side.
// Handles both boolean true and string "true" for loc_active.
final locationsProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('locations')
      .snapshots()
      .map((s) {
    final all = s.docs.map((d) {
      final data = d.data();
      data['_doc_id'] = d.id;
      return data;
    }).toList();

    // Debug log — check Flutter console to diagnose missing pins
    debugPrint('[locationsProvider] Total docs: ${all.length}');
    for (final d in all) {
      debugPrint('  ${d["_doc_id"]}: active=${d["loc_active"]} (${d["loc_active"]?.runtimeType}), lat=${d["loc_latitude"]}, lng=${d["loc_longitude"]}');
    }

    // Accept boolean true OR string "true"
    final active = all.where((d) {
      final v = d['loc_active'];
      return v == true || v?.toString().toLowerCase() == 'true';
    }).toList();

    debugPrint('[locationsProvider] Active after filter: ${active.length}');
    return active;
  });
});


// ── Location Resolver Provider ────────────────────────────────────────────────
final locationResolverProvider =
FutureProvider.family<String, String>((ref, locId) async {
  if (locId.isEmpty) return 'Unknown location';

  String _display(Map<String, dynamic> d) {
    final city       = (d['loc_city'] ?? '').toString();
    final prefecture = (d['loc_prefecture'] ?? '').toString();
    final country    = (d['loc_country'] ?? '').toString();
    final name       = (d['loc_name'] ?? '').toString();

    if (city.isNotEmpty && prefecture.isNotEmpty) return '\$city, \$prefecture';
    if (city.isNotEmpty && country.isNotEmpty)    return '\$city, \$country';
    if (city.isNotEmpty)                          return city;
    if (name.isNotEmpty)                          return name;
    return 'Unknown location';
  }

  try {
    final q1 = await FirebaseFirestore.instance
        .collection('locations')
        .where('loc_id', isEqualTo: locId)
        .limit(1)
        .get();
    if (q1.docs.isNotEmpty) return _display(q1.docs.first.data());

    final q2 = await FirebaseFirestore.instance
        .collection('locations')
        .where('loc_ID', isEqualTo: locId)
        .limit(1)
        .get();
    if (q2.docs.isNotEmpty) return _display(q2.docs.first.data());

    final doc = await FirebaseFirestore.instance
        .collection('locations')
        .doc(locId)
        .get();
    if (doc.exists) return _display(doc.data()!);

    final all = await FirebaseFirestore.instance
        .collection('locations')
        .get();
    for (final d in all.docs) {
      final data = d.data();
      if (d.id == locId ||
          data['loc_id']?.toString() == locId ||
          data['loc_ID']?.toString() == locId) {
        return _display(data);
      }
    }
  } catch (_) {}

  return 'Unknown location';
});

// ── Organizer Resolver Provider ───────────────────────────────────────────────
final organizerResolverProvider =
FutureProvider.family<String, String>((ref, orgId) async {
  if (orgId.isEmpty) return '';

  String _display(Map<String, dynamic> d) {
    return (d['org_name'] ?? '').toString().trim();
  }

  try {
    final q1 = await FirebaseFirestore.instance
        .collection('organizations')
        .where('org_id', isEqualTo: orgId)
        .limit(1)
        .get();
    if (q1.docs.isNotEmpty) return _display(q1.docs.first.data());

    final q2 = await FirebaseFirestore.instance
        .collection('organizations')
        .where('org_ID', isEqualTo: orgId)
        .limit(1)
        .get();
    if (q2.docs.isNotEmpty) return _display(q2.docs.first.data());

    final doc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .get();
    if (doc.exists) return _display(doc.data()!);

    final all = await FirebaseFirestore.instance
        .collection('organizations')
        .get();
    for (final d in all.docs) {
      final data = d.data();
      if (d.id == orgId ||
          data['org_id']?.toString() == orgId ||
          data['org_ID']?.toString() == orgId) {
        return _display(data);
      }
    }
  } catch (_) {}

  return '';
});