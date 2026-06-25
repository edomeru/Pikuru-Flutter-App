import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/screens/add_court_screen.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

// ── i18n ──────────────────────────────────────────────────────────────────────
class _T {
  final String courts;
  final String tokyo;
  final String search;
  final String filterTitle;
  final String courtSetting;
  final String all;
  final String indoor;
  final String outdoor;
  final String prefecture;
  final String allPrefectures;
  final String city;
  final String allCities;
  final String setupType;
  final String amenities;
  final String resetFilters;
  final String applyFilters;
  final String courtsFound;
  final String moreInfo;
  final String disclaimer;
  final String addCourt;
  final String loadingMap;
  final String setupPublic;
  final String setupPrivate;
  final String amenityOpenPlay;
  final String amenityReservation;
  final String amenityMembership;
  final String amenityLessons;
  final String amenityDedicated;
  final String amenityPaddleRentals;
  final String indoor2;
  final String outdoor2;
  final String visitWebsite;
  final String viewOnMaps;
  final String noCoords;
  final String active;
  final String free;
  final String writeReview;
  final String addPhotos;
  final String tellExperience;
  final String startReview;
  final String reviewMinChars;
  final String charsLeft;
  final String addPhotosOptional;
  final String uploadImages;
  final String postReview;
  final String noReviews;
  final String loadingReviews;
  final String photosSelected;
  final String clear;
  final String signInRequired;
  final String reviewMinError;
  final String photoSelectError;
  final String browseFiles;
  final String dragDropHint;
  final String uploading;
  final String upload;
  final String anonymous;

  const _T({
    required this.courts,
    required this.tokyo,
    required this.search,
    required this.filterTitle,
    required this.courtSetting,
    required this.all,
    required this.indoor,
    required this.outdoor,
    required this.prefecture,
    required this.allPrefectures,
    required this.city,
    required this.allCities,
    required this.setupType,
    required this.amenities,
    required this.resetFilters,
    required this.applyFilters,
    required this.courtsFound,
    required this.moreInfo,
    required this.disclaimer,
    required this.addCourt,
    required this.loadingMap,
    required this.setupPublic,
    required this.setupPrivate,
    required this.amenityOpenPlay,
    required this.amenityReservation,
    required this.amenityMembership,
    required this.amenityLessons,
    required this.amenityDedicated,
    required this.amenityPaddleRentals,
    required this.indoor2,
    required this.outdoor2,
    required this.visitWebsite,
    required this.viewOnMaps,
    required this.noCoords,
    required this.active,
    required this.free,
    required this.writeReview,
    required this.addPhotos,
    required this.tellExperience,
    required this.startReview,
    required this.reviewMinChars,
    required this.charsLeft,
    required this.addPhotosOptional,
    required this.uploadImages,
    required this.postReview,
    required this.noReviews,
    required this.loadingReviews,
    required this.photosSelected,
    required this.clear,
    required this.signInRequired,
    required this.reviewMinError,
    required this.photoSelectError,
    required this.browseFiles,
    required this.dragDropHint,
    required this.uploading,
    required this.upload,
    required this.anonymous,
  });

  static const en = _T(
    courts:               'Courts',
    tokyo:                'Tokyo',
    search:               'Search pickleball courts...',
    filterTitle:          'Filter Courts',
    courtSetting:         'Court Setting',
    all:                  'All',
    indoor:               'Indoor',
    outdoor:              'Outdoor',
    prefecture:           'Prefecture',
    allPrefectures:       'All prefectures',
    city:                 'City',
    allCities:            'All cities',
    setupType:            'Setup Type',
    amenities:            'Amenities',
    resetFilters:         'Reset Filters',
    applyFilters:         'Apply Filters',
    courtsFound:          'courts found',
    moreInfo:             'More Information',
    disclaimer:           'Court hours and amenities may change. Please confirm details directly with the facility or court operator.',
    addCourt:             'Add a Court',
    loadingMap:           'Loading map...',
    setupPublic:          'Public Access Courts',
    setupPrivate:         'Private / Coordinated Courts',
    amenityOpenPlay:      'Open Play',
    amenityReservation:   'Reservation',
    amenityMembership:    'Membership',
    amenityLessons:       'Lessons',
    amenityDedicated:     'Dedicated',
    amenityPaddleRentals: 'Paddle Rentals',
    indoor2:              'Indoor',
    outdoor2:             'Outdoor',
    visitWebsite:         'Visit Website',
    viewOnMaps:           'View on Google Maps',
    noCoords:             'No map location available for this court.',
    active:               '✓ Active',
    free:                 'Free',
    writeReview:          'Write a review',
    addPhotos:            'Add photos',
    tellExperience:       'Tell us about your experience',
    startReview:          'Start your review...',
    reviewMinChars:       'Reviews need to be at least 85 characters.',
    charsLeft:            'left',
    addPhotosOptional:    'Add photos (optional)',
    uploadImages:         'Upload images of the court to help others',
    postReview:           'Post Review',
    noReviews:            'No reviews yet. Be the first to share your experience!',
    loadingReviews:       'Loading reviews...',
    photosSelected:       'photos selected',
    clear:                'Clear',
    signInRequired:       'You must be signed in to post.',
    reviewMinError:       'Review must be at least 85 characters.',
    photoSelectError:     'Please select at least one photo.',
    browseFiles:          'Browse Files',
    dragDropHint:         'Tap to select photos/videos',
    uploading:            'Uploading...',
    upload:               'Upload',
    anonymous:            'Anonymous',
  );

  static const ja = _T(
    courts:               'コート',
    tokyo:                '東京',
    search:               'ピックルボールコートを検索...',
    filterTitle:          'コートを絞り込む',
    courtSetting:         'コート環境',
    all:                  'すべて',
    indoor:               '室内',
    outdoor:              '屋外',
    prefecture:           '都道府県',
    allPrefectures:       '全ての都道府県',
    city:                 '市区町村',
    allCities:            '全ての市区町村',
    setupType:            'セットアップタイプ',
    amenities:            'アメニティ',
    resetFilters:         'リセット',
    applyFilters:         'フィルターを適用',
    courtsFound:          '件のコートが見つかりました',
    moreInfo:             '詳細を見る',
    disclaimer:           'コートの営業時間や設備は変更される場合があります。詳細は施設またはコート運営者に直接ご確認ください。',
    addCourt:             'コート追加',
    loadingMap:           'マップを読み込み中...',
    setupPublic:          '一般開放コート',
    setupPrivate:         '事前調整・予約制コート',
    amenityOpenPlay:      'オープンプレイ',
    amenityReservation:   '予約制',
    amenityMembership:    '会員制',
    amenityLessons:       'レッスンあり',
    amenityDedicated:     '専用コート',
    amenityPaddleRentals: 'パドルレンタル',
    indoor2:              '室内',
    outdoor2:             '屋外',
    visitWebsite:         'ウェブサイトを見る',
    viewOnMaps:           'Googleマップで見る',
    noCoords:             'このコートの地図情報はありません。',
    active:               '✓ 利用可能',
    free:                 '無料',
    writeReview:          'レビューを書く',
    addPhotos:            '写真を追加',
    tellExperience:       'あなたの体験を教えてください',
    startReview:          'レビューを始めましょう...',
    reviewMinChars:       'レビューは85文字以上必要です。',
    charsLeft:            '文字残り',
    addPhotosOptional:    '写真を追加（任意）',
    uploadImages:         'コートの画像をアップロードして他の人を助けましょう',
    postReview:           'レビューを投稿',
    noReviews:            'まだレビューはありません。最初に体験を共有しましょう！',
    loadingReviews:       'レビューを読み込み中...',
    photosSelected:       '枚の写真を選択しました',
    clear:                'クリア',
    signInRequired:       '投稿するにはログインが必要です。',
    reviewMinError:       'レビューは85文字以上が必要です。',
    photoSelectError:     '少なくとも1枚の写真を選択してください。',
    browseFiles:          'ファイルを選択',
    dragDropHint:         'タップして写真・動画を選択',
    uploading:            'アップロード中...',
    upload:               'アップロード',
    anonymous:            '匿名',
  );

  static _T of(String lang) => lang == kLangJa ? ja : en;
}

// ── Filter State ───────────────────────────────────────────────────────────────
class CourtFilter {
  final String? prefecture;
  final String? city;
  final Set<String> setupTypes;
  final Set<String> amenities;
  final String setting;

  const CourtFilter({
    this.prefecture,
    this.city,
    this.setupTypes = const {},
    this.amenities = const {},
    this.setting = 'all',
  });

