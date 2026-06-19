import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:pikuru/providers/app_language_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// Translations
// ═══════════════════════════════════════════════════════════════════
const _T = {
  'en': {
    'appBarTitle':        'Add a Court',
    'step0':              'Basics',
    'step1':              'Location',
    'step2':              'Amenities',
    'step3':              'Hours',
    'step4':              'Review',
    // Page headers
    'basicTitle':         'Basic Information',
    'basicSub':           'Tell us about the court',
    'locationTitle':      'Location Details',
    'locationSub':        'Search or tap the map to set coordinates',
    'amenitiesTitle':     'Court Type & Amenities',
    'amenitiesSub':       'What does this venue offer?',
    'hoursTitle':         'Operating Hours',
    'hoursSub':           'When is the court open? Use semicolons for multiple ranges.',
    'hoursMon':           'Monday',
    'hoursTue':           'Tuesday',
    'hoursWed':           'Wednesday',
    'hoursThu':           'Thursday',
    'hoursFri':           'Friday',
    'hoursSat':           'Saturday',
    'hoursSun':           'Sunday',
    'hoursHint':          'e.g. 9:00-17:00 or 0:00-2:00; 6:00-23:59',
    'reviewTitle':        'Review & Submit',
    'reviewSub':          'Everything look good?',
    // Fields
    'courtName':          'Court Name *',
    'courtNameHint':      'e.g. Tokyo Pickleball Club',
    'locationType':       'Location Type',
    'numCourts':          'Number of Courts',
    'numCourtsHint':      'e.g. 4',
    'access':             'Access',
    'openPublic':         'Open to public',
    'requiresSetup':      'Requires setup',
    'coverPicture':       'Cover Picture',
    'selectImage':        'Select an Image',
    'selectImageSub':     'This will be used as the cover photo in listings.',
    'tapToChange':        'Tap to change',
    'googleMapsLink':     'Google Maps Link *',
    'googleMapsHint':     'https://www.google.com/maps/...',
    'latitude':           'Latitude',
    'longitude':          'Longitude',
    'address':            'Address',
    'addressHint':        'e.g. 1-1 Shibuya, Tokyo',
    'city':               'City',
    'cityHint':           'e.g. Shibuya',
    'prefecture':         'Prefecture',
    'prefectureHint':     'e.g. Tokyo',
    'country':            'Country',
    'website':            'Website',
    'websiteHint':        'https://example.com',
    'contactEmail':       'Contact Email',
    'contactEmailHint':   'contact@example.com',
    'courtType':          'Court Type *',
    'pricing':            'Pricing',
    'priceInfo':          'Price Info',
    'priceInfoHint':      'e.g. ¥4,000/hr',
    'courtsFree':         'Courts are Free',
    'amenities':          'Amenities',
    'dedicated':          'Dedicated Pickleball Court',
    'membership':         'Requires Membership',
    'openPlay':           'Open Play Available',
    'reservations':       'Reservations Required',
    'lessons':            'Lessons Available',
    'paddleRentals':      'Paddle Rentals',
    'additionalNotes':    'Additional Notes',
    'additionalNotesSub': 'e.g. "Open weekdays 9am–10pm, weekends 8am–8pm"',
    'coverPictureLabel':  'Cover Picture',
    'basicInfo':          'Basic Info',
    'location':           'Location',
    'courtPricing':       'Court & Pricing',
    'amenitiesLabel':     'Amenities',
    // Map
    'searchPlaceholder':  'Search for a court or place...',
    'tapMapHint':         'Tap the map to place a pin',
    'gettingAddress':     'Getting address...',
    'coordsAutofilled':   'Coordinates & address auto-filled. Edit below if needed.',
    'searchOrTap':        'Search above or tap the map to auto-fill all fields.',
    // Summary
    'name':               'Name',
    'type':               'Type',
    'courts':             'Courts',
    'courtTypeLabel':     'Court Type',
    'price':              'Price',
    'free':               'Free',
    'dedicatedRow':       'Dedicated Court',
    'membershipRow':      'Membership',
    'openPlayRow':        'Open Play',
    'reservationsRow':    'Reservations',
    'lessonsRow':         'Lessons',
    'paddleRentalsRow':   'Paddle Rentals',
    'uploadingImage':     'Uploading cover image...',
    'reviewDisclaimer':   'By submitting, you agree that this information will be reviewed by our team before appearing on the app.',
    // Bottom nav
    'back':               'Back',
    'continue':           'Continue',
    'saveBtn':            'SAVE COURT INFORMATION',
    // Snacks / dialogs
    'locationNotFound':   'Location not found.',
    'couldNotFind':       'Could not find',
    'locationDenied':     'Location permission denied.',
    'locationError':      'Could not get your location.',
    'imageUploadWarn':    'Could not upload image — saving court without it.',
    'validationError':    'Please fill out at least the Name, Google Map Link, and Court Type.',
    'submittedMsg':       'Court is under review. It will be added to our system within 48 hours',
    'submissionFailed':   'Submission failed — please try again.',
    // Amenity options
    'amenitySelect':      'Select...',
    'amenityYes':         'Yes',
    'amenityNo':          'No',
    'amenityUnknown':     'Unknown',
  },
  'ja': {
    'appBarTitle':        'コートを追加',
    'step0':              '基本情報',
    'step1':              '場所',
    'step2':              '設備',
    'step3':              '営業時間',
    'step4':              '確認',
    // Page headers
    'basicTitle':         '基本情報',
    'basicSub':           'コートについて教えてください',
    'locationTitle':      '場所の詳細',
    'locationSub':        '検索またはマップをタップして座標を設定',
    'amenitiesTitle':     'コートタイプと設備',
    'amenitiesSub':       'この施設が提供するものは？',
    'hoursTitle':         '営業時間',
    'hoursSub':           'コートはいつ利用できますか？複数の時間帯はセミコロンで区切ってください。',
    'hoursMon':           '月曜日',
    'hoursTue':           '火曜日',
    'hoursWed':           '水曜日',
    'hoursThu':           '木曜日',
    'hoursFri':           '金曜日',
    'hoursSat':           '土曜日',
    'hoursSun':           '日曜日',
    'hoursHint':          '例：9:00-17:00 または 0:00-2:00; 6:00-23:59',
    'reviewTitle':        '確認して送信',
    'reviewSub':          '内容を確認してください',
    // Fields
    'courtName':          'コート名 *',
    'courtNameHint':      '例：東京ピックルボールクラブ',
    'locationType':       '施設タイプ',
    'numCourts':          'コート数',
    'numCourtsHint':      '例：4',
    'access':             'アクセス',
    'openPublic':         '一般公開',
    'requiresSetup':      '要事前手配',
    'coverPicture':       'カバー写真',
    'selectImage':        '画像を選択',
    'selectImageSub':     'これが一覧表示のカバー写真として使用されます。',
    'tapToChange':        'タップして変更',
    'googleMapsLink':     'Googleマップリンク *',
    'googleMapsHint':     'https://www.google.com/maps/...',
    'latitude':           '緯度',
    'longitude':          '経度',
    'address':            '住所',
    'addressHint':        '例：東京都渋谷区1-1',
    'city':               '市区町村',
    'cityHint':           '例：渋谷',
    'prefecture':         '都道府県',
    'prefectureHint':     '例：東京都',
    'country':            '国',
    'website':            'ウェブサイト',
    'websiteHint':        'https://example.com',
    'contactEmail':       '連絡先メール',
    'contactEmailHint':   'contact@example.com',
    'courtType':          'コートタイプ *',
    'pricing':            '料金',
    'priceInfo':          '料金情報',
    'priceInfoHint':      '例：4,000円/時間',
    'courtsFree':         '無料コート',
    'amenities':          '設備・サービス',
    'dedicated':          '専用ピックルボールコート',
    'membership':         '会員制',
    'openPlay':           'オープンプレイあり',
    'reservations':       '要予約',
    'lessons':            'レッスンあり',
    'paddleRentals':      'パドルレンタル',
    'additionalNotes':    '備考',
    'additionalNotesSub': '例：「平日 9時〜22時、土日 8時〜20時営業」',
    'coverPictureLabel':  'カバー写真',
    'basicInfo':          '基本情報',
    'location':           '場所',
    'courtPricing':       'コートと料金',
    'amenitiesLabel':     '設備',
    // Map
    'searchPlaceholder':  'コートや場所を検索...',
    'tapMapHint':         'マップをタップしてピンを置く',
    'gettingAddress':     '住所を取得中...',
    'coordsAutofilled':   '座標と住所が自動入力されました。必要に応じて編集してください。',
    'searchOrTap':        '上で検索するかマップをタップしてすべてのフィールドを自動入力',
    // Summary
    'name':               '名前',
    'type':               'タイプ',
    'courts':             'コート数',
    'courtTypeLabel':     'コートタイプ',
    'price':              '料金',
    'free':               '無料',
    'dedicatedRow':       '専用コート',
    'membershipRow':      '会員制',
    'openPlayRow':        'オープンプレイ',
    'reservationsRow':    '予約',
    'lessonsRow':         'レッスン',
    'paddleRentalsRow':   'パドルレンタル',
    'uploadingImage':     'カバー画像をアップロード中...',
    'reviewDisclaimer':   '送信することで、アプリに表示される前にチームによって審査されることに同意します。',
    // Bottom nav
    'back':               '戻る',
    'continue':           '次へ',
    'saveBtn':            'コート情報を保存',
    // Snacks / dialogs
    'locationNotFound':   '場所が見つかりませんでした。',
    'couldNotFind':       '見つかりませんでした：',
    'locationDenied':     '位置情報の許可が拒否されました。',
    'locationError':      '現在地を取得できませんでした。',
    'imageUploadWarn':    '画像をアップロードできませんでした。画像なしで保存します。',
    'validationError':    '名前、Googleマップリンク、コートタイプを入力してください。',
    'submittedMsg':       'コートは審査中です。48時間以内にシステムに追加されます。',
    'submissionFailed':   '送信に失敗しました。もう一度お試しください。',
    // Amenity options
    'amenitySelect':      '選択...',
    'amenityYes':         'あり',
    'amenityNo':          'なし',
    'amenityUnknown':     '不明',
  },
};

