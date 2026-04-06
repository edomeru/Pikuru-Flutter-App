import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

// ─────────────────────────────────────────────────────────────────────────────
// pubspec.yaml dependencies:
//   cloud_firestore: ^4.x.x
//   firebase_storage: ^11.x.x
//   image_picker: ^1.x.x
//   flutter_riverpod: ^2.x.x
//   google_maps_flutter: ^2.x.x
//   geocoding: ^3.x.x
//
// AndroidManifest.xml — inside <application>:
//   <meta-data android:name="com.google.android.geo.API_KEY"
//              android:value="YOUR_API_KEY"/>
//
// iOS AppDelegate.swift — before GeneratedPluginRegistrant:
//   GMSServices.provideAPIKey("YOUR_API_KEY")
// ─────────────────────────────────────────────────────────────────────────────

// ── Detect Japanese characters ────────────────────────────────────────────────
bool _isJapanese(String text) =>
    RegExp(r'[\u3040-\u30FF\u4E00-\u9FFF\uFF65-\uFF9F]').hasMatch(text);

// ── Google Translate (free public endpoint) ───────────────────────────────────
Future<String> _translateText(String text, String targetLang) async {
  if (text.trim().isEmpty) return text;
  try {
    final uri = Uri.parse(
      'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=auto&tl=$targetLang&dt=t'
          '&q=${Uri.encodeComponent(text)}',
    );
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();
    final raw = await response.transform(const Utf8Decoder()).join();
    // Parse [[["translated","original"],...],...]
    final decoded = jsonDecode(raw) as List;
    final parts = (decoded[0] as List)
        .map((item) => (item as List).first?.toString() ?? '')
        .join();
    return parts;
  } catch (_) {
    return text;
  }
}