  CourtFilter copyWith({
    Object? prefecture = _sentinel,
    Object? city       = _sentinel,
    Set<String>? setupTypes,
    Set<String>? amenities,
    String? setting,
  }) {
    return CourtFilter(
      prefecture: prefecture == _sentinel ? this.prefecture : prefecture as String?,
      city:       city       == _sentinel ? this.city       : city       as String?,
      setupTypes: setupTypes ?? this.setupTypes,
      amenities:  amenities  ?? this.amenities,
      setting:    setting    ?? this.setting,
    );
  }

  static const String _country = 'Japan';

  static const CourtFilter defaultFilter = CourtFilter(
    prefecture: 'Tokyo',
    setting: 'all',
  );

  static String _prefValue(Map<String, dynamic> loc) {
    final en = (loc['loc_prefecture_en'] ?? '').toString().trim();
    if (en.isNotEmpty) return en;
    return (loc['loc_prefecture'] ?? '').toString().trim();
  }

  static String _cityValue(Map<String, dynamic> loc) {
    final en = (loc['loc_city_en'] ?? '').toString().trim();
    if (en.isNotEmpty) return en;
    return (loc['loc_city'] ?? '').toString().trim();
  }

  bool matchesLocation(Map<String, dynamic> loc) {
    if ((loc['loc_country'] ?? '').toString() != _country) return false;
    if (prefecture != null && _prefValue(loc) != prefecture) return false;
    return _matchesNonGeo(loc);
  }

  bool matchesNonGeo(Map<String, dynamic> loc) => _matchesNonGeo(loc);

  bool _matchesNonGeo(Map<String, dynamic> loc) {
    if (city != null && _cityValue(loc) != city) return false;
    if (setupTypes.isNotEmpty &&
        !setupTypes.contains((loc['loc_setup_type'] ?? '').toString())) return false;
    if (setting == 'indoor'  && loc['loc_court_type_indoor']  != true) return false;
    if (setting == 'outdoor' && loc['loc_court_type_outdoor'] != true) return false;
    for (final a in amenities) {
      final val = loc['loc_amenities_$a'];
      if (val != true && val?.toString() != 'T' && val?.toString() != 'Yes') {
        return false;
      }
    }
    return true;
  }
}

const _sentinel = Object();

bool _hasActiveFilter(CourtFilter f) =>
    (f.prefecture != null && f.prefecture != 'Tokyo') ||
        f.city != null ||
        f.setupTypes.isNotEmpty ||
        f.amenities.isNotEmpty ||
        f.setting != 'all';


// ─────────────────────────────────────────────────────────────────────────────
// CourtsScreen
// ─────────────────────────────────────────────────────────────────────────────
class CourtsScreen extends ConsumerStatefulWidget {
  const CourtsScreen({super.key});

  @override
  ConsumerState<CourtsScreen> createState() => _CourtsScreenState();
}

