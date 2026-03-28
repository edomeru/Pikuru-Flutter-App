import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'dart:io';

// ─────────────────────────────────────────────────────────────────────────────
// pubspec.yaml dependencies:
//   cloud_firestore: ^4.x.x
//   firebase_storage: ^11.x.x
//   image_picker: ^1.x.x
//   flutter_riverpod: ^2.x.x
// ─────────────────────────────────────────────────────────────────────────────

class AddEventScreen extends ConsumerStatefulWidget {
  const AddEventScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends ConsumerState<AddEventScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // ── Palette (matches AddCourtScreen) ─────────────────────────────────────
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

  // ── Step config ───────────────────────────────────────────────────────────
  final List<String>   _stepLabels = ['Details', 'Schedule', 'Divisions', 'Venue', 'Media'];
  final List<IconData> _stepIcons  = [
    Icons.info_outline,
    Icons.calendar_today_outlined,
    Icons.emoji_events_outlined,
    Icons.place_outlined,
    Icons.image_outlined,
  ];

  // ── Form Controllers ──────────────────────────────────────────────────────
  late TextEditingController _titleEnController;
  late TextEditingController _titleJpController;
  late TextEditingController _linkController;
  late TextEditingController _feeController;
  late TextEditingController _contactController;
  late TextEditingController _descEnController;
  late TextEditingController _descJpController;
  late TextEditingController _notesController;
  late TextEditingController _startTimeController;

  // ── Form State ────────────────────────────────────────────────────────────
  String   _eventType     = 'Tournament';
  DateTime? _eventDate;
  DateTime? _eventStartDateTime;
  String   _timeStr       = '9:00 AM - 12:00 PM';
  bool     _isActive      = true;
  bool     _isPublished   = true;

  // Skill levels
  bool _skillBeginner = false;
  bool _skillAmateur  = false;
  bool _skillPro      = false;

  // Categories
  bool _catMensSingles    = false;
  bool _catWomensSingles  = false;
  bool _catMensDoubles    = false;
  bool _catWomensDoubles  = false;
  bool _catMixedDoubles   = false;
  bool _catJuniors        = false;
  bool _catCollegiate     = false;
  bool _catSeniors        = false;

  // Venue / Org
  String? _selectedLocId;
  String? _selectedOrgId;
  List<Map<String, dynamic>> _locations     = [];
  List<Map<String, dynamic>> _organizations = [];

  // Image
  File?  _imageFile;
  bool   _isLoading    = false;
  bool   _isFetchingOptions = false;

  static const List<String> _eventTypes = [
    'Tournament', 'Japan Tour', 'Open Play', 'Clinic', 'Social', 'Other'
  ];
  static const List<String> _timeOptions = [
    '9:00 AM - 12:00 PM',
    '1:00 PM - 5:00 PM',
    '6:00 PM - 9:00 PM',
    '9:00 AM - 5:00 PM',
    'TBD',
  ];