String _t(String lang, String key) =>
    (_T[lang]?[key] ?? _T['en']![key]) ?? key;

class AddCourtScreen extends ConsumerStatefulWidget {
  const AddCourtScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddCourtScreen> createState() => _AddCourtScreenState();
}

class _AddCourtScreenState extends ConsumerState<AddCourtScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bg         = Color(0xFFF4FAF5);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _primary    = Color(0xFF2E7D4F);
  static const Color _accent     = Color(0xFF52B76E);
  static const Color _accentSoft = Color(0xFFD6EFD9);
  static const Color _textDark   = Color(0xFF1A2E1F);
  static const Color _textMid    = Color(0xFF4A6651);
  static const Color _textLight  = Color(0xFF8FB398);
  static const Color _border     = Color(0xFFCDE5D1);
  static const Color _errorBg    = Color(0xFFFFEEEE);
  static const Color _errorColor = Color(0xFFCC3333);

  // ── Map State ─────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  final LatLng _defaultCenter = const LatLng(35.6762, 139.6503);
  LatLng? _pickedLocation;
  Set<Marker> _markers        = {};
  bool _isReverseGeocoding    = false;
  bool _isSearchLoading       = false;
  bool _isLocating            = false;

  // ── Image State ───────────────────────────────────────────────────────────
  File? _pickedImage;
  bool  _isUploadingImage = false;

  // ── Form Controllers ──────────────────────────────────────────────────────
  late TextEditingController _nameController;
  late TextEditingController _courtCountController;
  late TextEditingController _addressEnController;
  late TextEditingController _cityEnController;
  late TextEditingController _prefectureEnController;
  late TextEditingController _countryController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _googlelinkController;
  late TextEditingController _websiteController;
  late TextEditingController _contactEmailController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;
  late TextEditingController _mapSearchController;
  late TextEditingController _hoursMonController;
  late TextEditingController _hoursTueController;
  late TextEditingController _hoursWedController;
  late TextEditingController _hoursThuController;
  late TextEditingController _hoursFriController;
  late TextEditingController _hoursSatController;
  late TextEditingController _hoursSunController;

  // ── Dropdown / toggle state ───────────────────────────────────────────────
  static const List<String> _locTypes = [
    'Arena', 'Professional Courts', 'Gym/Club', 'Gymnasium',
    'Public Court', 'Event Center', 'Resort/Hotel', 'School',
  ];
  String _locType = 'Gym/Club';

  static const List<String> _courtTypeValues = [
    'INDOOR COURTS', 'OUTDOOR COURTS', 'INDOOR/OUTDOOR COURTS',
  ];
  String _courtType = 'INDOOR COURTS';

  bool _isPublic    = true;
  bool _isPriceFree = false;

  String _dedicated     = '';
  String _membership    = '';
  String _openPlay      = '';
  String _reservations  = '';
  String _lessons       = '';
  String _paddleRentals = '';

  bool   _isLoading  = false;
  String _errorText  = '';

  // ── Init / Dispose ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pageController         = PageController();
    _nameController         = TextEditingController();
    _courtCountController   = TextEditingController();
    _addressEnController    = TextEditingController();
    _cityEnController       = TextEditingController();
    _prefectureEnController = TextEditingController(text: 'Tokyo');
    _countryController      = TextEditingController(text: 'Japan');
    _latController          = TextEditingController();
    _lngController          = TextEditingController();
    _googlelinkController   = TextEditingController();
    _websiteController      = TextEditingController();
    _contactEmailController = TextEditingController();
    _priceController        = TextEditingController();
    _notesController        = TextEditingController();
    _mapSearchController    = TextEditingController();
    _hoursMonController     = TextEditingController();
    _hoursTueController     = TextEditingController();
    _hoursWedController     = TextEditingController();
    _hoursThuController     = TextEditingController();
    _hoursFriController     = TextEditingController();
    _hoursSatController     = TextEditingController();
    _hoursSunController     = TextEditingController();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pageController.dispose();
    for (final c in [
      _nameController, _courtCountController,
      _addressEnController, _cityEnController, _prefectureEnController,
      _countryController, _latController, _lngController,
      _googlelinkController, _websiteController, _contactEmailController,
      _priceController, _notesController, _mapSearchController,
      _hoursMonController, _hoursTueController, _hoursWedController,
      _hoursThuController, _hoursFriController, _hoursSatController,
      _hoursSunController,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool _isJapanese(String text) =>
      RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]').hasMatch(text);

  List<String> _courtTypeLabels(String lang) => [
    lang == kLangJa ? '室内\nコート'  : 'INDOOR\nCOURTS',
    lang == kLangJa ? '屋外\nコート'  : 'OUTDOOR\nCOURTS',
    lang == kLangJa ? '室内/\n屋外'   : 'INDOOR/\nOUTDOOR',
  ];

  List<String> _amenityOpts(String lang) => [
    '',
    _t(lang, 'amenityYes'),
    _t(lang, 'amenityNo'),
    _t(lang, 'amenityUnknown'),
  ];

  // ── Claude translation helper ─────────────────────────────────────────────
  Future<String> _translate(String text, String toLang) async {
    if (text.trim().isEmpty) return '';
    try {
      const apiKey = 'YOUR_ACTUAL_API_KEY_HERE';
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type':      'application/json',
          'x-api-key':         apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model':      'claude-haiku-4-5-20251001',
          'max_tokens': 256,
          'messages': [
            {
              'role':    'user',
              'content': 'Translate the following text to $toLang. '
                  'Return ONLY the translated text with no explanation, '
                  'no quotes, and no extra punctuation.\n\n$text',
            }
          ],
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body    = jsonDecode(response.body) as Map<String, dynamic>;
        final content = body['content'] as List<dynamic>;
        if (content.isNotEmpty) {
          return (content.first['text'] as String? ?? '').trim();
        }
      }
    } catch (e) {
      debugPrint('[_translate] Exception: $e');
    }
    return '';
  }

  Future<({String en, String jp})> _resolveBilingual(String raw) async {
    if (raw.trim().isEmpty) return (en: '', jp: '');
    if (_isJapanese(raw)) {
      final en = await _translate(raw, 'English');
      return (en: en, jp: raw);
    } else {
      final jp = await _translate(raw, 'Japanese');
      return (en: raw, jp: jp);
    }
  }

  // ── Generate next loc_id ──────────────────────────────────────────────────
  Future<String> _generateNextLocId() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('locations').get();
      int maxNum = 0;
      for (final doc in snapshot.docs) {
        final locId = (doc.data()['loc_id'] ?? '').toString().trim();
        if (locId.startsWith('L-')) {
          final num = int.tryParse(locId.substring(2));
          if (num != null && num > maxNum) maxNum = num;
        }
      }
      return 'L-${(maxNum + 1).toString().padLeft(10, '0')}';
    } catch (_) {
      return 'L-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // ── Image picker ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  // ── Map helpers ───────────────────────────────────────────────────────────
  Future<void> _pinLocation(LatLng position) async {
    final lat = position.latitude.toStringAsFixed(6);
    final lng = position.longitude.toStringAsFixed(6);
    setState(() {
      _pickedLocation     = position;
      _isReverseGeocoding = true;
      _markers            = {
        Marker(
          markerId: const MarkerId('picked'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      };
      _latController.text        = lat;
      _lngController.text        = lng;
      _googlelinkController.text =
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    });
    await _reverseGeocode(position.latitude, position.longitude);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          final street = [p.subThoroughfare, p.thoroughfare]
              .where((s) => s != null && s!.isNotEmpty)
              .join(' ');
          if (street.isNotEmpty) _addressEnController.text = street;
          if ((p.locality ?? '').isNotEmpty) {
            _cityEnController.text = p.locality!;
          } else if ((p.subAdministrativeArea ?? '').isNotEmpty) {
            _cityEnController.text = p.subAdministrativeArea!;
          }
          if ((p.administrativeArea ?? '').isNotEmpty) {
            _prefectureEnController.text = p.administrativeArea!;
          }
          if ((p.country ?? '').isNotEmpty) {
            _countryController.text = p.country!;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  Future<void> _searchLocation(String lang, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSearchLoading = true);
    try {
      final locations = await locationFromAddress(trimmed);
      if (locations.isNotEmpty && mounted) {
        final best = locations.first;
        final pos  = LatLng(best.latitude, best.longitude);
        await _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(pos, 14));
        await Future.delayed(const Duration(milliseconds: 400));
        await _pinLocation(pos);
      } else {
        _showSnack(_t(lang, 'locationNotFound'), isError: true);
      }
    } catch (_) {
      if (mounted) {
        _showSnack(
            '${_t(lang, 'couldNotFind')} "$trimmed".', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  Future<void> _useMyLocation(String lang) async {
    setState(() => _isLocating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showSnack(_t(lang, 'locationDenied'), isError: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final latlng = LatLng(pos.latitude, pos.longitude);
      await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latlng, 16));
      await _pinLocation(latlng);
    } catch (_) {
      if (mounted) {
        _showSnack(_t(lang, 'locationError'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm(String lang) async {
    if (_nameController.text.trim().isEmpty ||
        _googlelinkController.text.trim().isEmpty ||
        _courtType.isEmpty) {
      setState(() => _errorText = _t(lang, 'validationError'));
      _pageController.animateToPage(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      return;
    }
    setState(() { _isLoading = true; _errorText = ''; });

    try {
      final newLocId = await _generateNextLocId();

      final rawName    = _nameController.text.trim();
      final rawAddress = _addressEnController.text.trim();

      final nameResult    = await _resolveBilingual(rawName);
      final addressResult = await _resolveBilingual(rawAddress);

      // ── Upload image ─────────────────────────────────────────────────────
      String imageUrl = '';
      if (_pickedImage != null) {
        setState(() => _isUploadingImage = true);
        try {
          final fileRef = FirebaseStorage.instance.ref(
              'court_images/${DateTime.now().millisecondsSinceEpoch}_'
                  '${_pickedImage!.path.split('/').last}');
          final snap = await fileRef
              .putFile(_pickedImage!)
              .timeout(const Duration(seconds: 30));
          imageUrl = await snap.ref.getDownloadURL();
        } catch (_) {
          if (mounted) {
            _showSnack(_t(lang, 'imageUploadWarn'), isError: false);
          }
        } finally {
          if (mounted) setState(() => _isUploadingImage = false);
        }
      }

      // ── Write to Firestore — mirrors web app field names exactly ─────────
      await FirebaseFirestore.instance.collection('locations').add({
        'loc_id':             newLocId,
        'loc_pending_review': true,
        'loc_active':         false,
        'loc_checked':        false,
        'loc_added':          FieldValue.serverTimestamp(),
        'loc_created_at':     DateTime.now().toIso8601String(),
        'loc_updated_at':     DateTime.now().toIso8601String(),
        'loc_org_id':         '',

        // Bilingual name — matches web: loc_name / loc_name_jp
        'loc_name':    nameResult.en,
        'loc_name_jp': nameResult.jp,

        'loc_type':        _locType,
        'loc_court_count': int.tryParse(_courtCountController.text) ?? 0,
        'loc_setup_type':  _isPublic ? 'Open to public' : 'Requires setup',

        // Bilingual address — matches web: loc_address / loc_address_jp
        'loc_address':    addressResult.en,
        'loc_address_jp': addressResult.jp,

        'loc_city_en':       _cityEnController.text.trim(),
        'loc_city_jp':       '',
        'loc_prefecture_en': _prefectureEnController.text.trim(),
        'loc_prefecture_jp': '',
        'loc_country':       _countryController.text.trim(),
        'loc_latitude':      _latController.text.trim(),
        'loc_longitude':     _lngController.text.trim(),
        'loc_googlelink':    _googlelinkController.text.trim(),
        'loc_website':       _websiteController.text.trim(),
        'loc_contact_email': _contactEmailController.text.trim(),

        'loc_court_type_indoor':
        _courtType == 'INDOOR COURTS' ||
            _courtType == 'INDOOR/OUTDOOR COURTS',
        'loc_court_type_outdoor':
        _courtType == 'OUTDOOR COURTS' ||
            _courtType == 'INDOOR/OUTDOOR COURTS',

        'loc_price':      _priceController.text.trim(),
        'loc_price_free': _isPriceFree,

        'loc_amenities_dedicated':     _dedicated,
        'loc_amenities_membership':    _membership,
        'loc_amenities_openplay':      _openPlay,
        'loc_amenities_reservation':   _reservations,
        'loc_amenities_lessons':       _lessons,
        'loc_amenities_paddlerentals': _paddleRentals,

        'loc_hours_mon':   _hoursMonController.text.trim(),
        'loc_hours_tues':  _hoursTueController.text.trim(),
        'loc_hours_weds':  _hoursWedController.text.trim(),
        'loc_hours_thurs': _hoursThuController.text.trim(),
        'loc_hours_fri':   _hoursFriController.text.trim(),
        'loc_hours_sat':   _hoursSatController.text.trim(),
        'loc_hours_sun':   _hoursSunController.text.trim(),
        'loc_hours_notes': '',

        'loc_notes': _notesController.text.trim(),
        'loc_image': imageUrl.isNotEmpty ? imageUrl : null,
      });

      if (mounted) {
        _showSnack(_t(lang, 'submittedMsg'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Error: $e');
        _showSnack(_t(lang, 'submissionFailed'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.red.shade400 : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    final stepLabels = [
      _t(lang, 'step0'), _t(lang, 'step1'), _t(lang, 'step2'),
      _t(lang, 'step3'), _t(lang, 'step4'),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: _primary.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: _textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          Text(_t(lang, 'appBarTitle'),
              style: const TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5)),
          Text(stepLabels[_currentPage],
              style: const TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w500,
                  fontSize: 12)),
        ]),
        centerTitle: true,
      ),
      body: Column(children: [
        _buildStepIndicator(stepLabels),
        if (_errorText.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _errorBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _errorColor.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.error_outline, color: _errorColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_errorText,
                    style: const TextStyle(
                        color: _errorColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                onTap: () => setState(() => _errorText = ''),
                child: const Icon(Icons.close, color: _errorColor, size: 16),
              ),
            ]),
          ),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildBasicInfoPage(lang),
              _buildLocationPage(lang),
              _buildAmenitiesPage(lang),
              _buildHoursPage(lang),
              _buildSummaryPage(lang),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(lang),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator(List<String> stepLabels) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(stepLabels.length, (i) {
          final active = i <= _currentPage;
          return Expanded(
            child: Row(children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? _accent : _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < stepLabels.length - 1) const SizedBox(width: 4),
            ]),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 1 — Basic Info
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBasicInfoPage(String lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _t(lang, 'basicTitle'), _t(lang, 'basicSub'),
            Icons.sports_tennis),

        _buildTextField(
            label: _t(lang, 'courtName'),
            controller: _nameController,
            hint: _t(lang, 'courtNameHint')),
        const SizedBox(height: 14),

        _buildLabel(_t(lang, 'locationType')),
        const SizedBox(height: 6),
        _buildDropdown<String>(
          value: _locType,
          items: _locTypes,
          itemLabel: (v) => v,
          onChanged: (v) => setState(() => _locType = v ?? _locType),
        ),
        const SizedBox(height: 14),

        _buildTextField(
            label: _t(lang, 'numCourts'),
            controller: _courtCountController,
            hint: _t(lang, 'numCourtsHint'),
            keyboardType: TextInputType.number),
        const SizedBox(height: 20),

        _buildLabel(_t(lang, 'access')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildToggleButton(
            label: _t(lang, 'openPublic'),
            selected: _isPublic,
            onTap: () => setState(() => _isPublic = true),
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildToggleButton(
            label: _t(lang, 'requiresSetup'),
            selected: !_isPublic,
            onTap: () => setState(() => _isPublic = false),
          )),
        ]),
        const SizedBox(height: 24),

        _buildLabel(_t(lang, 'coverPicture')),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: _pickedImage != null ? 200 : 140,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _pickedImage != null ? _accent : _border,
                width: _pickedImage != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                    color: _primary.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: _pickedImage != null
                ? Stack(fit: StackFit.expand, children: [
              Image.file(_pickedImage!, fit: BoxFit.cover),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.black.withOpacity(0.45),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(_t(lang, 'tapToChange'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ])
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(
                      color: _textDark, shape: BoxShape.circle),
                  child: const Icon(Icons.add,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(height: 12),
                Text(_t(lang, 'selectImage'),
                    style: const TextStyle(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _t(lang, 'selectImageSub'),
                    style: const TextStyle(
                        color: _textLight, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 2 — Location
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLocationPage(String lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _t(lang, 'locationTitle'), _t(lang, 'locationSub'),
            Icons.place_outlined),

        Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _primary.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4))
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition:
              CameraPosition(target: _defaultCenter, zoom: 12),
              onMapCreated: (c) => _mapController = c,
              onTap: _pinLocation,
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

            // Search bar
            Positioned(
              top: 12, left: 12, right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: TextField(
                  controller: _mapSearchController,
                  style: const TextStyle(
                      color: _textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) => _searchLocation(lang, q),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _t(lang, 'searchPlaceholder'),
                    hintStyle:
                    const TextStyle(color: _textLight, fontSize: 13),
                    prefixIcon: _isSearchLoading
                        ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation(_accent)),
                      ),
                    )
                        : const Icon(Icons.search_rounded,
                        color: _accent, size: 20),
                    suffixIcon: _mapSearchController.text.isNotEmpty &&
                        !_isSearchLoading
                        ? IconButton(
                      icon: const Icon(Icons.close,
                          color: _textLight, size: 18),
                      onPressed: () {
                        _mapSearchController.clear();
                        setState(() {});
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Use my location
            Positioned(
              top: 72, right: 12,
              child: GestureDetector(
                onTap: _isLocating ? null : () => _useMyLocation(lang),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8)
                    ],
                  ),
                  child: _isLocating
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_accent)))
                      : const Icon(Icons.my_location_rounded,
                      color: _primary, size: 20),
                ),
              ),
            ),

            // Tap hint
            if (_pickedLocation == null && !_isSearchLoading)
              Positioned(
                bottom: 12, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _textDark.withOpacity(0.82),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_rounded,
                            color: _accent, size: 16),
                        const SizedBox(width: 6),
                        Text(_t(lang, 'tapMapHint'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),

            // Reverse geocoding spinner
            if (_isReverseGeocoding)
              Positioned(
                bottom: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8)
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_accent)),
                    ),
                    const SizedBox(width: 8),
                    Text(_t(lang, 'gettingAddress'),
                        style: const TextStyle(
                            color: _textMid,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
          ]),
        ),

        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(
              _pickedLocation != null
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 16, color: _primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _pickedLocation != null
                    ? _t(lang, 'coordsAutofilled')
                    : _t(lang, 'searchOrTap'),
                style: const TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),
        _buildTextField(
            label: _t(lang, 'googleMapsLink'),
            controller: _googlelinkController,
            hint: _t(lang, 'googleMapsHint')),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _buildTextField(
              label: _t(lang, 'latitude'),
              controller: _latController,
              hint: '35.6762',
              keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(
              label: _t(lang, 'longitude'),
              controller: _lngController,
              hint: '139.6503',
              keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 14),
        _buildTextField(
            label: _t(lang, 'address'),
            controller: _addressEnController,
            hint: _t(lang, 'addressHint')),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _buildTextField(
              label: _t(lang, 'city'),
              controller: _cityEnController,
              hint: _t(lang, 'cityHint'))),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(
              label: _t(lang, 'prefecture'),
              controller: _prefectureEnController,
              hint: _t(lang, 'prefectureHint'))),
        ]),
        const SizedBox(height: 14),
        _buildTextField(
            label: _t(lang, 'country'),
            controller: _countryController,
            hint: 'Japan'),
        const SizedBox(height: 14),
        _buildTextField(
            label: _t(lang, 'website'),
            controller: _websiteController,
            hint: _t(lang, 'websiteHint')),
        const SizedBox(height: 14),
        _buildTextField(
            label: _t(lang, 'contactEmail'),
            controller: _contactEmailController,
            hint: _t(lang, 'contactEmailHint')),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 3 — Amenities
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAmenitiesPage(String lang) {
    final ctLabels = _courtTypeLabels(lang);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _t(lang, 'amenitiesTitle'), _t(lang, 'amenitiesSub'),
            Icons.star_outline),

        _buildLabel(_t(lang, 'courtType')),
        const SizedBox(height: 10),
        Row(
          children: List.generate(3, (i) {
            final isSelected = _courtType == _courtTypeValues[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _courtType = _courtTypeValues[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : _surface,
                    border: Border.all(
                      color: isSelected ? _primary : _border,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                          color: _primary.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                        : [
                      BoxShadow(
                          color: _primary.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(
                    ctLabels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        _buildLabel(_t(lang, 'pricing')),
        const SizedBox(height: 10),
        _buildTextField(
            label: _t(lang, 'priceInfo'),
            controller: _priceController,
            hint: _t(lang, 'priceInfoHint')),
        const SizedBox(height: 12),
        _buildToggleCheckbox(
            label: _t(lang, 'courtsFree'),
            value: _isPriceFree,
            onChanged: (v) => setState(() => _isPriceFree = v)),
        const SizedBox(height: 24),

        _buildLabel(_t(lang, 'amenities')),
        const SizedBox(height: 12),
        _buildAmenityRow(
            label: _t(lang, 'dedicated'),
            value: _dedicated,
            lang: lang,
            onChanged: (v) => setState(() => _dedicated = v ?? '')),
        const SizedBox(height: 12),
        _buildAmenityRow(
            label: _t(lang, 'membership'),
            value: _membership,
            lang: lang,
            onChanged: (v) => setState(() => _membership = v ?? '')),
        const SizedBox(height: 12),
        _buildAmenityRow(
            label: _t(lang, 'openPlay'),
            value: _openPlay,
            lang: lang,
            onChanged: (v) => setState(() => _openPlay = v ?? '')),
        const SizedBox(height: 12),
        _buildAmenityRow(
            label: _t(lang, 'reservations'),
            value: _reservations,
            lang: lang,
            onChanged: (v) => setState(() => _reservations = v ?? '')),
        const SizedBox(height: 12),
        _buildAmenityRow(
            label: _t(lang, 'lessons'),
            value: _lessons,
            lang: lang,
            onChanged: (v) => setState(() => _lessons = v ?? '')),
        const SizedBox(height: 12),
        _buildAmenityRow(
            label: _t(lang, 'paddleRentals'),
            value: _paddleRentals,
            lang: lang,
            onChanged: (v) => setState(() => _paddleRentals = v ?? '')),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 4 — Hours
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHoursPage(String lang) {
    final hint = _t(lang, 'hoursHint');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(_t(lang, 'hoursTitle'), _t(lang, 'hoursSub'),
            Icons.schedule_outlined),
        _buildTextField(label: _t(lang, 'hoursMon'), controller: _hoursMonController, hint: hint),
        _buildTextField(label: _t(lang, 'hoursTue'), controller: _hoursTueController, hint: hint),
        _buildTextField(label: _t(lang, 'hoursWed'), controller: _hoursWedController, hint: hint),
        _buildTextField(label: _t(lang, 'hoursThu'), controller: _hoursThuController, hint: hint),
        _buildTextField(label: _t(lang, 'hoursFri'), controller: _hoursFriController, hint: hint),
        _buildTextField(label: _t(lang, 'hoursSat'), controller: _hoursSatController, hint: hint),
        _buildTextField(label: _t(lang, 'hoursSun'), controller: _hoursSunController, hint: hint),
        _buildTextField(
            label: _t(lang, 'additionalNotes'),
            controller: _notesController,
            hint: _t(lang, 'additionalNotesSub'),
            maxLines: 4),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAGE 5 — Review & Submit
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSummaryPage(String lang) {
    String amenityDisplay(String v) => v.isEmpty ? '—' : v;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _t(lang, 'reviewTitle'), _t(lang, 'reviewSub'),
            Icons.check_circle_outline),

        if (_pickedImage != null) ...[
          _buildLabel(_t(lang, 'coverPictureLabel')),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(_pickedImage!,
                width: double.infinity, height: 140, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
        ],

        _buildSummarySection(_t(lang, 'basicInfo'), [
          (_t(lang, 'name'),   _nameController.text.isEmpty ? '—' : _nameController.text),
          (_t(lang, 'type'),   _locType),
          (_t(lang, 'courts'), _courtCountController.text.isEmpty ? '—' : _courtCountController.text),
          (_t(lang, 'access'), _isPublic ? _t(lang, 'openPublic') : _t(lang, 'requiresSetup')),
        ]),
        const SizedBox(height: 12),

        _buildSummarySection(_t(lang, 'location'), [
          (_t(lang, 'latitude'),   _latController.text.isEmpty ? '—' : _latController.text),
          (_t(lang, 'longitude'),  _lngController.text.isEmpty ? '—' : _lngController.text),
          (_t(lang, 'city'),       _cityEnController.text.isEmpty ? '—' : _cityEnController.text),
          (_t(lang, 'prefecture'), _prefectureEnController.text.isEmpty ? '—' : _prefectureEnController.text),
          (_t(lang, 'country'),    _countryController.text.isEmpty ? '—' : _countryController.text),
        ]),
        const SizedBox(height: 12),

        _buildSummarySection(_t(lang, 'courtPricing'), [
          (_t(lang, 'courtTypeLabel'), _courtType),
          (_t(lang, 'price'), _isPriceFree
              ? _t(lang, 'free')
              : (_priceController.text.isEmpty ? '—' : _priceController.text)),
        ]),
        const SizedBox(height: 12),

        _buildSummarySection(_t(lang, 'amenitiesLabel'), [
          (_t(lang, 'dedicatedRow'),    amenityDisplay(_dedicated)),
          (_t(lang, 'membershipRow'),   amenityDisplay(_membership)),
          (_t(lang, 'openPlayRow'),     amenityDisplay(_openPlay)),
          (_t(lang, 'reservationsRow'), amenityDisplay(_reservations)),
          (_t(lang, 'lessonsRow'),      amenityDisplay(_lessons)),
          (_t(lang, 'paddleRentalsRow'),amenityDisplay(_paddleRentals)),
        ]),
        const SizedBox(height: 24),

        if (_isUploadingImage) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_primary)),
              ),
              const SizedBox(width: 12),
              Text(_t(lang, 'uploadingImage'),
                  style: const TextStyle(
                      color: _primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(16)),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: _primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t(lang, 'reviewDisclaimer'),
                    style: const TextStyle(
                        color: _textMid, fontSize: 13, height: 1.5),
                  ),
                ),
              ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM NAV
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav(String lang) {
    return Container(
      color: _surface,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 20, right: 20, top: 16,
      ),
      child: Row(children: [
        if (_currentPage > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_t(lang, 'back'),
                  style: const TextStyle(
                      color: _textMid,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
              if (_currentPage == 4) {
                _submitForm(lang);
              } else {
                _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _accent.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Text(
              _currentPage == 4
                  ? _t(lang, 'saveBtn')
                  : _t(lang, 'continue'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
        ),
      ]),
    );
  }
// ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPageHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: _primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: _textLight, fontSize: 12)),
              ]),
        ),
      ]),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
        color: _textMid,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2),
  );

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildLabel(label),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
            color: _textDark, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textLight, fontSize: 14),
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent, width: 1.5)),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    ]);
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: _surface,
          style: const TextStyle(
              color: _textDark, fontSize: 14, fontWeight: FontWeight.w500),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _textLight, size: 20),
          items: items
              .map((v) => DropdownMenuItem<T>(
            value: v,
            child: Text(itemLabel(v)),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAmenityRow({
    required String label,
    required String value,
    required String lang,
    required ValueChanged<String?> onChanged,
  }) {
    final opts = _amenityOpts(lang);

    // Map stored English value → localised display value for dropdown
    String displayValue = '';
    if (value == 'Yes') {
      displayValue = _t(lang, 'amenityYes');
    } else if (value == 'No') {
      displayValue = _t(lang, 'amenityNo');
    } else if (value == 'Unknown') {
      displayValue = _t(lang, 'amenityUnknown');
    }

    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: value.isNotEmpty ? _accent : _border, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: displayValue,
              dropdownColor: _surface,
              style: TextStyle(
                  color: value.isNotEmpty ? _primary : _textLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _textLight, size: 16),
              items: opts
                  .map((o) => DropdownMenuItem<String>(
                value: o,
                child: Text(
                  o.isEmpty ? _t(lang, 'amenitySelect') : o,
                  style: TextStyle(
                      color: o.isEmpty ? _textLight : _textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ))
                  .toList(),
              onChanged: (localised) {
                // Always persist English values to Firestore (matches web app)
                if (localised == null || localised.isEmpty) {
                  onChanged('');
                } else if (localised == _t(lang, 'amenityYes')) {
                  onChanged('Yes');
                } else if (localised == _t(lang, 'amenityNo')) {
                  onChanged('No');
                } else if (localised == _t(lang, 'amenityUnknown')) {
                  onChanged('Unknown');
                } else {
                  onChanged(localised);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _accentSoft : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _accent : _border,
              width: selected ? 1.5 : 1),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? _primary : _textMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildToggleCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? _accentSoft : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value ? _accent : _border,
              width: value ? 1.5 : 1),
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? _primary : Colors.transparent,
              border:
              Border.all(color: value ? _primary : _border, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: value
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: value ? _textDark : _textMid,
                    fontSize: 14,
                    fontWeight:
                    value ? FontWeight.w600 : FontWeight.w500)),
          ),
        ]),
      ),
    );
  }

  Widget _buildSummarySection(
      String title, List<(String, String)> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: _primary.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(
                  color: _accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ),
        const Divider(height: 1, color: _border),
        ...rows.map((r) => Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.$1,
                    style: const TextStyle(
                        color: _textLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(r.$2,
                      style: const TextStyle(
                          color: _textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.end),
                ),
              ]),
        )),
      ]),
    );
  }
}