class _CourtsScreenState extends ConsumerState<CourtsScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _mapReady = false;

  // ── User location blue dot ────────────────────────────────────────────────
  Marker? _userLocationMarker;
  bool _locationInitDone = false;

  CourtFilter _filter = CourtFilter.defaultFilter;

  List<Map<String, dynamic>> _lastLocations = [];
  Timer? _searchDebounce;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.6762, 139.6503),
    zoom: 10,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(showAddCourtButtonProvider.notifier).state = true;
    });
    _initUserLocation();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── iOS-compatible location init ──────────────────────────────────────────
  Future<void> _initUserLocation() async {
    if (_locationInitDone) return;
    _locationInitDone = true;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[CourtsScreen] Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[CourtsScreen] Location permission denied: $permission');
        return;
      }

      Position? position;

      if (Platform.isIOS) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.reduced,
            timeLimit: const Duration(seconds: 10),
          ).timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Location timeout'),
          );
        } catch (_) {
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.best,
              timeLimit: const Duration(seconds: 15),
            );
          } catch (e) {
            debugPrint('[CourtsScreen] iOS location fallback failed: $e');
            return;
          }
        }
      } else {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      if (position == null) return;

      final icon = await _buildUserLocationMarker();
      if (!mounted) return;

      final marker = Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(position.latitude, position.longitude),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        zIndex: 9999,
        consumeTapEvents: false,
        infoWindow: InfoWindow.noText,
      );

      setState(() {
        _userLocationMarker = marker;
        _markers = {..._markers, marker};
      });

      debugPrint('[CourtsScreen] User location set: ${position.latitude}, ${position.longitude}');

      _applySearchAndFilter();
    } on TimeoutException catch (e) {
      debugPrint('[CourtsScreen] Location timed out: $e');
    } catch (e) {
      debugPrint('[CourtsScreen] Location error: $e');
    }
  }

  Future<BitmapDescriptor> _buildUserLocationMarker() async {
    const double logicalSize = 80.0;
    const double scale = 3.0;
    const double canvasSize = logicalSize * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final center = Offset(canvasSize / 2, canvasSize / 2);

    canvas.drawCircle(
      center,
      canvasSize / 2 * 0.95,
      Paint()..color = const Color(0x224285F4),
    );

    canvas.drawCircle(
      center,
      canvasSize / 2 * 0.70,
      Paint()..color = const Color(0x334285F4),
    );

    canvas.drawCircle(
      center,
      canvasSize / 2 * 0.52,
      Paint()..color = const Color(0x444285F4),
    );

    canvas.drawCircle(
      center,
      canvasSize / 2 * 0.30,
      Paint()
        ..color = Colors.white.withOpacity(0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawCircle(
      center,
      canvasSize / 2 * 0.26,
      Paint()..color = const Color(0xFF4285F4),
    );

    canvas.drawCircle(
      center,
      canvasSize / 2 * 0.26,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = canvasSize * 0.055,
    );

    canvas.drawCircle(
      center,
      canvasSize / 2 * 0.36,
      Paint()
        ..color = const Color(0x884285F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = canvasSize * 0.022,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes, size: Size(logicalSize, logicalSize));
  }

  double? _parseCoordinate(dynamic value) {
    if (value == null)   return null;
    if (value is double) return value;
    if (value is int)    return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _moveCameraToMarkers() {
    if (_mapController == null) return;
    final courtMarkers = _markers
        .where((m) => m.markerId.value != 'user_location')
        .toSet();
    if (courtMarkers.isEmpty) {
      _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(const LatLng(35.6762, 139.6503), 10));
      return;
    }
    if (courtMarkers.length == 1) {
      _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(courtMarkers.first.position, 14));
      return;
    }
    double? minLat, maxLat, minLng, maxLng;
    for (final m in courtMarkers) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      minLat = minLat == null ? lat : (lat < minLat ? lat : minLat);
      maxLat = maxLat == null ? lat : (lat > maxLat ? lat : maxLat);
      minLng = minLng == null ? lng : (lng < minLng ? lng : minLng);
      maxLng = maxLng == null ? lng : (lng > maxLng ? lng : maxLng);
    }
    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      if (minLat == maxLat && minLng == maxLng) {
        _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14));
      } else {
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
            LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng)),
            80));
      }
    }
  }

  void _updateMarkers(List<Map<String, dynamic>> filtered) {
    final newMarkers = <Marker>{};

    for (int i = 0; i < filtered.length; i++) {
      final loc = filtered[i];
      final lat = _parseCoordinate(loc['loc_latitude']);
      final lng = _parseCoordinate(loc['loc_longitude']);
      if (lat != null && lng != null) {
        newMarkers.add(Marker(
          markerId: MarkerId(loc['_doc_id'] ?? 'court_$i'),
          position: LatLng(lat, lng),
          onTap: () {
            final lang = ref.read(appLangProvider);
            _showCourtSheet(loc, lang);
          },
        ));
      }
    }

    if (_userLocationMarker != null) {
      newMarkers.add(_userLocationMarker!);
    }

    setState(() => _markers = newMarkers);

    final focusId = ref.read(focusedCourtIdProvider);
    if (focusId != null && focusId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryFocusCourt(focusId);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 800), _moveCameraToMarkers);
    }
  }

  void _tryFocusCourt(String docId) {
    if (!mounted) return;
    final loc = _lastLocations.firstWhere(
          (l) => (l['_doc_id']?.toString() ?? '') == docId,
      orElse: () => <String, dynamic>{},
    );
    if (loc.isEmpty) return;
    final lat = _parseCoordinate(loc['loc_latitude']);
    final lng = _parseCoordinate(loc['loc_longitude']);
    if (lat == null || lng == null) return;

    if (_mapController == null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _tryFocusCourt(docId);
      });
      return;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
    );

    final lang = ref.read(appLangProvider);
    _showCourtSheet(loc, lang);

    Future.microtask(() {
      if (mounted) {
        ref.read(focusedCourtIdProvider.notifier).state = null;
      }
    });
  }

  void _applySearchAndFilter() {
    final search = _searchController.text.trim().toLowerCase();
    final filtered = _lastLocations.where((loc) {
      if (search.isNotEmpty) {
        final name   = (loc['loc_name']         ?? '').toString().toLowerCase();
        final nameJp = (loc['loc_name_jp']       ?? '').toString().toLowerCase();
        final city   = (loc['loc_city']          ?? '').toString().toLowerCase();
        final cityEn = (loc['loc_city_en']       ?? '').toString().toLowerCase();
        final pref   = (loc['loc_prefecture']    ?? '').toString().toLowerCase();
        final prefEn = (loc['loc_prefecture_en'] ?? '').toString().toLowerCase();
        final addr   = (loc['loc_address']       ?? '').toString().toLowerCase();
        final addrJp = (loc['loc_address_jp']    ?? '').toString().toLowerCase();
        if (!name.contains(search)   && !nameJp.contains(search) &&
            !city.contains(search)   && !cityEn.contains(search) &&
            !pref.contains(search)   && !prefEn.contains(search) &&
            !addr.contains(search)   && !addrJp.contains(search)) return false;
        return _filter.matchesNonGeo(loc);
      }
      return _filter.matchesLocation(loc);
    }).toList();
    _updateMarkers(filtered);
  }

  void _showCourtSheet(Map<String, dynamic> loc, String lang) {
    final t = _T.of(lang);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CourtDetailSheet(loc: loc, lang: lang, t: t),
    );
  }

  void _openFilterModal(List<Map<String, dynamic>> allLocations, String lang) async {
    final t = _T.of(lang);
    final result = await showModalBottomSheet<CourtFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CourtFilterModal(
        currentFilter: _filter,
        allLocations: allLocations,
        lang: lang,
        t: t,
      ),
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
      _applySearchAndFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final lang           = ref.watch(appLangProvider);
    final t              = _T.of(lang);
    final showAddButton  = ref.watch(showAddCourtButtonProvider);
    final locationsAsync = ref.watch(locationsProvider);
    final allLocations   = locationsAsync.asData?.value ?? [];

    // ── ADDED: Listen for reset signal from Home screen's "See all" ──────────
    // When triggered, reset filter to Tokyo default and clear search.
    ref.listen<int>(resetCourtsFilterProvider, (prev, next) {
      if (next != prev) {
        setState(() {
          _filter = CourtFilter.defaultFilter;
          _searchController.clear();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applySearchAndFilter();
        });
      }
    });

    // React when the Home screen (or anywhere else) asks us to focus a court.
    ref.listen<String?>(focusedCourtIdProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryFocusCourt(next);
        });
      }
    });

    if (locationsAsync.hasValue && allLocations.isNotEmpty) {
      final newIds = allLocations.map((l) => l['_doc_id']?.toString() ?? '').toSet();
      final oldIds = _lastLocations.map((l) => l['_doc_id']?.toString() ?? '').toSet();
      if (!newIds.containsAll(oldIds) || !oldIds.containsAll(newIds)) {
        _lastLocations = allLocations;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applySearchAndFilter();
        });
      }
    }

    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredLocations = allLocations.where((loc) {
      if (searchQuery.isNotEmpty) {
        final name   = (loc['loc_name']         ?? '').toString().toLowerCase();
        final nameJp = (loc['loc_name_jp']       ?? '').toString().toLowerCase();
        final city   = (loc['loc_city']          ?? '').toString().toLowerCase();
        final cityEn = (loc['loc_city_en']       ?? '').toString().toLowerCase();
        final pref   = (loc['loc_prefecture']    ?? '').toString().toLowerCase();
        final prefEn = (loc['loc_prefecture_en'] ?? '').toString().toLowerCase();
        final addr   = (loc['loc_address']       ?? '').toString().toLowerCase();
        final addrJp = (loc['loc_address_jp']    ?? '').toString().toLowerCase();
        if (!name.contains(searchQuery) && !nameJp.contains(searchQuery) &&
            !city.contains(searchQuery) && !cityEn.contains(searchQuery) &&
            !pref.contains(searchQuery) && !prefEn.contains(searchQuery) &&
            !addr.contains(searchQuery) && !addrJp.contains(searchQuery)) return false;
        return _filter.matchesNonGeo(loc);
      }
      return _filter.matchesLocation(loc);
    }).toList();

    final hasActiveFilter = _hasActiveFilter(_filter);

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            child: GoogleMap(
              key: const ValueKey('google_map'),
              initialCameraPosition: _initialPosition,
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              mapType: MapType.normal,
              compassEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                setState(() => _mapReady = true);
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted && _markers.isNotEmpty) _moveCameraToMarkers();
                });
                if (Platform.isIOS && _userLocationMarker == null) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && _userLocationMarker == null) {
                      _locationInitDone = false;
                      _initUserLocation();
                    }
                  });
                }
              },
            ),
          ),

          if (!_mapReady && Platform.isIOS)
            Container(
              color: const Color(0xFFF4F9F5),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(t.loadingMap,
                      style: TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

          SafeArea(
            child: Column(children: [
              _buildHeader(allLocations, hasActiveFilter, lang, t),
            ]),
          ),

          if (_lastLocations.isNotEmpty && (searchQuery.isNotEmpty || hasActiveFilter))
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Text(
                    lang == kLangJa
                        ? '${filteredLocations.length}${t.courtsFound}'
                        : '${filteredLocations.length} ${t.courtsFound}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),

          if (showAddButton)
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Center(child: _buildAddCourtButton(t)),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      List<Map<String, dynamic>> allLocations,
      bool hasActiveFilter,
      String lang,
      _T t,
      ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text(t.courts,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: Color(0xFF0D0D0D), letterSpacing: -0.5)),
                const SizedBox(width: 8),
                if (!hasActiveFilter)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(t.tokyo,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 8),

          _LangToggle(
            lang: lang,
            onToggle: (selected) =>
                ref.read(appLangProvider.notifier).setLang(selected),
          ),
          const SizedBox(width: 8),

          GestureDetector(
            onTap: () => _openFilterModal(allLocations, lang),
            child: Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: hasActiveFilter ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: hasActiveFilter
                            ? AppColors.primary.withOpacity(0.4)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(Icons.tune_rounded,
                    color: hasActiveFilter ? Colors.white : AppColors.primary,
                    size: 22),
              ),
              if (hasActiveFilter)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(
                        color: Colors.orangeAccent, shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) {
              setState(() {});
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                _applySearchAndFilter();
              });
            },
            style: const TextStyle(fontSize: 15, color: Color(0xFF0D0D0D)),
            decoration: InputDecoration(
              hintText: t.search,
              hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.35),
                  fontSize: 15, fontWeight: FontWeight.w400),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.black.withOpacity(0.35), size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {});
                    _applySearchAndFilter();
                  },
                  child: Icon(Icons.close_rounded,
                      color: Colors.black.withOpacity(0.35), size: 20))
                  : null,
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildAddCourtButton(_T t) {
    return Stack(clipBehavior: Clip.none, children: [
      GestureDetector(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddCourtScreen())),
        child: Container(
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(t.addCourt,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          ]),
        ),
      ),
      Positioned(
        top: -8, right: -8,
        child: GestureDetector(
          onTap: () =>
          ref.read(showAddCourtButtonProvider.notifier).state = false,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
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
    ]);
  }
}

// ── Language Toggle ────────────────────────────────────────────────────────────
class _LangToggle extends StatelessWidget {
  final String lang;
  final ValueChanged<String> onToggle;
  const _LangToggle({required this.lang, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _tab('EN',    lang == kLangEn, () => onToggle(kLangEn)),
        _tab('日本語', lang == kLangJa, () => onToggle(kLangJa)),
      ]),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : Colors.black.withOpacity(0.4))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Court Detail Bottom Sheet — LIGHT MODE
// ─────────────────────────────────────────────────────────────────────────────
class _CourtDetailSheet extends StatefulWidget {
  final Map<String, dynamic> loc;
  final String lang;
  final _T t;
  const _CourtDetailSheet({required this.loc, required this.lang, required this.t});

  @override
  State<_CourtDetailSheet> createState() => _CourtDetailSheetState();
}

class _CourtDetailSheetState extends State<_CourtDetailSheet> {
  static const Color _sheetBg   = Color(0xFFF5F7F4);
  static const Color _cardBg    = Colors.white;
  static const Color _primary   = Color(0xFF497C38);
  static const Color _accent    = Color(0xFF6AAF52);
  static const Color _accentSoft= Color(0xFFDDEDD6);
  static const Color _textDark  = Color(0xFF222222);
  static const Color _textMid   = Color(0xFF444444);
  static const Color _textLight = Color(0xFF777777);
  static const Color _border    = Color(0xFFCCDEC5);
  static const Color _errorBg   = Color(0xFFFFF0F0);
  static const Color _successBg = Color(0xFFEEF7EA);

