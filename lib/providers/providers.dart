import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── UI State Providers ────────────────────────────────────────────────────────
final showAddEventButtonProvider = StateProvider<bool>((ref) => true);
final showAddGroupButtonProvider = StateProvider<bool>((ref) => true);
final showAddCourtButtonProvider = StateProvider<bool>((ref) => true);

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Future<Map<String, dynamic>> _attachEventCapacityMeta(
    String eventId,
    Map<String, dynamic> data,
    ) async {
  final limit = _asInt(data['event_limit']);
  int approvedCount = 0;
  int waitlistCount = 0;

  try {
    final approvedSnap = await FirebaseFirestore.instance
        .collection('event_registrations')
        .where('event_id', isEqualTo: eventId)
        .where('status', isEqualTo: 'approved')
        .count()
        .get();
    approvedCount = approvedSnap.count ?? 0;
  } catch (e) {
    debugPrint('[eventCapacity] approved count failed for $eventId: $e');
  }

  try {
    final waitlistSnap = await FirebaseFirestore.instance
        .collection('event_registrations')
        .where('event_id', isEqualTo: eventId)
        .where('status', whereIn: ['waitlisted', 'waiting_list'])
        .count()
        .get();
    waitlistCount = waitlistSnap.count ?? 0;
  } catch (e) {
    debugPrint('[eventCapacity] waitlist count failed for $eventId: $e');
  }

  final hasLimit = limit > 0;
  final remaining = hasLimit ? (limit - approvedCount).clamp(0, limit) : 0;
  final isFull = hasLimit && approvedCount >= limit;
  final pct = hasLimit ? (approvedCount / limit).clamp(0.0, 1.0) : 0.0;

  return {
    ...data,
    '_capacity_limit': limit,
    '_capacity_has_limit': hasLimit,
    '_capacity_approved_count': approvedCount,
    '_capacity_waitlist_count': waitlistCount,
    '_capacity_remaining': remaining,
    '_capacity_percent': pct,
    '_capacity_is_full': isFull,
    '_capacity_cta_label': isFull ? 'Join Waiting List' : 'Register',
    '_capacity_label': hasLimit
        ? '$approvedCount / $limit spots filled'
        : 'No capacity limit',
    '_waitlist_enabled': isFull,
    'capacity_limit': limit,
    'capacity_registered_count': approvedCount,
    'waiting_list_count': waitlistCount,
  };
}

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
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thirtyDaysLater = today.add(const Duration(days: 30));

  return FirebaseFirestore.instance
      .collection('events')
      .where('event_active', isEqualTo: true)
      .where('event_status', isEqualTo: true)
      .where('event_pending_review', isEqualTo: false)
      .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
      .where(
    'event_date',
    isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysLater),
  )
      .orderBy('event_date')
      .limit(50)
      .snapshots()
      .asyncMap((s) async {
    return Future.wait(
      s.docs.map((d) {
        final data = d.data();
        data['_doc_id'] = d.id;
        return _attachEventCapacityMeta(d.id, data);
      }),
    );
  });
});

// ── Calendar Events Provider ──────────────────────────────────────────────────
// Fetch window: event_date >= today AND event_date <= today + 30 days.
//
// The 30-day limit applies only to the FETCH (i.e. an event must *start*
// within the next 30 days to be included). Once fetched, _buildEventMap in
// calendar_events_screen.dart spans each event from its start date all the
// way to its event_date_end with no upper cutoff, so a multi-day event that
// begins inside the window but ends beyond it will still render correctly on
// the calendar for its full duration — exactly matching the web app's logic.
//
// Required Firestore composite index:
//   Collection : events
//   Fields     : event_active ASC, event_status ASC,
//                event_pending_review ASC, event_date ASC
final calendarEventsProvider = StreamProvider<List<Map<String, dynamic>>>((
    ref,
    ) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thirtyDaysLater = today.add(
    const Duration(days: 30),
  ); // ← added upper bound

  return FirebaseFirestore.instance
      .collection('events')
      .where('event_active', isEqualTo: true)
      .where('event_status', isEqualTo: true)
      .where('event_pending_review', isEqualTo: false)
      .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
      .where(
    'event_date',
    isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysLater),
  ) // ← added
      .orderBy('event_date')
      .snapshots()
      .asyncMap((s) async {
    return Future.wait(
      s.docs.map((d) {
        final data = d.data();
        data['_doc_id'] = d.id;
        return _attachEventCapacityMeta(d.id, data);
      }),
    );
  });
});

