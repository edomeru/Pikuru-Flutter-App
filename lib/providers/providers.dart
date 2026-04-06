import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── UI State Providers ────────────────────────────────────────────────────────
final showAddEventButtonProvider = StateProvider<bool>((ref) => true);
final showAddGroupButtonProvider = StateProvider<bool>((ref) => true);
final showAddCourtButtonProvider = StateProvider<bool>((ref) => true);

// ── Events Provider ───────────────────────────────────────────────────────────
// Mirrors the web app's EventsContent load() defaults exactly:
//   • event_active         == true
//   • event_status         == true
//   • event_pending_review == false   ← only show approved events
//   • event_date           >= today (midnight)
//   • event_date           <= today + 30 days
//   • orderBy event_date ASC
//   • limit 50
//
// Required Firestore composite index:
//   Collection : events
//   Fields     : event_active ASC, event_status ASC,
//                event_pending_review ASC, event_date ASC
final eventsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final now             = DateTime.now();
  final today           = DateTime(now.year, now.month, now.day);
  final thirtyDaysLater = today.add(const Duration(days: 30));

  return FirebaseFirestore.instance
      .collection('events')
      .where('event_active',         isEqualTo: true)
      .where('event_status',         isEqualTo: true)   // ← added
      .where('event_pending_review', isEqualTo: false)  // ← added
      .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
      .where('event_date', isLessThanOrEqualTo:    Timestamp.fromDate(thirtyDaysLater))
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
// Also filters out pending/inactive events so the calendar view stays clean.
final calendarEventsProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return FirebaseFirestore.instance
      .collection('events')
      .where('event_active',         isEqualTo: true)
      .where('event_status',         isEqualTo: true)   // ← added
      .where('event_pending_review', isEqualTo: false)  // ← added
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
      .where('org_active', isEqualTo: true)
      .orderBy('org_created_at')
      .snapshots()
      .map((s) => s.docs.map((d) {
    final data = d.data();
    data['_doc_id'] = d.id;
    return data;
  }).toList());
});

// ── Locations (Courts) Provider ───────────────────────────────────────────────
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

    debugPrint('[locationsProvider] Total docs: ${all.length}');
    for (final d in all) {
      debugPrint(
          '  ${d["_doc_id"]}: active=${d["loc_active"]} (${d["loc_active"]?.runtimeType}), '
              'lat=${d["loc_latitude"]}, lng=${d["loc_longitude"]}');
    }

    final active = all.where((d) {
      final v = d['loc_active'];
      return v == true || v?.toString().toLowerCase() == 'true';
    }).toList();

    debugPrint('[locationsProvider] Active after filter: ${active.length}');
    return active;
  });
});

// ── Location Resolver Provider ────────────────────────────────────────────────
// Resolves a loc_id → "City, Prefecture" display label (English).
//
// Field priority (English first, then legacy fallbacks):
//   city       : loc_city_en  → loc_city
//   prefecture : loc_prefecture_en → loc_prefecture
//   country    : loc_country
//   last resort: loc_name (the venue name — only shown if nothing else works)
//
// Returns '' on failure so callers can show org_country as a fallback.
final locationResolverProvider =
FutureProvider.family<String, String>((ref, locId) async {
  if (locId.isEmpty) return '';

  String display(Map<String, dynamic> d) {
    // City: prefer the dedicated English field
    final city = ((d['loc_city_en'] ?? '').toString().trim().isNotEmpty
        ? d['loc_city_en']
        : d['loc_city'] ?? '')
        .toString()
        .trim();

    // Prefecture: prefer the dedicated English field
    final prefecture =
    ((d['loc_prefecture_en'] ?? '').toString().trim().isNotEmpty
        ? d['loc_prefecture_en']
        : d['loc_prefecture'] ?? '')
        .toString()
        .trim();

    final country = (d['loc_country'] ?? '').toString().trim();

    // Build label — never fall back to loc_name so venue names don't show
    if (city.isNotEmpty && prefecture.isNotEmpty) return '$city, $prefecture';
    if (city.isNotEmpty && country.isNotEmpty)    return '$city, $country';
    if (city.isNotEmpty)                          return city;
    if (prefecture.isNotEmpty && country.isNotEmpty) return '$prefecture, $country';
    if (prefecture.isNotEmpty)                    return prefecture;
    if (country.isNotEmpty)                       return country;
    return '';
  }

  try {
    // 1️⃣ Query by loc_id field (lowercase)
    final q1 = await FirebaseFirestore.instance
        .collection('locations')
        .where('loc_id', isEqualTo: locId)
        .limit(1)
        .get();
    if (q1.docs.isNotEmpty) {
      final label = display(q1.docs.first.data());
      if (label.isNotEmpty) return label;
    }

    // 2️⃣ Try Firestore document ID
    final doc = await FirebaseFirestore.instance
        .collection('locations')
        .doc(locId)
        .get();
    if (doc.exists) {
      final label = display(doc.data()!);
      if (label.isNotEmpty) return label;
    }

    // 3️⃣ Full-scan fallback
    final all =
    await FirebaseFirestore.instance.collection('locations').get();
    for (final d in all.docs) {
      final data = d.data();
      if (d.id == locId || data['loc_id']?.toString() == locId) {
        final label = display(data);
        if (label.isNotEmpty) return label;
      }
    }
  } catch (e) {
    debugPrint('[locationResolverProvider] Error for locId=$locId: $e');
  }

  return '';
});

// ── Organizer Resolver Provider ───────────────────────────────────────────────
final organizerResolverProvider =
FutureProvider.family<String, String>((ref, orgId) async {
  if (orgId.isEmpty) return '';

  String display(Map<String, dynamic> d) =>
      (d['org_name'] ?? '').toString().trim();

  try {
    final q1 = await FirebaseFirestore.instance
        .collection('organizations')
        .where('org_id', isEqualTo: orgId)
        .limit(1)
        .get();
    if (q1.docs.isNotEmpty) return display(q1.docs.first.data());

    final doc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .get();
    if (doc.exists) return display(doc.data()!);

    final all = await FirebaseFirestore.instance
        .collection('organizations')
        .get();
    for (final d in all.docs) {
      final data = d.data();
      if (d.id == orgId || data['org_id']?.toString() == orgId) {
        return display(data);
      }
    }
  } catch (_) {}

  return '';
});