  bool _showReviewForm = false;
  bool _showPhotoForm  = false;
  String _reviewText   = '';
  List<File> _files    = [];
  bool _isSubmitting   = false;
  String _errorLine    = '';
  String _successMsg   = '';
  bool _loadingReviews = true;
  List<Map<String, dynamic>> _reviews     = [];
  List<Map<String, dynamic>> _courtImages = [];
  int? _selectedImageIndex;

  // ── Facility sections (Upcoming Events / Local Groups at this Facility) ──
  bool _loadingFacility = true;
  List<Map<String, dynamic>> _facilityEvents = [];
  List<Map<String, dynamic>> _facilityGroups = [];
  bool _facilityEventsExpanded = true;
  bool _facilityGroupsExpanded = true;

  // ── Pagination state (mirrors web app: 3 items per page) ──
  static const int _facilityPageSize = 3;
  int _eventsPage = 1;
  int _groupsPage = 1;



  final TextEditingController _reviewController = TextEditingController();

  bool get _isJa => widget.lang == kLangJa;
  _T   get _t    => widget.t;
  Map<String, dynamic> get _loc => widget.loc;
  String get _locId => (_loc['loc_id'] ?? _loc['_doc_id'] ?? '').toString();

  List<String> get _allImages {
    final reviewImgs = _reviews.expand<String>((r) {
      final urls = r['image_urls'];
      if (urls is List) return urls.cast<String>();
      final url = r['image_url'];
      if (url is String && url.isNotEmpty) return [url];
      return [];
    }).toList();
    final courtImgs = _courtImages.expand<String>((img) {
      final imgs = img['images'];
      if (imgs is List) return imgs.cast<String>();
      return [];
    }).toList();
    return [...reviewImgs, ...courtImgs];
  }