  @override
  void initState() {
    super.initState();
    _pageController      = PageController();
    _titleEnController   = TextEditingController();
    _titleJpController   = TextEditingController();
    _linkController      = TextEditingController();
    _feeController       = TextEditingController();
    _contactController   = TextEditingController();
    _descEnController    = TextEditingController();
    _descJpController    = TextEditingController();
    _notesController     = TextEditingController();
    _startTimeController = TextEditingController();
    _fetchOptions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _titleEnController, _titleJpController, _linkController, _feeController,
      _contactController, _descEnController, _descJpController, _notesController,
      _startTimeController,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Fetch locations + organizations ──────────────────────────────────────
  Future<void> _fetchOptions() async {
    setState(() => _isFetchingOptions = true);
    try {
      final locSnap = await FirebaseFirestore.instance.collection('locations').get();
      final orgSnap = await FirebaseFirestore.instance.collection('organizations').get();
      setState(() {
        _locations = locSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList()
          ..sort((a, b) => (a['loc_name'] ?? '').compareTo(b['loc_name'] ?? ''));
        _organizations = orgSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList()
          ..sort((a, b) =>
              (a['org_name'] ?? a['org_handle_name'] ?? '')
                  .compareTo(b['org_name'] ?? b['org_handle_name'] ?? ''));
      });
    } catch (_) {}
    finally { if (mounted) setState(() => _isFetchingOptions = false); }
  }

  // ── Pick image ────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (_titleEnController.text.trim().isEmpty || _eventDate == null) {
      _showSnack('Please fill in the Event Title and Date.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Upload image if selected — with a 30 s timeout so we never hang forever
      String imageUrl = '';
      if (_imageFile != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref('event_images/${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}');

          final uploadTask = storageRef.putFile(_imageFile!);

          // Timeout: if upload takes more than 30 s, cancel it and proceed
          // without the image rather than blocking the whole submission.
          final snapshot = await uploadTask.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              uploadTask.cancel();
              throw TimeoutException('Image upload timed out');
            },
          );
          imageUrl = await snapshot.ref.getDownloadURL();
        } on TimeoutException {
          // Network too slow / emulator restriction — save event without image
          if (mounted) {
            _showSnack('Image upload timed out — saving event without image.', isError: false);
          }
          imageUrl = '';
        } catch (uploadErr) {
          // Storage not reachable (e.g. emulator, App Check not configured)
          // Don't block the whole submission — just skip the image.
          if (mounted) {
            _showSnack('Could not upload image — saving event without it.', isError: false);
          }
          imageUrl = '';
        }
      }

      // Parse start time from controller (HH:MM)
      DateTime? startDateTime;
      if (_eventDate != null && _startTimeController.text.isNotEmpty) {
        final parts = _startTimeController.text.split(':');
        if (parts.length == 2) {
          startDateTime = DateTime(
            _eventDate!.year, _eventDate!.month, _eventDate!.day,
            int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0,
          );
        }
      }

      await FirebaseFirestore.instance.collection('events').add({
        'event_active':                   _isActive,
        'event_category_collegiate':      _catCollegiate,
        'event_category_juniors':         _catJuniors,
        'event_category_mensdoubles':     _catMensDoubles,
        'event_category_menssingle':      _catMensSingles,
        'event_category_mixeddoubles':    _catMixedDoubles,
        'event_category_seniors':         _catSeniors,
        'event_category_womensdoubles':   _catWomensDoubles,
        'event_category_womenssingle':    _catWomensSingles,
        'event_contact':                  _contactController.text.trim(),
        'event_created':                  FieldValue.serverTimestamp(),
        'event_date':                     _eventDate != null ? Timestamp.fromDate(_eventDate!) : null,
        'event_description':              _descEnController.text.trim(),
        'event_description_jp':           _descJpController.text.trim(),
        'event_fee':                      _feeController.text.trim(),
        'event_link':                     _linkController.text.trim(),
        'event_loc_id':                   _selectedLocId ?? '',
        'event_notes':                    _notesController.text.trim(),
        'event_org_id':                   _selectedOrgId ?? '',
        'event_pic':                      imageUrl,
        'event_pic_thumbnail':            imageUrl,
        'event_skill_level_amateur':      _skillAmateur,
        'event_skill_level_beginner':     _skillBeginner,
        'event_skill_level_pro':          _skillPro,
        'event_start_date':               startDateTime != null ? Timestamp.fromDate(startDateTime) : null,
        'event_start_time':               startDateTime != null ? Timestamp.fromDate(startDateTime) : null,
        'event_status':                   _isPublished,
        'event_time':                     _timeStr,
        'event_title':                    _titleEnController.text.trim(),
        'event_title_jp':                 _titleJpController.text.trim(),
        'event_type':                     _eventType,
        'event_updated':                  FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnack('Event created successfully!');
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
              boxShadow: [BoxShadow(color: _primary.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          const Text('Add an Event',
              style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
          Text(_stepLabels[_currentPage],
              style: const TextStyle(color: _accent, fontWeight: FontWeight.w500, fontSize: 12)),
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

  // ── Step Indicator ────────────────────────────────────────────────────────
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
        _buildPageHeader('Basic Details', 'Title, type & visibility', Icons.info_outline),

        _buildTextField(label: 'Event Title (EN) *', controller: _titleEnController, hint: 'e.g. UTR Pickleball Japan Tour 2026'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Event Title (JP)', controller: _titleJpController, hint: 'e.g. UTRピックルボールジャパンツアー2026'),
        const SizedBox(height: 14),

        // Event Type
        _buildLabel('Event Type *'),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _eventType,
          items: _eventTypes,
          onChanged: (v) => setState(() => _eventType = v!),
          labelBuilder: (v) => v,
        ),
        const SizedBox(height: 14),

        _buildTextField(label: 'Registration Link', controller: _linkController, hint: 'https://app.utrsports.net/events/...'),
        const SizedBox(height: 20),

        // Active + Published toggles
        Row(children: [
          Expanded(child: _buildToggleTile('Active', 'Visible in app', _isActive, Icons.visibility_outlined,
                  (v) => setState(() => _isActive = v))),
          const SizedBox(width: 12),
          Expanded(child: _buildToggleTile('Published', 'Open to public', _isPublished, Icons.public_outlined,
                  (v) => setState(() => _isPublished = v))),
        ]),
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
        _buildPageHeader('Schedule & Fees', 'Date, time and entry fee', Icons.calendar_today_outlined),

        // Date picker
        _buildLabel('Event Date *'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _eventDate ?? DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: _primary, onSurface: _textDark),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _eventDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _eventDate != null ? _accent : _border),
            ),
            child: Row(children: [
              Icon(Icons.calendar_month_rounded, color: _eventDate != null ? _primary : _textLight, size: 18),
              const SizedBox(width: 10),
              Text(
                _eventDate != null
                    ? '${_eventDate!.year}/${_eventDate!.month.toString().padLeft(2,'0')}/${_eventDate!.day.toString().padLeft(2,'0')}'
                    : 'Select event date',
                style: TextStyle(
                  color: _eventDate != null ? _textDark : _textLight,
                  fontSize: 14, fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 14),
        _buildTextField(
          label: 'Start Time (HH:MM)',
          controller: _startTimeController,
          hint: 'e.g. 09:00',
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: 14),

        // Display time string
        _buildLabel('Display Time String'),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _timeStr,
          items: _timeOptions,
          onChanged: (v) => setState(() => _timeStr = v!),
          labelBuilder: (v) {
            const map = {
              '9:00 AM - 12:00 PM': 'Morning (9:00 AM - 12:00 PM)',
              '1:00 PM - 5:00 PM':  'Afternoon (1:00 PM - 5:00 PM)',
              '6:00 PM - 9:00 PM':  'Evening (6:00 PM - 9:00 PM)',
              '9:00 AM - 5:00 PM':  'Full Day (9:00 AM - 5:00 PM)',
              'TBD':                'To Be Determined (TBD)',
            };
            return map[v] ?? v;
          },
        ),
        const SizedBox(height: 14),
        _buildTextField(label: 'Entry Fee', controller: _feeController, hint: 'e.g. ¥2,000 or 6,600-7,040'),
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
        _buildPageHeader('Divisions & Levels', 'Who can participate?', Icons.emoji_events_outlined),

        _buildLabel('Target Skill Levels'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildSkillChip('Beginner', _skillBeginner, (v) => setState(() => _skillBeginner = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip('Amateur', _skillAmateur, (v) => setState(() => _skillAmateur = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip('Pro', _skillPro, (v) => setState(() => _skillPro = v))),
        ]),

        const SizedBox(height: 24),
        _buildLabel('Categories Included'),
        const SizedBox(height: 10),

        _buildSectionCard(children: [
          _buildCategoryRow("Men's Singles",    _catMensSingles,   (v) => setState(() => _catMensSingles = v),   Icons.person_outline),
          _buildCategoryRow("Women's Singles",  _catWomensSingles, (v) => setState(() => _catWomensSingles = v), Icons.person_outline),
          _buildCategoryRow("Men's Doubles",    _catMensDoubles,   (v) => setState(() => _catMensDoubles = v),   Icons.people_outline),
          _buildCategoryRow("Women's Doubles",  _catWomensDoubles, (v) => setState(() => _catWomensDoubles = v), Icons.people_outline),
          _buildCategoryRow("Mixed Doubles",    _catMixedDoubles,  (v) => setState(() => _catMixedDoubles = v),  Icons.people_outline),
          _buildCategoryRow("Juniors",          _catJuniors,       (v) => setState(() => _catJuniors = v),       Icons.child_care_outlined),
          _buildCategoryRow("Collegiate",       _catCollegiate,    (v) => setState(() => _catCollegiate = v),    Icons.school_outlined),
          _buildCategoryRow("Seniors",          _catSeniors,       (v) => setState(() => _catSeniors = v),       Icons.elderly_outlined),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 4 – Venue & Organization
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVenuePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Venue & Organization', 'Where and who is hosting?', Icons.place_outlined),

        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 16, color: _primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Link this event to an existing Court/Location and its managing Organization so players can find hosting details.',
                style: const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
              ),
            ),
          ]),
        ),

        _buildLabel('Target Location *'),
        const SizedBox(height: 6),
        _isFetchingOptions
            ? _buildLoadingSkeleton()
            : _buildSearchableDropdown(
          hint: 'Select an existing court...',
          value: _selectedLocId,
          items: _locations,
          labelKey: 'loc_name',
          valueKey: 'loc_id',       // ← stores loc_id, NOT the Firestore doc id
          secondaryKey: 'loc_city_en',
          onChanged: (v) => setState(() => _selectedLocId = v),
        ),

        const SizedBox(height: 14),
        _buildLabel('Managing Organization'),
        const SizedBox(height: 6),
        _isFetchingOptions
            ? _buildLoadingSkeleton()
            : _buildSearchableDropdown(
          hint: 'None / Independent',
          value: _selectedOrgId,
          items: _organizations,
          labelKey: 'org_name',
          valueKey: 'org_id',       // ← stores org_id, NOT the Firestore doc id
          secondaryKey: 'org_handle_name',
          onChanged: (v) => setState(() => _selectedOrgId = v),
          nullable: true,
        ),

        const SizedBox(height: 14),
        _buildTextField(
          label: 'Contact Email / Phone',
          controller: _contactController,
          hint: 'e.g. info@event.com',
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 5 – Media & Notes
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMediaPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Description & Media', 'Tell players about this event', Icons.image_outlined),

        _buildTextField(
          label: 'Event Description (EN)',
          controller: _descEnController,
          hint: 'Talk about the event, rules, schedule...',
          maxLines: 5,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: 'Event Description (JP)',
          controller: _descJpController,
          hint: 'イベントの詳細、ルール、スケジュールなど...',
          maxLines: 5,
        ),
        const SizedBox(height: 20),

        // Cover image picker
        _buildLabel('Cover Picture'),
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
                style: _imageFile != null ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: _imageFile != null
                ? Stack(fit: StackFit.expand, children: [
              Image.file(_imageFile!, fit: BoxFit.cover),
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _textDark.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text('Change', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_photo_alternate_outlined, color: _primary, size: 24),
              ),
              const SizedBox(height: 8),
              const Text('Select Event Image', style: TextStyle(color: _textMid, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Text('Used as thumbnail automatically', style: TextStyle(color: _textLight, fontSize: 11)),
            ]),
          ),
        ),

        const SizedBox(height: 20),
        _buildTextField(
          label: 'Internal Notes (Hidden from public)',
          controller: _notesController,
          hint: 'Staff-only notes...',
          maxLines: 3,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom navigation
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
                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Back', style: TextStyle(color: _textMid, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () {
              if (isLast) {
                _submitForm();
              } else {
                _pageController.nextPage(
                    duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _accent.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Text(
              isLast ? 'Create Event' : 'Continue',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared Widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPageHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: _primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: _textLight, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(color: _textMid, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
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
        style: const TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textLight, fontSize: 14),
          filled: true, fillColor: _surface,
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border, width: 1)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    ]);
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String Function(String) labelBuilder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textLight, size: 20),
          dropdownColor: _surface,
          style: const TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w500),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(labelBuilder(item), style: const TextStyle(color: _textDark, fontSize: 14)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSearchableDropdown({
    required String hint,
    required String? value,
    required List<Map<String, dynamic>> items,
    required String labelKey,
    String? valueKey,        // ← the field used as the stored value (e.g. 'loc_id')
    String? secondaryKey,
    required ValueChanged<String?> onChanged,
    bool nullable = false,
  }) {
    // Resolve display label from the currently selected value
    String displayLabel = hint;
    if (value != null) {
      final match = items.firstWhere(
            (i) => (i[valueKey ?? 'id'] ?? i['id'] ?? i[labelKey]).toString() == value,
        orElse: () => {},
      );
      if (match.isNotEmpty) displayLabel = (match[labelKey] ?? hint).toString();
    }

    return GestureDetector(
      onTap: () => _showPickerSheet(
        hint: hint, value: value, items: items,
        labelKey: labelKey, valueKey: valueKey,
        secondaryKey: secondaryKey,
        onChanged: onChanged, nullable: nullable,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value != null ? _accent : _border),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              displayLabel,
              style: TextStyle(
                color: value != null ? _textDark : _textLight,
                fontSize: 14, fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: _textLight, size: 20),
        ]),
      ),
    );
  }

  void _showPickerSheet({
    required String hint,
    required String? value,
    required List<Map<String, dynamic>> items,
    required String labelKey,
    String? valueKey,        // ← the field used as the stored value (e.g. 'loc_id')
    String? secondaryKey,
    required ValueChanged<String?> onChanged,
    required bool nullable,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(hint, style: const TextStyle(color: _textMid, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (nullable)
                  _sheetItem('None / Independent', null, value, onChanged),
                ...items.map((item) {
                  // Use valueKey field (e.g. 'loc_id') if provided,
                  // otherwise fall back to the Firestore document 'id'.
                  final itemValue = (item[valueKey ?? 'id'] ?? item['id'] ?? item[labelKey]).toString();
                  final label     = (item[labelKey] ?? itemValue).toString();
                  final sub       = secondaryKey != null ? (item[secondaryKey] ?? '').toString() : '';
                  return _sheetItem(label, itemValue, value, onChanged, subtitle: sub.isNotEmpty ? sub : null);
                }),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sheetItem(String label, String? id, String? current, ValueChanged<String?> onChanged, {String? subtitle}) {
    final isSelected = current == id;
    return InkWell(
      onTap: () { Navigator.pop(context); onChanged(id); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        color: isSelected ? _accentSoft : Colors.transparent,
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              color: isSelected ? _primary : _textDark,
              fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            )),
            if (subtitle != null)
              Text(subtitle, style: const TextStyle(color: _textLight, fontSize: 12)),
          ])),
          if (isSelected) const Icon(Icons.check_rounded, color: _primary, size: 18),
        ]),
      ),
    );
  }

  Widget _buildToggleTile(String title, String subtitle, bool value, IconData icon, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value ? _accentSoft : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? _accent : _border, width: value ? 1.5 : 1),
          boxShadow: [BoxShadow(color: _primary.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: value ? _primary : _border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: value ? Colors.white : _textLight),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: value ? _textDark : _textMid, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(color: _textLight, fontSize: 11)),
          ])),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36, height: 20,
            decoration: BoxDecoration(
              color: value ? _primary : _border,
              borderRadius: BorderRadius.circular(10),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(2),
                width: 16, height: 16,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSkillChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _primary : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _primary : _border, width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(color: _primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: _primary.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : _textMid,
            fontSize: 13, fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: children.asMap().entries.map((e) {
        final isLast = e.key == children.length - 1;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          e.value,
          if (!isLast) const Divider(height: 1, color: _border, indent: 16, endIndent: 16),
        ]);
      }).toList()),
    );
  }

  Widget _buildCategoryRow(String label, bool value, ValueChanged<bool> onChanged, IconData icon) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 18, color: value ? _primary : _textLight),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(
            color: value ? _textDark : _textMid,
            fontSize: 14, fontWeight: value ? FontWeight.w600 : FontWeight.w500,
          ))),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: value ? _primary : Colors.transparent,
              border: Border.all(color: value ? _primary : _border, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: value ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
        ]),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _accentSoft.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: const Center(
        child: SizedBox(height: 16, width: 16,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_accent))),
      ),
    );
  }
}