class AddEventScreen extends ConsumerStatefulWidget {
  const AddEventScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends ConsumerState<AddEventScreen> {
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
  static const Color _errorRed   = Color(0xFFE53935);

  final List<String> _stepLabels = ['Details', 'Schedule', 'Divisions', 'Venue', 'Media'];

  // ── Controllers ───────────────────────────────────────────────────────────
  late TextEditingController _titleController;
  late TextEditingController _linkController;
  late TextEditingController _feeController;
  late TextEditingController _maxParticipantsController;
  late TextEditingController _contactController;
  late TextEditingController _descController;
  late TextEditingController _startTimeController;
  late TextEditingController _venueNameController;
  late TextEditingController _venueAddressController;
  late TextEditingController _venueMapLinkController;
  late TextEditingController _orgNameController;
  late TextEditingController _mapSearchController;

  // ── Map state ─────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng _mapCenter = const LatLng(35.6895, 139.6917);
  LatLng? _markerPos;
  bool   _searchLoading = false;
  Timer? _searchDebounce;

  // ── Form state ────────────────────────────────────────────────────────────
  String    _eventType      = 'Open Play';
  DateTime? _eventDate;
  DateTime? _eventDateEnd;
  bool _acceptStripe    = false;
  bool _touristFriendly = false;
  bool _skillBeginner   = false;
  bool _skillAmateur    = false;
  bool _skillPro        = false;
  bool _catMensSingles   = false;
  bool _catWomensSingles = false;
  bool _catMensDoubles   = false;
  bool _catWomensDoubles = false;
  bool _catMixedDoubles  = false;
  bool _catJuniors       = false;
  bool _catCollegiate    = false;
  bool _catSeniors       = false;

  File? _imageFile;
  bool  _isLoading = false;

  static const List<String> _eventTypes = [
    'Professional Tournament',
    'Global Tournament',
    'Japan Tournament',
    'Open Play',
    'Trial Session',
    'Local Event',
    'Lessons/Clinics',
    'Weekly Play / Recurring Play',
  ];

  @override
  void initState() {
    super.initState();
    _pageController            = PageController();
    _titleController           = TextEditingController();
    _linkController            = TextEditingController();
    _feeController             = TextEditingController();
    _maxParticipantsController = TextEditingController();
    _contactController         = TextEditingController();
    _descController            = TextEditingController();
    _startTimeController       = TextEditingController();
    _venueNameController       = TextEditingController();
    _venueAddressController    = TextEditingController();
    _venueMapLinkController    = TextEditingController();
    _orgNameController         = TextEditingController();
    _mapSearchController       = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapController?.dispose();
    _searchDebounce?.cancel();
    for (final c in [
      _titleController, _linkController, _feeController, _maxParticipantsController,
      _contactController, _descController, _startTimeController,
      _venueNameController, _venueAddressController, _venueMapLinkController,
      _orgNameController, _mapSearchController,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Map: tap → reverse geocode → fill fields ──────────────────────────────
  Future<void> _onMapTap(LatLng pos) async {
    setState(() => _markerPos = pos);
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
    await _fillFromLatLng(pos);
  }

  Future<void> _fillFromLatLng(LatLng pos) async {
    final mapsLink =
        'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
    setState(() => _venueMapLinkController.text = mapsLink);
    try {
      final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.locality, p.administrativeArea, p.country]
            .where((s) => s != null && s.isNotEmpty)
            .toList();

        // A valid place name must:
        //  • be non-empty
        //  • not be purely numeric (e.g. "13", "1-13")
        //  • not equal the street value (geocoder sometimes copies it)
        //  • not be a leading numeric prefix of the street (house number)
        final rawName  = p.name?.trim() ?? '';
        final street   = p.street?.trim() ?? '';
        final isNumeric = RegExp(r'^[\d\-‐–—/\s]+$').hasMatch(rawName);
        final isStreetPrefix = street.isNotEmpty &&
            street.startsWith(rawName) &&
            rawName.length <= street.length;
        final isValidName = rawName.isNotEmpty &&
            !isNumeric &&
            rawName != street &&
            !isStreetPrefix;

        setState(() {
          _venueAddressController.text = parts.join(', ');
          // Only overwrite if field is empty AND we have a real place name
          if (_venueNameController.text.isEmpty && isValidName) {
            _venueNameController.text = rawName;
          }
        });
      }
    } catch (_) {}
  }

  // ── Map: search bar ───────────────────────────────────────────────────────
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 600),
          () => _searchPlace(query),
    );
  }

  Future<void> _searchPlace(String query) async {
    if (!mounted) return;
    setState(() => _searchLoading = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty && mounted) {
        final loc = locations.first;
        final pos = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _markerPos    = pos;
          _mapCenter    = pos;
          _searchLoading = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
        await _fillFromLatLng(pos);
        _mapSearchController.clear();
        FocusManager.instance.primaryFocus?.unfocus();
      } else {
        if (mounted) setState(() => _searchLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  // ── Pick image ────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _imageFile = File(picked.path));
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    final title   = _titleController.text.trim();
    final address = _venueAddressController.text.trim();
    final contact = _contactController.text.trim();
    final desc    = _descController.text.trim();

    if (title.isEmpty || _eventDate == null || address.isEmpty || contact.isEmpty) {
      _showSnack('Please fill in Title, Date, Address, and Contact Email.',
          isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      // ── Image upload ──────────────────────────────────────────────────────
      String imageUrl = '';
      if (_imageFile != null) {
        try {
          final storageRef = FirebaseStorage.instance.ref(
              'event_images/${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}');
          final uploadTask = storageRef.putFile(_imageFile!);
          final snapshot = await uploadTask.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              uploadTask.cancel();
              throw TimeoutException('timeout');
            },
          );
          imageUrl = await snapshot.ref.getDownloadURL();
        } catch (_) {
          if (mounted) {
            _showSnack('Could not upload image — saving without it.',
                isError: false);
          }
        }
      }

      // ── Bilingual title ───────────────────────────────────────────────────
      String titleEn;
      String titleJp;
      if (_isJapanese(title)) {
        // Input is Japanese → keep as JP, translate to EN
        titleJp = title;
        titleEn = await _translateText(title, 'en');
      } else {
        // Input is English (or other) → keep as EN, translate to JP
        titleEn = title;
        titleJp = await _translateText(title, 'ja');
      }

      // ── Bilingual description ─────────────────────────────────────────────
      String descEn;
      String descJp;
      if (_isJapanese(desc)) {
        // Input is Japanese → keep as JP, translate to EN
        descJp = desc;
        descEn = await _translateText(desc, 'en');
      } else {
        // Input is English (or other) → keep as EN, translate to JP
        descEn = desc;
        descJp = await _translateText(desc, 'ja');
      }

      // ── Timestamps ────────────────────────────────────────────────────────
      final eventDateTs    = Timestamp.fromDate(_eventDate!);
      final eventDateEndTs =
      _eventDateEnd != null ? Timestamp.fromDate(_eventDateEnd!) : null;

      Timestamp? startTs;
      final timeStr = _startTimeController.text.trim();
      if (timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          startTs = Timestamp.fromDate(DateTime(
            _eventDate!.year, _eventDate!.month, _eventDate!.day,
            int.tryParse(parts[0]) ?? 0,
            int.tryParse(parts[1]) ?? 0,
          ));
        }
      }

      await FirebaseFirestore.instance.collection('events').add({
        // Review flags
        'event_pending_review': true,
        'event_checked':        false,
        'event_active':         false,
        'event_status':         false,

        // Timestamps
        'event_added':   FieldValue.serverTimestamp(),
        'event_created': FieldValue.serverTimestamp(),
        'event_updated': FieldValue.serverTimestamp(),

        // Title (bilingual)
        'event_title':    titleEn,
        'event_title_en': titleEn,
        'event_title_jp': titleJp,

        // Basic
        'event_type': _eventType,
        'event_link': _linkController.text.trim(),

        // Schedule
        'event_date':       eventDateTs,
        'event_date_end':   eventDateEndTs,
        'event_time':       startTs,
        'event_start_date': startTs,
        'event_fee':        _feeController.text.trim(),
        'event_limit':      _maxParticipantsController.text.trim().isNotEmpty
            ? int.tryParse(_maxParticipantsController.text.trim())
            : null,
        'event_stripe_setup': _acceptStripe,

        // Skill
        'event_skill_level_beginner': _skillBeginner,
        'event_skill_level_amateur':  _skillAmateur,
        'event_skill_level_pro':      _skillPro,

        // Categories
        'event_category_menssingle':    _catMensSingles,
        'event_category_womenssingle':  _catWomensSingles,
        'event_category_mensdoubles':   _catMensDoubles,
        'event_category_womensdoubles': _catWomensDoubles,
        'event_category_mixeddoubles':  _catMixedDoubles,
        'event_category_juniors':       _catJuniors,
        'event_category_collegiate':    _catCollegiate,
        'event_category_seniors':       _catSeniors,

        'event_touristfriendly': _touristFriendly,

        // Venue
        'event_venue_name':    _venueNameController.text.trim(),
        'event_venue_address': address,
        'event_venue_link':    _venueMapLinkController.text.trim(),
        'event_org_name':      _orgNameController.text.trim(),
        'event_loc_id':        '',
        'event_org_id':        '',

        // Contact & description (bilingual)
        'event_contact':         contact,
        'event_description_en':  descEn,
        'event_description_jp':  descJp,

        // Media
        'event_pic':           imageUrl,
        'event_pic_thumbnail': imageUrl,

        // Submitter — replace with FirebaseAuth.instance.currentUser?.uid ?? ''
        'event_addedby': '',
        'submittedBy':   '',
      });

      if (mounted) {
        _showSnack('Event submitted for review!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _errorRed : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
              boxShadow: [BoxShadow(
                  color: _primary.withOpacity(0.08),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          const Text('Add an Event',
              style: TextStyle(
                  color: _textDark, fontWeight: FontWeight.w800,
                  fontSize: 18, letterSpacing: -0.5)),
          Text(_stepLabels[_currentPage],
              style: const TextStyle(
                  color: _accent, fontWeight: FontWeight.w500, fontSize: 12)),
        ]),
        centerTitle: true,
      ),
      body: Column(children: [
        _buildStepIndicator(),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildDetailsPage(),
              _buildSchedulePage(),
              _buildDivisionsPage(),
              _buildVenuePage(),
              _buildMediaPage(),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(_stepLabels.length, (i) {
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
              if (i < _stepLabels.length - 1) const SizedBox(width: 4),
            ]),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 1 – Basic Details
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            'Basic Details', 'Title, type & registration link', Icons.info_outline),

        _buildTextField(
          label: 'Event Name *',
          controller: _titleController,
          hint: 'e.g. UTR Pickleball Japan Tour 2026',
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.translate_rounded, size: 13, color: _textLight),
          const SizedBox(width: 5),
          const Text('Auto-translated to both EN & JP on submit',
              style: TextStyle(color: _textLight, fontSize: 11)),
        ]),
        const SizedBox(height: 14),

        _buildLabel('Event Type *'),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _eventType,
          items: _eventTypes,
          onChanged: (v) => setState(() => _eventType = v!),
          labelBuilder: (v) => v,
        ),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Registration / Event Link',
          controller: _linkController,
          hint: 'https://',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _accentSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 16, color: _primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Submitted events go through a review process and will be '
                    'visible within 48 hours of approval.',
                style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 2 – Schedule & Fees
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSchedulePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            'Schedule & Fees', 'Date, time and entry fee', Icons.calendar_today_outlined),

        _buildLabel('Date of Event *'),
        const SizedBox(height: 6),
        _buildDatePicker(
          value: _eventDate,
          hint: 'Select event date',
          onPicked: (d) => setState(() => _eventDate = d),
        ),
        const SizedBox(height: 14),

        _buildLabel('End Date (Optional)'),
        const SizedBox(height: 6),
        _buildDatePicker(
          value: _eventDateEnd,
          hint: 'Select end date',
          onPicked: (d) => setState(() => _eventDateEnd = d),
        ),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Start Time (e.g. 09:00)',
          controller: _startTimeController,
          hint: '09:00',
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: 14),

        Row(children: [
          Expanded(child: _buildTextField(
            label: 'Fee (e.g. Free, ¥2000)',
            controller: _feeController,
            hint: '¥2,000',
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(
            label: 'Max Participants',
            controller: _maxParticipantsController,
            hint: 'e.g. 64',
            keyboardType: TextInputType.number,
          )),
        ]),
        const SizedBox(height: 20),

        _buildSectionCard(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Accept payment through Pikuru App?',
                  style: TextStyle(
                      color: _textDark, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [
                _buildRadioOption('Yes', true, _acceptStripe,
                        (v) => setState(() => _acceptStripe = v)),
                const SizedBox(width: 24),
                _buildRadioOption('No', false, _acceptStripe,
                        (v) => setState(() => _acceptStripe = v)),
              ]),
              const SizedBox(height: 8),
              const Text(
                '*Stripe fees plus a ¥100 fee per participant will apply.',
                style: TextStyle(
                    color: _textLight, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 3 – Divisions & Levels
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDivisionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            'Divisions & Levels', 'Who can participate?', Icons.emoji_events_outlined),

        _buildLabel('Skill Level'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildSkillChip('Beginner', _skillBeginner,
                  (v) => setState(() => _skillBeginner = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip('Amateur', _skillAmateur,
                  (v) => setState(() => _skillAmateur = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip('Pro', _skillPro,
                  (v) => setState(() => _skillPro = v))),
        ]),

        const SizedBox(height: 24),
        _buildLabel('Event Category'),
        const SizedBox(height: 10),
        _buildSectionCard(children: [
          _buildCategoryRow("Men's Singles",   _catMensSingles,   (v) => setState(() => _catMensSingles = v),   Icons.person_outline),
          _buildCategoryRow("Women's Singles", _catWomensSingles, (v) => setState(() => _catWomensSingles = v), Icons.person_outline),
          _buildCategoryRow("Men's Doubles",   _catMensDoubles,   (v) => setState(() => _catMensDoubles = v),   Icons.people_outline),
          _buildCategoryRow("Women's Doubles", _catWomensDoubles, (v) => setState(() => _catWomensDoubles = v), Icons.people_outline),
          _buildCategoryRow("Mixed Doubles",   _catMixedDoubles,  (v) => setState(() => _catMixedDoubles = v),  Icons.people_outline),
          _buildCategoryRow("Juniors",         _catJuniors,       (v) => setState(() => _catJuniors = v),       Icons.child_care_outlined),
          _buildCategoryRow("Collegiate",      _catCollegiate,    (v) => setState(() => _catCollegiate = v),    Icons.school_outlined),
          _buildCategoryRow("Seniors",         _catSeniors,       (v) => setState(() => _catSeniors = v),       Icons.elderly_outlined),
        ]),

        const SizedBox(height: 24),
        _buildSectionCard(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tourist Friendly?',
                  style: TextStyle(
                      color: _textDark, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                'Welcoming to visitors and tourists, including non-Japanese speakers.',
                style: TextStyle(color: _textLight, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _buildRadioOption('Yes', true, _touristFriendly,
                        (v) => setState(() => _touristFriendly = v)),
                const SizedBox(width: 24),
                _buildRadioOption('No', false, _touristFriendly,
                        (v) => setState(() => _touristFriendly = v)),
              ]),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 4 – Venue  (Google Map + search bar)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVenuePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            'Location & Org', 'Search or tap the map to set the venue',
            Icons.place_outlined),

        // ── Embedded map with search overlay ──────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(children: [

              // Google Map
              GoogleMap(
                initialCameraPosition:
                CameraPosition(target: _mapCenter, zoom: 13),
                onMapCreated: (c) => _mapController = c,
                onTap: _onMapTap,
                markers: _markerPos != null
                    ? {
                  Marker(
                    markerId: const MarkerId('venue'),
                    position: _markerPos!,
                    infoWindow: const InfoWindow(title: 'Event Venue'),
                  ),
                }
                    : {},
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
              ),

              // Search bar
              Positioned(
                top: 12, left: 12, right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _mapSearchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _searchPlace,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: _textDark, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search venue or address…',
                      hintStyle:
                      const TextStyle(color: _textLight, fontSize: 13),
                      prefixIcon: _searchLoading
                          ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation(_accent),
                          ),
                        ),
                      )
                          : const Icon(Icons.search_rounded,
                          color: _textLight, size: 20),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _mapSearchController,
                        builder: (_, v, __) => v.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: _textLight, size: 18),
                          onPressed: () => _mapSearchController.clear(),
                        )
                            : const SizedBox.shrink(),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 14),
                    ),
                  ),
                ),
              ),

              // "Tap to drop pin" hint
              if (_markerPos == null)
                Positioned(
                  bottom: 12, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _textDark.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Tap map to drop a pin',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),

        const SizedBox(height: 16),

        // ── Auto-filled fields (editable) ──────────────────────────────────
        _buildTextField(
          label: 'Event Address *',
          controller: _venueAddressController,
          hint: 'Auto-filled from map or type manually',
        ),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Google Maps Link',
          controller: _venueMapLinkController,
          hint: 'Auto-filled from map or paste link',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 14),

        Row(children: [
          Expanded(child: _buildTextField(
            label: 'Venue Name / Hosted By',
            controller: _venueNameController,
            hint: 'e.g. Shibuya Sports Center',
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(
            label: 'Organization Name',
            controller: _orgNameController,
            hint: 'e.g. Tokyo Pickleball Assoc.',
          )),
        ]),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Contact Email *',
          controller: _contactController,
          hint: 'email@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 5 – Description & Media
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMediaPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            'Description & Media', 'Tell players about this event',
            Icons.image_outlined),

        _buildTextField(
          label: 'Event Description *',
          controller: _descController,
          hint: 'Talk about the event, rules, schedule, etc.',
          maxLines: 6,
        ),
        const SizedBox(height: 6),
        // ── Translation hint, consistent with title field ──────────────────
        Row(children: [
          Icon(Icons.translate_rounded, size: 13, color: _textLight),
          const SizedBox(width: 5),
          const Text('Auto-translated to both EN & JP on submit',
              style: TextStyle(color: _textLight, fontSize: 11)),
        ]),
        const SizedBox(height: 20),

        _buildLabel('Event Flyer / Cover Image'),
        const SizedBox(height: 4),
        const Text("We'll use this as the event thumbnail.",
            style: TextStyle(color: _textLight, fontSize: 11)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _imageFile != null ? 200 : 120,
            decoration: BoxDecoration(
              color: _imageFile != null ? Colors.transparent : _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _imageFile != null ? _accent : _border,
                width: _imageFile != null ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: _imageFile != null
                ? Stack(fit: StackFit.expand, children: [
              Image.file(_imageFile!, fit: BoxFit.cover),
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _textDark.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text('Change',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: _primary, size: 24),
              ),
              const SizedBox(height: 8),
              const Text('Select Event Image',
                  style: TextStyle(
                      color: _textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Text('Used as thumbnail automatically',
                  style: TextStyle(color: _textLight, fontSize: 11)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom Nav
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isLast = _currentPage == _stepLabels.length - 1;
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
              child: const Text('Back',
                  style: TextStyle(
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
              if (isLast) {
                _submitForm();
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
              isLast ? 'Create Event' : 'Continue',
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
  // Shared widget helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPageHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _accentSoft, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: _primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: _textLight, fontSize: 12)),
        ])),
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

  Widget _buildDatePicker({
    required DateTime? value,
    required String hint,
    required ValueChanged<DateTime> onPicked,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                  primary: _primary, onSurface: _textDark),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value != null ? _accent : _border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_month_rounded,
              color: value != null ? _primary : _textLight, size: 18),
          const SizedBox(width: 10),
          Text(
            value != null
                ? '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}'
                : hint,
            style: TextStyle(
              color: value != null ? _textDark : _textLight,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRadioOption<T>(
      String label, T optionValue, T groupValue, ValueChanged<T> onChanged) {
    final selected = optionValue == groupValue;
    return GestureDetector(
      onTap: () => onChanged(optionValue),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: selected ? _primary : _border, width: 2),
          ),
          child: selected
              ? Center(
            child: Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(
                  color: _primary, shape: BoxShape.circle),
            ),
          )
              : null,
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
              color: selected ? _textDark : _textMid,
              fontSize: 14,
              fontWeight:
              selected ? FontWeight.w600 : FontWeight.w500,
            )),
      ]),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String Function(String) labelBuilder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _textLight, size: 20),
          dropdownColor: _surface,
          style: const TextStyle(
              color: _textDark,
              fontSize: 14,
              fontWeight: FontWeight.w500),
          items: items
              .map((item) => DropdownMenuItem(
            value: item,
            child: Text(labelBuilder(item),
                style: const TextStyle(
                    color: _textDark, fontSize: 14)),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSkillChip(
      String label, bool selected, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _primary : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _primary : _border,
              width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(
              color: _primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3))]
              : [BoxShadow(
              color: _primary.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : _textMid,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
            color: _primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            e.value,
            if (!isLast)
              const Divider(
                  height: 1, color: _border, indent: 16, endIndent: 16),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryRow(
      String label, bool value, ValueChanged<bool> onChanged, IconData icon) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon,
              size: 18, color: value ? _primary : _textLight),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: value ? _textDark : _textMid,
                    fontSize: 14,
                    fontWeight:
                    value ? FontWeight.w600 : FontWeight.w500,
                  ))),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: value ? _primary : Colors.transparent,
              border: Border.all(
                  color: value ? _primary : _border, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: value
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }
}