  String get _name {
    if (_isJa) {
      final jp = (_loc['loc_name_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (_loc['loc_name'] ?? 'Court').toString();
  }

  String get _address {
    if (_isJa) {
      final jp = (_loc['loc_address_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (_loc['loc_address'] ?? '').toString();
  }

  String get _city {
    if (_isJa) {
      final jp = (_loc['loc_city_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    final en = (_loc['loc_city_en'] ?? '').toString().trim();
    return en.isNotEmpty ? en : (_loc['loc_city'] ?? '').toString();
  }

  String get _prefecture {
    if (_isJa) {
      final jp = (_loc['loc_prefecture_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    final en = (_loc['loc_prefecture_en'] ?? '').toString().trim();
    return en.isNotEmpty ? en : (_loc['loc_prefecture'] ?? '').toString();
  }

  String get _country    => (_loc['loc_country']   ?? '').toString();
  String get _type       => (_loc['loc_type']       ?? '').toString();
  String get _price      => (_loc['loc_price']      ?? '').toString();
  String get _googleLink => (_loc['loc_googlelink'] ?? '').toString();
  String get _website    => (_loc['loc_website']    ?? '').toString();
  String get _image      => (_loc['loc_image']      ?? '').toString();
  String get _primaryLink => _website.isNotEmpty ? _website : _googleLink;

  String get _setupTypeLabel {
    final raw = (_loc['loc_setup_type'] ?? '').toString().trim();
    if (!_isJa || raw.isEmpty) return raw;
    if (raw == 'Public Access Courts')         return _t.setupPublic;
    if (raw == 'Private / Coordinated Courts') return _t.setupPrivate;
    return raw;
  }

  String get _priceDisplay {
    final isFree = _loc['loc_price_free'] == true ||
        _loc['loc_price_free']?.toString() == 'T';
    if (isFree) return _t.free;
    return _price;
  }

  int get _courtCount {
    final v = _loc['loc_court_count'];
    if (v is int)    return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool get _isIndoor  => _loc['loc_court_type_indoor']  == true ||
      _loc['loc_court_type_indoor']?.toString()  == 'T';
  bool get _isOutdoor => _loc['loc_court_type_outdoor'] == true ||
      _loc['loc_court_type_outdoor']?.toString() == 'T';

  String get _courtCountLabel {
    if (_courtCount <= 0) return '';
    if (_isJa) return '$_courtCount コート';
    return '$_courtCount court${_courtCount == 1 ? '' : 's'}';
  }

  String get _locationLine =>
      [_city, _prefecture, _country].where((s) => s.isNotEmpty).join(', ');

  String get _hoursFormatted {
    const days = [
      ('Mon', 'loc_hours_mon'),   ('Tue', 'loc_hours_tues'),
      ('Wed', 'loc_hours_weds'),  ('Thu', 'loc_hours_thurs'),
      ('Fri', 'loc_hours_fri'),   ('Sat', 'loc_hours_sat'),
      ('Sun', 'loc_hours_sun'),
    ];
    final filled = <(String, String)>[];
    for (final (label, field) in days) {
      final v = (_loc[field] ?? '').toString().trim();
      if (v.isNotEmpty) filled.add((label, v));
    }
    if (filled.isEmpty) return '';
    final groups = <({String range, String hours})>[];
    String startDay = filled[0].$1, prevDay = filled[0].$1, curHours = filled[0].$2;
    for (int i = 1; i < filled.length; i++) {
      final (day, hours) = filled[i];
      if (hours == curHours) {
        prevDay = day;
      } else {
        groups.add((range: startDay == prevDay ? startDay : '$startDay–$prevDay', hours: curHours));
        startDay = prevDay = day;
        curHours = hours;
      }
    }
    groups.add((range: startDay == prevDay ? startDay : '$startDay–$prevDay', hours: curHours));
    return groups.map((g) => '${g.range}: ${g.hours}').join('\n');
  }

  bool _isTruthy(dynamic v) =>
      v == true || v?.toString() == 'T' || v?.toString() == 'Yes';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadFacilitySections();
  }

  // ───────────────────────── Facility data loader ─────────────────────────
  // Mirrors web app logic: query events by event_loc_id, then derive groups
  // from event_org_id (org_public == true).
  Future<void> _loadFacilitySections() async {
    if (_locId.isEmpty) {
      if (mounted) setState(() => _loadingFacility = false);
      return;
    }
    setState(() => _loadingFacility = true);
    try {
      final db = FirebaseFirestore.instance;

      DateTime? _toDate(dynamic v) {
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
        return null;
      }

      // 1. Fetch events for this facility (mirror web app filters)
      final eventsSnap = await db
          .collection('events')
          .where('event_loc_id', isEqualTo: _locId)
          .where('event_active', isEqualTo: true)
          .where('event_checked', isEqualTo: true)
          .where('event_pending_review', isEqualTo: false)
          .get();

      final allEvents = eventsSnap.docs
          .map((d) => {'_doc_id': d.id, 'id': d.id, ...d.data()})
          .toList();

      // 2. Filter upcoming
      final now = DateTime.now();
      final upcoming = allEvents.where((e) {
        final d = _toDate(e['event_date']);
        return d != null && !d.isBefore(now);
      }).toList();

      upcoming.sort((a, b) {
        final da = _toDate(a['event_date']) ?? DateTime(2100);
        final db_ = _toDate(b['event_date']) ?? DateTime(2100);
        return da.compareTo(db_);
      });

      // 3. Local Groups — unique org ids from events (sorted by most recent event)
      final sortedDesc = [...allEvents]..sort((a, b) {
        final ta = _toDate(a['event_date'])?.millisecondsSinceEpoch ?? 0;
        final tb = _toDate(b['event_date'])?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      final uniqueOrgIds = <String>[];
      final seen = <String>{};
      for (final e in sortedDesc) {
        final oid = (e['event_org_id'] ?? '').toString();
        if (oid.isNotEmpty && seen.add(oid)) uniqueOrgIds.add(oid);
      }

      final resolvedGroups = <Map<String, dynamic>>[];
      for (final orgId in uniqueOrgIds) {
        if (resolvedGroups.length >= 20) break;
        Map<String, dynamic>? groupDoc;
        try {
          final snap = await db.collection('organizations').doc(orgId).get();
          if (snap.exists) {
            groupDoc = {'_doc_id': snap.id, ...?snap.data()};
          } else {
            final q = await db
                .collection('organizations')
                .where('org_id', isEqualTo: orgId)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              groupDoc = {'_doc_id': q.docs.first.id, ...q.docs.first.data()};
            }
          }
        } catch (e) {
          debugPrint('[facility] org lookup failed for $orgId: $e');
        }
        if (groupDoc != null && groupDoc['org_public'] == true) {
          resolvedGroups.add(groupDoc);
        }
      }

      if (mounted) {
        setState(() {
          _facilityEvents = upcoming;
          _facilityGroups = resolvedGroups;
          _eventsPage = 1;
          _groupsPage = 1;
        });
      }

    } catch (e) {
      debugPrint('[CourtDetailSheet] _loadFacilitySections error: $e');
    } finally {
      if (mounted) setState(() => _loadingFacility = false);
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loadingReviews = true);
    try {
      final db = FirebaseFirestore.instance;
      final reviewsSnap = await db
          .collection('reviews')
          .where('loc_id', isEqualTo: _locId)
          .get();
      final imagesSnap = await db
          .collection('court_images')
          .where('loc_id', isEqualTo: _locId)
          .get();

      // ── Mirror web app filter exactly:
      //   review_pending_review == false AND rejected != true
      final reviews = reviewsSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((r) =>
      r['review_pending_review'] == false &&
          r['rejected'] != true)
          .toList();
      reviews.sort((a, b) {
        final tA = (a['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tB = (b['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tB.compareTo(tA);
      });

      final courtImages = imagesSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((img) => img['court_images_pending_review'] == false)
          .toList();
      courtImages.sort((a, b) {
        final tA = (a['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tB = (b['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _reviews     = reviews;
          _courtImages = courtImages;
        });
      }
    } catch (e) {
      debugPrint('[CourtDetailSheet] _fetchData error: $e');
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty && mounted) {
      setState(() => _files = [..._files, ...picked.map((x) => File(x.path))]);
    }
  }

  Future<List<String>> _uploadFiles() async {
    final storage = FirebaseStorage.instance;
    final urls = <String>[];
    for (final f in _files) {
      final name = '${DateTime.now().millisecondsSinceEpoch}_${f.path.split('/').last}';
      final ref  = storage.ref('court_images/$name');
      final snap = await ref.putFile(f);
      urls.add(await snap.ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _errorLine = _t.signInRequired); return; }
    if (_reviewText.length < 85) { setState(() => _errorLine = _t.reviewMinError); return; }
    setState(() { _isSubmitting = true; _errorLine = ''; });
    try {
      final imageUrls = _files.isNotEmpty ? await _uploadFiles() : <String>[];
      await FirebaseFirestore.instance.collection('reviews').add({
        'loc_id':                _locId,
        'review_pending_review': true,
        'text':                  _reviewText,
        'image_urls':            imageUrls,
        'user_id':               user.uid,
        'user_name':             user.displayName ?? _t.anonymous,
        'user_image':            user.photoURL,
        'created_at':            FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _reviewText = '';
          _reviewController.clear();
          _files = [];
          _showReviewForm = false;
          _successMsg = _isJa ? 'レビューを投稿しました！' : 'Review posted successfully!';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _successMsg = '');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorLine = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitPhotos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _errorLine = _t.signInRequired); return; }
    if (_files.isEmpty) { setState(() => _errorLine = _t.photoSelectError); return; }
    setState(() { _isSubmitting = true; _errorLine = ''; });
    try {
      final imageUrls = await _uploadFiles();
      await FirebaseFirestore.instance.collection('court_images').add({
        'loc_id':                         _locId,
        'user_id':                        user.uid,
        'images':                         imageUrls,
        'created_at':                     FieldValue.serverTimestamp(),
        'court_images_pending_review':    true,
      });
      if (mounted) {
        setState(() {
          _files = [];
          _showPhotoForm = false;
          _successMsg = _isJa ? '写真をアップロードしました！' : 'Photos uploaded successfully!';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _successMsg = '');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorLine = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = _loc['loc_latitude'] != null && _loc['loc_longitude'] != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 40,
              offset: const Offset(0, -4)),
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.91,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2)),
          ),

          if (_image.isNotEmpty)
            Stack(children: [
              SizedBox(
                height: 200, width: double.infinity,
                child: Image.network(_image, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: _accentSoft,
                      child: Icon(Icons.sports_tennis_rounded, size: 52, color: _primary.withOpacity(0.4)),
                    )),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [_sheetBg, Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12, left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_t.active,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              if (_type.isNotEmpty)
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: Text(_type,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: _primary)),
                  ),
                ),
              Positioned(
                top: 12, right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      shape: BoxShape.circle,
                      border: Border.all(color: _border),
                    ),
                    child: Icon(Icons.close_rounded, size: 16, color: _textDark),
                  ),
                ),
              ),
            ])
          else
            Stack(children: [
              Container(
                height: 100, width: double.infinity,
                color: _accentSoft,
                child: Icon(Icons.sports_tennis_rounded, size: 48, color: _primary.withOpacity(0.4)),
              ),
              Positioned(
                top: 12, right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _border),
                    ),
                    child: Icon(Icons.close_rounded, size: 16, color: _textDark),
                  ),
                ),
              ),
            ]),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                Text(_name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: _textDark, letterSpacing: -0.3)),
                if (_loc['loc_name_jp'] != null && !_isJa) ...[
                  const SizedBox(height: 3),
                  Text(_loc['loc_name_jp'].toString(),
                      style: TextStyle(fontSize: 11, color: _textLight)),
                ],
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                          color: _primary.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_locationLine.isNotEmpty) _infoRow(Icons.location_on_rounded,   _locationLine),
                    if (_address.isNotEmpty)      _infoRow(Icons.home_rounded,          _address),
                    if (_priceDisplay.isNotEmpty) _infoRow(Icons.payments_outlined,     _priceDisplay),
                    if (_hoursFormatted.isNotEmpty) _infoRow(Icons.access_time_rounded, _hoursFormatted),
                    if (_setupTypeLabel.isNotEmpty) _infoRow(Icons.construction_rounded, _setupTypeLabel),
                  ]),
                ),

                if (_isIndoor || _isOutdoor || _courtCount > 0 ||
                    _isTruthy(_loc['loc_amenities_dedicated'])    ||
                    _isTruthy(_loc['loc_amenities_membership'])   ||
                    _isTruthy(_loc['loc_amenities_openplay'])     ||
                    _isTruthy(_loc['loc_amenities_reservation'])  ||
                    _isTruthy(_loc['loc_amenities_lessons'])      ||
                    _isTruthy(_loc['loc_amenities_paddlerentals'])) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (_isIndoor)              _primaryTag('🏠 ${_t.indoor2}'),
                    if (_isOutdoor)             _primaryTag('🌳 ${_t.outdoor2}'),
                    if (_courtCountLabel.isNotEmpty) _primaryTag(_courtCountLabel),
                    if (_isTruthy(_loc['loc_amenities_dedicated']))    _softTag(_t.amenityDedicated),
                    if (_isTruthy(_loc['loc_amenities_membership']))   _softTag(_t.amenityMembership),
                    if (_isTruthy(_loc['loc_amenities_openplay']))     _softTag(_t.amenityOpenPlay),
                    if (_isTruthy(_loc['loc_amenities_reservation']))  _softTag(_t.amenityReservation),
                    if (_isTruthy(_loc['loc_amenities_lessons']))      _softTag(_t.amenityLessons),
                    if (_isTruthy(_loc['loc_amenities_paddlerentals'])) _softTag(_t.amenityPaddleRentals),
                  ]),
                ],

                if (!hasCoords) ...[
                  const SizedBox(height: 8),
                  Text(_t.noCoords,
                      style: TextStyle(
                          fontSize: 11, color: _textLight, fontStyle: FontStyle.italic)),
                ],

                if (_allImages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildGallery(),
                ],

                _buildFacilitySections(),

                const SizedBox(height: 18),

                if (_primaryLink.isNotEmpty)
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _openLink(_primaryLink),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 18, color: Colors.white),
                      label: Text(_t.moreInfo,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                if (_googleLink.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _openLink(_googleLink),
                      icon: Icon(Icons.map_rounded, size: 18, color: _primary),
                      label: Text(_t.viewOnMaps,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: _primary)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _primary, width: 1.5),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _accentSoft.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline_rounded, size: 13, color: _textLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_t.disclaimer,
                          style: TextStyle(fontSize: 10, color: _textMid, height: 1.5)),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),
                Divider(color: _border, height: 1),
                const SizedBox(height: 16),

                if (_errorLine.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _errorBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Text(_errorLine,
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),

                if (_successMsg.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _successBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accent.withOpacity(0.3)),
                    ),
                    child: Text(_successMsg,
                        style: TextStyle(
                            color: _primary,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),

                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _showReviewForm = !_showReviewForm;
                        _showPhotoForm  = false;
                        _errorLine = '';
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 48,
                        decoration: BoxDecoration(
                          color: _showReviewForm ? _primary : _cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _showReviewForm ? _primary : _border,
                              width: 1.5),
                          boxShadow: _showReviewForm ? [
                            BoxShadow(
                                color: _primary.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ] : [],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.star_outline_rounded, size: 16,
                              color: _showReviewForm ? Colors.white : _primary),
                          const SizedBox(width: 6),
                          Text(_t.writeReview,
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: _showReviewForm ? Colors.white : _primary)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _showPhotoForm  = !_showPhotoForm;
                        _showReviewForm = false;
                        _errorLine = '';
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 48,
                        decoration: BoxDecoration(
                          color: _showPhotoForm ? _primary : _cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _showPhotoForm ? _primary : _border,
                              width: 1.5),
                          boxShadow: _showPhotoForm ? [
                            BoxShadow(
                                color: _primary.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ] : [],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.camera_alt_outlined, size: 16,
                              color: _showPhotoForm ? Colors.white : _primary),
                          const SizedBox(width: 6),
                          Text(_t.addPhotos,
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: _showPhotoForm ? Colors.white : _primary)),
                        ]),
                      ),
                    ),
                  ),
                ]),

                if (_showReviewForm) ...[
                  const SizedBox(height: 14),
                  _buildReviewForm(),
                ],

                if (_showPhotoForm) ...[
                  const SizedBox(height: 14),
                  _buildPhotoForm(),
                ],

                const SizedBox(height: 20),
                Divider(color: _border, height: 1),

                if (_loadingReviews)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(_t.loadingReviews,
                          style: TextStyle(fontSize: 12, color: _textLight)),
                    ),
                  )
                else if (_reviews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(_t.noReviews,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _textLight)),
                    ),
                  )
                else ...[
                    const SizedBox(height: 16),
                    ..._reviews.map((review) => _buildReviewItem(review)),
                  ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────── Facility sections UI (Upcoming Events / Local Groups) ───────────
  Widget _buildFacilitySections() {
    if (_loadingFacility) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(
          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2),
        )),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_facilityEvents.isNotEmpty) ...[
        const SizedBox(height: 18),
        _facilitySectionHeader(
          emoji: '📅',
          label: _isJa ? 'この施設で開催予定のイベント' : 'Upcoming Events at this Facility',
          count: _facilityEvents.length,
          expanded: _facilityEventsExpanded,
          onTap: () => setState(() => _facilityEventsExpanded = !_facilityEventsExpanded),
        ),
        if (_facilityEventsExpanded) ...[
          const SizedBox(height: 8),
          ...(() {
            // Mirror web app: slice the list and render only the current page
            // (3 per page) so we don't pay for rendering everything at once.
            final totalPages =
            (_facilityEvents.length / _facilityPageSize).ceil().clamp(1, 9999);
            if (_eventsPage > totalPages) _eventsPage = totalPages;
            final start = (_eventsPage - 1) * _facilityPageSize;
            final end = (start + _facilityPageSize) > _facilityEvents.length
                ? _facilityEvents.length
                : (start + _facilityPageSize);
            final pageItems = _facilityEvents.sublist(start, end);
            return pageItems.map((e) {
              final title = _isJa
                  ? ((e['event_title_jp'] ?? e['event_title'] ?? e['event_name'] ?? '').toString())
                  : ((e['event_title'] ?? e['event_name'] ?? '').toString());
              final img = (e['event_pic'] ?? e['event_pic_thumbnail'] ?? e['event_image'] ?? '').toString();
              final dt = e['event_date'];
              String subtitle = '';
              DateTime? d;
              if (dt is Timestamp) d = dt.toDate();
              if (dt is String) d = DateTime.tryParse(dt);
              if (d != null) {
                subtitle = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              }
              return _facilityListTile(image: img, title: title, subtitle: subtitle, onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: Map<String, dynamic>.from(e)),
                ));
              });
            });
          })(),
          if (_facilityEvents.length > _facilityPageSize)
            _facilityPaginationBar(
              currentPage: _eventsPage,
              totalPages: (_facilityEvents.length / _facilityPageSize).ceil(),
              onPrev: () => setState(() {
                if (_eventsPage > 1) _eventsPage--;
              }),
              onNext: () => setState(() {
                final tp = (_facilityEvents.length / _facilityPageSize).ceil();
                if (_eventsPage < tp) _eventsPage++;
              }),
            ),
        ],

      ] else if (!_loadingFacility) ...[
        const SizedBox(height: 18),
        _facilitySectionHeader(
          emoji: '📅',
          label: _isJa ? 'この施設で開催予定のイベント' : 'Upcoming Events at this Facility',
          count: 0,
          expanded: _facilityEventsExpanded,
          onTap: () => setState(() => _facilityEventsExpanded = !_facilityEventsExpanded),
        ),
        if (_facilityEventsExpanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Text(
              _isJa
                  ? 'この施設で予定されているイベントはありません。'
                  : 'No upcoming events scheduled at this facility.',
              style: TextStyle(fontSize: 12, color: _textLight),
            ),
          ),
        ],
      ],
      if (_facilityGroups.isNotEmpty) ...[
        const SizedBox(height: 18),
        _facilitySectionHeader(
          emoji: '👥',
          label: _isJa ? 'この施設を利用しているグループ' : 'Local Groups at this Facility',
          count: _facilityGroups.length,
          expanded: _facilityGroupsExpanded,
          onTap: () => setState(() => _facilityGroupsExpanded = !_facilityGroupsExpanded),
        ),
        if (_facilityGroupsExpanded) ...[
          const SizedBox(height: 8),
          ...(() {
            final totalPages =
            (_facilityGroups.length / _facilityPageSize).ceil().clamp(1, 9999);
            if (_groupsPage > totalPages) _groupsPage = totalPages;
            final start = (_groupsPage - 1) * _facilityPageSize;
            final end = (start + _facilityPageSize) > _facilityGroups.length
                ? _facilityGroups.length
                : (start + _facilityPageSize);
            final pageItems = _facilityGroups.sublist(start, end);
            return pageItems.map((g) {
              final title = _isJa
                  ? ((g['org_name_jp'] ?? g['org_name'] ?? '').toString())
                  : ((g['org_name'] ?? '').toString());
              final img = (g['org_logo_url'] ?? g['org_image'] ?? g['org_logo'] ?? '').toString();
              final subtitle = (g['org_type'] ?? g['org_city'] ?? '').toString();
              return _facilityListTile(image: img, title: title, subtitle: subtitle, onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(group: Map<String, dynamic>.from(g)),
                ));
              });
            });
          })(),
          if (_facilityGroups.length > _facilityPageSize)
            _facilityPaginationBar(
              currentPage: _groupsPage,
              totalPages: (_facilityGroups.length / _facilityPageSize).ceil(),
              onPrev: () => setState(() {
                if (_groupsPage > 1) _groupsPage--;
              }),
              onNext: () => setState(() {
                final tp = (_facilityGroups.length / _facilityPageSize).ceil();
                if (_groupsPage < tp) _groupsPage++;
              }),
            ),
        ],

      ] else if (!_loadingFacility) ...[
        const SizedBox(height: 18),
        _facilitySectionHeader(
          emoji: '👥',
          label: _isJa ? 'この施設を利用しているグループ' : 'Local Groups at this Facility',
          count: 0,
          expanded: _facilityGroupsExpanded,
          onTap: () => setState(() => _facilityGroupsExpanded = !_facilityGroupsExpanded),
        ),
        if (_facilityGroupsExpanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Text(
              _isJa
                  ? 'この施設でイベントを開催したグループはまだありません。'
                  : 'No groups have hosted events at this facility yet.',
              style: TextStyle(fontSize: 12, color: _textLight),
            ),
          ),
        ],
      ],
    ]);
  }

  Widget _facilitySectionHeader({
    required String emoji,
    required String label,
    required int count,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _accentSoft.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label ($count)',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _textDark),
            ),
          ),
          Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20, color: _primary),
        ]),
      ),
    );
  }

  Widget _facilityListTile({
    required String image,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48, height: 48,
                child: image.isNotEmpty
                    ? Image.network(image, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _accentSoft,
                        child: Icon(Icons.image_rounded, size: 20, color: _primary.withOpacity(0.4))))
                    : Container(color: _accentSoft,
                    child: Icon(Icons.image_rounded, size: 20, color: _primary.withOpacity(0.4))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title.isEmpty ? '—' : title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: _textLight)),
                ],
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: _textLight),
          ]),
        ),
      ),
    );
  }

  // ── Pagination bar (mirrors web app: ← Prev | X / Y | Next →) ──
  Widget _facilityPaginationBar({
    required int currentPage,
    required int totalPages,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    final isFirst = currentPage <= 1;
    final isLast = currentPage >= totalPages;

    Widget pageBtn({
      required String label,
      required bool disabled,
      required VoidCallback onTap,
    }) {
      return Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _accentSoft.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          pageBtn(label: '← Prev', disabled: isFirst, onTap: onPrev),
          Text(
            '$currentPage / $totalPages',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          pageBtn(label: 'Next →', disabled: isLast, onTap: onNext),
        ],
      ),
    );
  }



  Widget _buildGallery() {
    final imgs = _allImages;
    if (imgs.isEmpty) return const SizedBox.shrink();

    Widget imgTile(String url, int index, {bool hasOverlay = false, int extra = 0}) {
      return GestureDetector(
        onTap: () => setState(() => _selectedImageIndex = index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(fit: StackFit.expand, children: [
            Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: _accentSoft)),
            if (hasOverlay)
              Container(
                color: Colors.black.withOpacity(0.45),
                child: Center(
                  child: Text('+$extra',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
      );
    }

    Widget gallery;
    if (imgs.length == 1) {
      gallery = SizedBox(height: 200, child: imgTile(imgs[0], 0));
    } else if (imgs.length == 2) {
      gallery = SizedBox(
        height: 200,
        child: Row(children: [
          Expanded(child: imgTile(imgs[0], 0)),
          const SizedBox(width: 4),
          Expanded(child: imgTile(imgs[1], 1)),
        ]),
      );
    } else {
      gallery = SizedBox(
        height: 200,
        child: Row(children: [
          Expanded(flex: 2, child: imgTile(imgs[0], 0)),
          const SizedBox(width: 4),
          Expanded(child: Column(children: [
            Expanded(child: imgTile(imgs[1], 1)),
            const SizedBox(height: 4),
            Expanded(child: imgTile(imgs[2], 2, hasOverlay: imgs.length > 3, extra: imgs.length - 3)),
          ])),
        ]),
      );
    }

    return Column(children: [
      gallery,
      if (_selectedImageIndex != null)
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _selectedImageIndex = null),
            child: Container(
              color: Colors.black.withOpacity(0.95),
              child: Stack(alignment: Alignment.center, children: [
                InteractiveViewer(
                  child: Image.network(imgs[_selectedImageIndex!], fit: BoxFit.contain),
                ),
                Positioned(
                  top: 16, right: 16,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImageIndex = null),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                if (_selectedImageIndex! > 0)
                  Positioned(
                    left: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImageIndex = _selectedImageIndex! - 1),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                if (_selectedImageIndex! < imgs.length - 1)
                  Positioned(
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImageIndex = _selectedImageIndex! + 1),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _buildReviewForm() {
    final remaining = 85 - _reviewText.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: _primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t.tellExperience,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: _textDark)),
        const SizedBox(height: 10),
        TextField(
          controller: _reviewController,
          onChanged: (v) => setState(() => _reviewText = v),
          maxLines: 5,
          style: const TextStyle(fontSize: 13, color: _textDark),
          decoration: InputDecoration(
            hintText: _t.startReview,
            hintStyle: TextStyle(color: _textLight, fontSize: 13),
            filled: true,
            fillColor: _sheetBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text(_t.reviewMinChars,
              style: TextStyle(fontSize: 10, color: _textLight)),
          if (remaining > 0)
            Text(' ($remaining ${_t.charsLeft})',
                style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
        ]),
        const SizedBox(height: 12),

        GestureDetector(
          onTap: _pickImages,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(12),
              color: _sheetBg,
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: _accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, size: 18, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(
                      _files.isEmpty
                          ? _t.addPhotosOptional
                          : '${_files.length} ${_t.photosSelected}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _textMid),
                    ),
                    if (_files.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _files = []),
                        child: Text(_t.clear,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.redAccent)),
                      ),
                    ],
                  ]),
                  Text(_t.uploadImages,
                      style: TextStyle(fontSize: 10, color: _textLight)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _reviewText.length >= 85 && !_isSubmitting ? _submitReview : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _primary.withOpacity(0.35),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_t.postReview,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _buildPhotoForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: _primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Image.asset(
          'assets/pickleball_ball_no_bg_1.png',
          width: 64,
          height: 64,
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            _files.isEmpty ? _t.dragDropHint : '${_files.length} ${_t.photosSelected}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _textDark),
          ),
          if (_files.isNotEmpty) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => _files = []),
              child: Text(_t.clear,
                  style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _pickImages,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_t.browseFiles,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        if (_files.isNotEmpty) ...[
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitPhotos,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_t.upload,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ]),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final userName  = (review['user_name'] ?? _t.anonymous).toString();
    final userImage = (review['user_image'] ?? '').toString();
    final text      = (review['text'] ?? '').toString();
    final createdAt = review['created_at'] as Timestamp?;
    final dateStr   = createdAt != null ? _formatDate(createdAt.toDate()) : '';
    final imgUrls = <String>[];
    final urls = review['image_urls'];
    if (urls is List) imgUrls.addAll(urls.cast<String>());
    final singleUrl = review['image_url'];
    if (singleUrl is String && singleUrl.isNotEmpty) imgUrls.add(singleUrl);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color: _primary.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _accentSoft,
              backgroundImage: userImage.isNotEmpty ? NetworkImage(userImage) : null,
              child: userImage.isEmpty
                  ? Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _primary))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(userName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
                if (dateStr.isNotEmpty)
                  Text(dateStr,
                      style: TextStyle(fontSize: 10, color: _textLight)),
              ]),
            ),
          ]),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(text,
                style: TextStyle(fontSize: 12, color: _textMid, height: 1.6)),
          ],
          if (imgUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: imgUrls.map((url) {
              final globalIdx = _allImages.indexOf(url);
              return GestureDetector(
                onTap: () => setState(
                        () => _selectedImageIndex = globalIdx >= 0 ? globalIdx : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 80, height: 80,
                    child: Image.network(url, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: _accentSoft)),
                  ),
                ),
              );
            }).toList()),
          ],
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) {
    if (_isJa) return '${d.year}年${d.month}月${d.day}日';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: _primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style: TextStyle(fontSize: 12, color: _textMid, height: 1.4)),
      ),
    ]),
  );

  Widget _primaryTag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: _primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withOpacity(0.2))),
    child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _primary)),
  );

  Widget _softTag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: _accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border)),
    child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textMid)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Modal