// ── Organizations Provider ────────────────────────────────────────────────────
final organizationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('organizations')
      .where('org_active', isEqualTo: true)
      .orderBy('org_created_at')
      .snapshots()
      .map(
        (s) => s.docs.map((d) {
      final data = d.data();
      data['_doc_id'] = d.id;
      return data;
    }).toList(),
  );
});

// ── Locations (Courts) Provider ───────────────────────────────────────────────
// Mirrors the web app's CourtsPage load() query exactly:
//   • loc_checked        == true   ← only fully approved courts
//   • loc_active         == true   ← only active courts
//   • loc_pending_review == false  ← exclude courts awaiting re-review
//
// This means when the admin clicks "Set to pending" on an approved court,
// Firestore sets { loc_pending_review: true, loc_checked: false }, and this
// stream will immediately drop that court — keeping Flutter in sync with web.
//
// Required Firestore composite index:
//   Collection : locations
//   Fields     : loc_checked ASC, loc_active ASC, loc_pending_review ASC
final locationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('locations')
      .where('loc_checked', isEqualTo: true)
      .where('loc_active', isEqualTo: true)
      .where('loc_pending_review', isEqualTo: false)
      .snapshots()
      .map((s) {
    final docs = s.docs.map((d) {
      final data = d.data();
      data['_doc_id'] = d.id;
      return data;
    }).toList();

    debugPrint('[locationsProvider] Total docs fetched: ${docs.length}');

    return docs;
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
final locationResolverProvider = FutureProvider.family<String, String>((
    ref,
    locId,
    ) async {
  if (locId.isEmpty) return '';

  String display(Map<String, dynamic> d) {
    final city =
    ((d['loc_city_en'] ?? '').toString().trim().isNotEmpty
        ? d['loc_city_en']
        : d['loc_city'] ?? '')
        .toString()
        .trim();

    final prefecture =
    ((d['loc_prefecture_en'] ?? '').toString().trim().isNotEmpty
        ? d['loc_prefecture_en']
        : d['loc_prefecture'] ?? '')
        .toString()
        .trim();

    final country = (d['loc_country'] ?? '').toString().trim();

    if (city.isNotEmpty && prefecture.isNotEmpty) return '$city, $prefecture';
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (city.isNotEmpty) return city;
    if (prefecture.isNotEmpty && country.isNotEmpty)
      return '$prefecture, $country';
    if (prefecture.isNotEmpty) return prefecture;
    if (country.isNotEmpty) return country;
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
    final all = await FirebaseFirestore.instance.collection('locations').get();
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
final organizerResolverProvider = FutureProvider.family<String, String>((
    ref,
    orgId,
    ) async {
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

// ── Focused Court Provider ────────────────────────────────────────────────────
// When set to a Firestore document id, the CourtsScreen will pan/zoom to that
// court's marker and open its detail sheet, then reset this back to null.
final focusedCourtIdProvider = StateProvider<String?>((ref) => null);

// ── Reset Courts Filter Provider ──────────────────────────────────────────────
// When incremented, CourtsScreen resets its filter to CourtFilter.defaultFilter
// (prefecture: 'Tokyo'). Triggered by the Home screen's "See all" courts button.
final resetCourtsFilterProvider = StateProvider<int>((ref) => 0);