// ─────────────────────────────────────────────────────────────────────────────
class _CourtFilterModal extends StatefulWidget {
  final CourtFilter currentFilter;
  final List<Map<String, dynamic>> allLocations;
  final String lang;
  final _T t;

  const _CourtFilterModal({
    required this.currentFilter,
    required this.allLocations,
    required this.lang,
    required this.t,
  });

  @override
  State<_CourtFilterModal> createState() => _CourtFilterModalState();
}

class _CourtFilterModalState extends State<_CourtFilterModal> {
  late CourtFilter _draft;
  late final List<String> _prefectures;
  late final Map<String, List<String>> _citiesByPref;

  static const _setupTypes = [
    ('Public Access Courts',             'Public Access Courts',             '一般開放コート'),
    ('Private / Coordinated Courts',     'Private / Coordinated Courts',     '事前調整・予約制コート'),
    ('Reserved Courts',                  'Reserved Courts',                  '予約制コート'),
    ('Class/Membership Only Courts',     'Class/Membership Only Courts',     'クラス・会員限定コート'),
    ('Coordinated Group / Setup Courts', 'Coordinated Group / Setup Courts', '調整グループ／セットアップコート'),
    ('Drop-in Courts',                   'Drop-in Courts',                   'ドロップインコート'),
  ];

  static const _amenities = [
    ('Open Play',      'オープンプレイ',   'openplay'),
    ('Reservation',    '予約制',          'reservation'),
    ('Membership',     '会員制',          'membership'),
    ('Lessons',        'レッスンあり',     'lessons'),
    ('Dedicated',      '専用コート',       'dedicated'),
    ('Paddle Rentals', 'パドルレンタル',   'paddlerentals'),
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter;
    _buildLookups();
  }

  void _buildLookups() {
    final prefectures  = <String>{};
    final citiesByPref = <String, Set<String>>{};
    for (final loc in widget.allLocations) {
      final country = (loc['loc_country'] ?? '').toString().trim();
      if (country != 'Japan') continue;
      final prefEn  = (loc['loc_prefecture_en'] ?? '').toString().trim();
      final pref    = (loc['loc_prefecture']    ?? '').toString().trim();
      final prefVal = prefEn.isNotEmpty ? prefEn : pref;
      final cityEn  = (loc['loc_city_en'] ?? '').toString().trim();
      final city    = (loc['loc_city']    ?? '').toString().trim();
      final cityVal = cityEn.isNotEmpty ? cityEn : city;
      if (prefVal.isNotEmpty) {
        prefectures.add(prefVal);
        if (cityVal.isNotEmpty) {
          citiesByPref.putIfAbsent(prefVal, () => <String>{}).add(cityVal);
        }
      }
    }
    _prefectures  = prefectures.toList()..sort();
    _citiesByPref = citiesByPref.map((k, v) => MapEntry(k, v.toList()..sort()));
  }

  List<String> get _currentCities =>
      _draft.prefecture != null ? (_citiesByPref[_draft.prefecture] ?? []) : [];

  String? get _safeCity =>
      (_draft.city != null && _currentCities.contains(_draft.city)) ? _draft.city : null;

  String? get _safePref =>
      (_draft.prefecture != null && _prefectures.contains(_draft.prefecture))
          ? _draft.prefecture
          : null;

  _T   get _t    => widget.t;
  bool get _isJa => widget.lang == kLangJa;

  void _resetAndClose() =>
      Navigator.of(context, rootNavigator: false).pop(CourtFilter.defaultFilter);

  void _applyAndClose() =>
      Navigator.of(context, rootNavigator: false).pop(_draft);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 40,
                    offset: const Offset(0, -8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(_t.filterTitle,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: Color(0xFF0D0D0D), letterSpacing: -0.5)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context, rootNavigator: false).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.06),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: Colors.black.withOpacity(0.5)),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                Divider(height: 20, thickness: 1, color: Colors.black.withOpacity(0.06)),

                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        20, 4, 20, MediaQuery.of(context).padding.bottom + 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel(_t.setupType, Icons.construction_rounded),
                      const SizedBox(height: 10),
                      _multiSelectDropdown(
                        selected: _draft.setupTypes,
                        options: _setupTypes
                            .map((tp) => (
                        value: tp.$1,
                        label: _isJa ? tp.$3 : tp.$2,
                        ))
                            .toList(),
                        onChanged: (next) => setState(
                                () => _draft = _draft.copyWith(setupTypes: next)),
                      ),
                      const SizedBox(height: 20),

                      _sectionLabel(_t.courtSetting, Icons.roofing_rounded),
                      const SizedBox(height: 10),
                      Row(children: [
                        _settingChip(_t.all,     'all'),
                        const SizedBox(width: 8),
                        _settingChip(_t.indoor,  'indoor'),
                        const SizedBox(width: 8),
                        _settingChip(_t.outdoor, 'outdoor'),
                      ]),
                      const SizedBox(height: 20),

                      _sectionLabel(_t.prefecture, Icons.map_outlined),
                      const SizedBox(height: 10),
                      _buildDropdown(
                        value: _safePref, hint: _t.allPrefectures, items: _prefectures,
                        onChanged: (v) => setState(() =>
                        _draft = _draft.copyWith(prefecture: v, city: null)),
                      ),
                      const SizedBox(height: 20),

                      if (_currentCities.isNotEmpty) ...[
                        _sectionLabel(_t.city, Icons.location_city_rounded),
                        const SizedBox(height: 10),
                        _buildDropdown(
                          value: _safeCity, hint: _t.allCities, items: _currentCities,
                          onChanged: (v) => setState(() => _draft = _draft.copyWith(city: v)),
                        ),
                        const SizedBox(height: 20),
                      ],


                      _sectionLabel(_t.amenities, Icons.star_outline_rounded),
                      const SizedBox(height: 10),
                      _multiSelectDropdown(
                        selected: _draft.amenities,
                        options: _amenities
                            .map((a) => (
                        value: a.$3,
                        label: _isJa ? a.$2 : a.$1,
                        ))
                            .toList(),
                        onChanged: (next) => setState(
                                () => _draft = _draft.copyWith(amenities: next)),
                      ),
                      const SizedBox(height: 28),

                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _resetAndClose,
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(_t.resetFilters,
                                    style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w700,
                                        color: Colors.black.withOpacity(0.55))),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _applyAndClose,
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.35),
                                    blurRadius: 16, offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(_t.applyFilters,
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w800,
                                        color: Colors.white, letterSpacing: 0.2)),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) => Row(children: [
    Icon(icon, size: 15, color: AppColors.primary),
    const SizedBox(width: 6),
    Text(label,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: Color(0xFF0D0D0D), letterSpacing: 0.2)),
  ]);

  Widget _settingChip(String label, String value) {
    final selected = _draft.setting == value;
    return GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(setting: value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black.withOpacity(0.55))),
      ),
    );
  }

  Widget _setupChip(String label, String? value) {
    final selected = value == null
        ? _draft.setupTypes.isEmpty
        : _draft.setupTypes.contains(value);
    return GestureDetector(
      onTap: () => setState(() {
        if (value == null) {
          _draft = _draft.copyWith(setupTypes: <String>{});
        } else {
          final next = Set<String>.from(_draft.setupTypes);
          if (next.contains(value)) {
            next.remove(value);
          } else {
            next.add(value);
          }
          _draft = _draft.copyWith(setupTypes: next);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black.withOpacity(0.55))),
      ),
    );
  }


  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final uniqueItems = items.toSet().toList()..sort();
    final safeValue = (value != null && uniqueItems.contains(value)) ? value : null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: safeValue != null
              ? AppColors.primary.withOpacity(0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          hint: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(hint,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.38),
                    fontWeight: FontWeight.w500)),
          ),
          isExpanded: true,
          padding: const EdgeInsets.only(left: 14, right: 8),
          borderRadius: BorderRadius.circular(16),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 22),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint,
                  style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.4))),
            ),
            ...uniqueItems.map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0D0D0D))),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _multiSelectDropdown({
    required Set<String> selected,
    required List<({String value, String label})> options,
    required void Function(Set<String>) onChanged,
  }) {
    final allLabel = _isJa ? 'すべて' : 'All';
    String summary;
    if (selected.isEmpty) {
      summary = allLabel;
    } else if (selected.length == 1) {
      final only = selected.first;
      final match = options.where((o) => o.value == only).toList();
      summary = match.isNotEmpty ? match.first.label : '1 selected';
    } else {
      summary = _isJa ? '${selected.length}件選択中' : '${selected.length} selected';
    }
    final hasSelection = selected.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasSelection
              ? AppColors.primary.withOpacity(0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final result = await showModalBottomSheet<Set<String>>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (ctx) => _MultiSelectSheet(
                initialSelected: selected,
                options: options,
                isJa: _isJa,
              ),
            );
            if (result != null) onChanged(result);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Text(
                  summary,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: hasSelection
                        ? AppColors.primary
                        : Colors.black.withOpacity(0.45),
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary, size: 22),
            ]),
          ),
        ),
      ),
    );
  }

}


// ── Multi-select bottom sheet ────────────────────────────────────────────────
class _MultiSelectSheet extends StatefulWidget {
  final Set<String> initialSelected;
  final List<({String value, String label})> options;
  final bool isJa;

  const _MultiSelectSheet({
    required this.initialSelected,
    required this.options,
    required this.isJa,
  });

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late Set<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = Set<String>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final allLabel = widget.isJa ? 'すべて' : 'All';
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // "All" row -> clears selection
            InkWell(
              onTap: () => setState(() => _sel.clear()),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  _checkbox(_sel.isEmpty),
                  const SizedBox(width: 12),
                  Text(allLabel,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _sel.isEmpty
                              ? AppColors.primary
                              : Colors.black.withOpacity(0.7))),
                ]),
              ),
            ),
            Divider(height: 1, color: Colors.black.withOpacity(0.06)),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: widget.options.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.black.withOpacity(0.04)),
                itemBuilder: (ctx, i) {
                  final opt = widget.options[i];
                  final active = _sel.contains(opt.value);
                  return InkWell(
                    onTap: () => setState(() {
                      if (active) {
                        _sel.remove(opt.value);
                      } else {
                        _sel.add(opt.value);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(children: [
                        _checkbox(active),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(opt.label,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? AppColors.primary
                                      : Colors.black.withOpacity(0.75))),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: Colors.black.withOpacity(0.06)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).pop(_sel),
                  child: Text(widget.isJa ? '完了' : 'Done',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _checkbox(bool active) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withOpacity(0.15)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? AppColors.primary : Colors.black.withOpacity(0.18),
          width: 1.5,
        ),
      ),
      child: active
          ? Icon(Icons.check_rounded, size: 14, color: AppColors.primary)
          : null,
    );
  }
}
