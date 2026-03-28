import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AddGroupScreen — mirrors the web app's Add a Group page
// Fields: all org_* fields from Firestore spec
// Design: matches AddCourtScreen palette (green-tinted light bg)
// ─────────────────────────────────────────────────────────────────────────────

class AddGroupScreen extends ConsumerStatefulWidget {
  const AddGroupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends ConsumerState<AddGroupScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // ── Palette (matches AddCourtScreen) ──────────────────────────────────────
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

  // ── Steps ─────────────────────────────────────────────────────────────────
  final List<String> _stepLabels = ['Basics', 'Location', 'Schedule', 'Members', 'Media'];

  // ── Form Controllers ──────────────────────────────────────────────────────
  late TextEditingController _nameController;
  late TextEditingController _handleController;
  late TextEditingController _websiteController;
  late TextEditingController _socialController;
  late TextEditingController _emailController;
  late TextEditingController _bookingController;
  late TextEditingController _notesController;
  late TextEditingController _cityController;
  late TextEditingController _prefectureController;
  late TextEditingController _countryController;

  // ── Form State ────────────────────────────────────────────────────────────
  String  _orgType       = 'Club';
  bool    _isActive      = true;
  bool    _isPublic      = true;
  bool    _locRelation   = false;
  String? _selectedLocId; // stores loc_id (e.g. "L-0000000050")

  // Meetup days
  bool _mon = false, _tue = false, _wed = false, _thu = false;
  bool _fri = false, _sat = false, _sun = false;

  // Meetup times
  bool _mornings = false, _afternoons = false, _evenings = false;

  // Skill levels
  bool _skillBeginner     = false;
  bool _skillIntermediate = false;
  bool _skillAdvance      = false;

  // Age groups
  bool _ageJuniors  = false;
  bool _ageStudents = false;
  bool _ageAdult    = true;
  bool _ageSeniors  = false;

  // Image
  File? _imageFile;

  // Data
  List<Map<String, dynamic>> _locations = [];
  bool _isFetchingLocs = false;
  bool _isLoading      = false;

  static const List<String> _orgTypes = ['Club', 'Entity', 'Casual Group', 'Other'];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pageController    = PageController();
    _nameController    = TextEditingController();
    _handleController  = TextEditingController();
    _websiteController = TextEditingController();
    _socialController  = TextEditingController();
    _emailController   = TextEditingController();
    _bookingController = TextEditingController();
    _notesController   = TextEditingController();
    _cityController    = TextEditingController();
    _prefectureController = TextEditingController(text: 'Tokyo');
    _countryController    = TextEditingController(text: 'Japan');
    _fetchLocations();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _nameController, _handleController, _websiteController, _socialController,
      _emailController, _bookingController, _notesController, _cityController,
      _prefectureController, _countryController,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Fetch locations ───────────────────────────────────────────────────────
  Future<void> _fetchLocations() async {
    setState(() => _isFetchingLocs = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('locations').get();
      setState(() {
        _locations = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList()
          ..sort((a, b) => (a['loc_name'] ?? '').compareTo(b['loc_name'] ?? ''));
      });
    } catch (_) {}
    finally { if (mounted) setState(() => _isFetchingLocs = false); }
  }

  // ── Pick image ────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _imageFile = File(picked.path));
  }

  // ── Generate org_id ───────────────────────────────────────────────────────
  Future<String> _generateOrgId() async {
    final snap = await FirebaseFirestore.instance
        .collection('organizations')
        .orderBy('org_id', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return 'O-0000000001';
    final last = snap.docs.first.data()['org_id']?.toString() ?? 'O-0000000000';
    final num  = int.tryParse(last.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'O-${(num + 1).toString().padLeft(10, '0')}';
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (_nameController.text.trim().isEmpty || _handleController.text.trim().isEmpty) {
      _showSnack('Please fill in Group Name and Handle.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Upload image
      String imageUrl = '';
      if (_imageFile != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref('org_images/${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}');
          final snapshot = await storageRef.putFile(_imageFile!).timeout(const Duration(seconds: 30));
          imageUrl = await snapshot.ref.getDownloadURL();
        } catch (_) {
          if (mounted) _showSnack('Image upload failed — saving without image.', isError: false);
        }
      }

      final orgId = await _generateOrgId();

      await FirebaseFirestore.instance.collection('organizations').add({
        'org_active':                  _isActive,
        'org_age_adult':               _ageAdult,
        'org_age_juniors':             _ageJuniors,
        'org_age_seniors':             _ageSeniors,
        'org_age_students':            _ageStudents,
        'org_booking':                 _bookingController.text.trim(),
        'org_city':                    _cityController.text.trim(),
        'org_contact_email':           _emailController.text.trim(),
        'org_country':                 _countryController.text.trim(),
        'org_created_at':              FieldValue.serverTimestamp(),
        'org_handle_name':             _handleController.text.trim(),
        'org_id':                      orgId,
        'org_image':                   imageUrl,
        'org_loc_id':                  _selectedLocId ?? '',
        'org_loc_relation':            _locRelation ? 'TRUE' : 'FALSE',
        'org_meetup_fri':              _fri,
        'org_meetup_mon':              _mon,
        'org_meetup_sat':              _sat,
        'org_meetup_sun':              _sun,
        'org_meetup_thurs':            _thu,
        'org_meetup_time_afternoons':  _afternoons,
        'org_meetup_time_evenings':    _evenings,
        'org_meetup_time_mornings':    _mornings,
        'org_meetup_tues':             _tue,
        'org_meetup_weds':             _wed,
        'org_name':                    _nameController.text.trim(),
        'org_notes':                   _notesController.text.trim(),
        'org_prefecture':              _prefectureController.text.trim(),
        'org_public':                  _isPublic,
        'org_skill_advance':           _skillAdvance,
        'org_skill_beginner':          _skillBeginner,
        'org_skill_intermediate':      _skillIntermediate,
        'org_social':                  _socialController.text.trim(),
        'org_type':                    _orgType,
        'org_updated_at':              FieldValue.serverTimestamp(),
        'org_website':                 _websiteController.text.trim(),
      });

      if (mounted) {
        _showSnack('Group created successfully!');
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
          const Text('Add a Group',
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
              _buildBasicsPage(),
              _buildLocationPage(),
              _buildSchedulePage(),
              _buildMembersPage(),
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
  // Page 1 — Basic Details
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBasicsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Basic Details', 'Name, type & visibility', Icons.groups_outlined),

        _buildTextField(label: 'Group / Org Name *', controller: _nameController, hint: 'e.g. Tokyo Pickleball Club'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Handle / Short Name *', controller: _handleController, hint: 'e.g. tokyo_pickleball'),
        const SizedBox(height: 14),

        _buildLabel('Group Type'),
        const SizedBox(height: 6),
        _buildSegmentedType(),
        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: _buildToggleTile('Active', 'Visible in app', _isActive, Icons.visibility_outlined,
                  (v) => setState(() => _isActive = v))),
          const SizedBox(width: 12),
          Expanded(child: _buildToggleTile('Public', 'Listed publicly', _isPublic, Icons.public_outlined,
                  (v) => setState(() => _isPublic = v))),
        ]),
      ]),
    );
  }

  Widget _buildSegmentedType() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _orgTypes.map((type) {
        final selected = _orgType == type;
        return GestureDetector(
          onTap: () => setState(() => _orgType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _primary : _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: selected ? _primary : _border, width: selected ? 1.5 : 1),
              boxShadow: selected
                  ? [BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
                  : [],
            ),
            child: Text(type,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _textMid)),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 2 — Location & Contact
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Location & Contact', 'Where does this group meet?', Icons.place_outlined),

        _buildLabel('Home Court / Primary Location'),
        const SizedBox(height: 6),
        _isFetchingLocs
            ? _buildLoadingSkeleton()
            : _buildLocationPicker(),
        const SizedBox(height: 10),

        // loc_relation toggle
        GestureDetector(
          onTap: () => setState(() => _locRelation = !_locRelation),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _locRelation ? _accentSoft : _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _locRelation ? _accent : _border, width: _locRelation ? 1.5 : 1),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: _locRelation ? _primary : Colors.transparent,
                  border: Border.all(color: _locRelation ? _primary : _border, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _locRelation ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Officially associated with this location',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMid)),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 20),
        _buildTextField(label: 'City', controller: _cityController, hint: 'e.g. Shinjuku'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Prefecture', controller: _prefectureController, hint: 'e.g. Tokyo'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Country', controller: _countryController, hint: 'Japan'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Contact Email', controller: _emailController, hint: 'info@group.com', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _buildTextField(label: 'Website', controller: _websiteController, hint: 'https://example.com', keyboardType: TextInputType.url),
        const SizedBox(height: 14),
        _buildTextField(label: 'Social Media Link', controller: _socialController, hint: 'https://instagram.com/...', keyboardType: TextInputType.url),
      ]),
    );
  }

  Widget _buildLocationPicker() {
    // Find display name of currently selected loc
    String displayLabel = 'Select an existing court...';
    if (_selectedLocId != null) {
      final match = _locations.firstWhere(
            (l) => (l['loc_id'] ?? l['id']).toString() == _selectedLocId,
        orElse: () => {},
      );
      if (match.isNotEmpty) displayLabel = (match['loc_name'] ?? _selectedLocId!).toString();
    }

    return GestureDetector(
      onTap: () => _showLocationSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _selectedLocId != null ? _accent : _border),
        ),
        child: Row(children: [
          Icon(Icons.sports_tennis_rounded,
              size: 18, color: _selectedLocId != null ? _primary : _textLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(displayLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _selectedLocId != null ? _textDark : _textLight)),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: _textLight, size: 20),
        ]),
      ),
    );
  }

  void _showLocationSheet() {
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
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('Select a Court', style: TextStyle(color: _textMid, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // None option
                InkWell(
                  onTap: () { Navigator.pop(context); setState(() => _selectedLocId = null); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    color: _selectedLocId == null ? _accentSoft : Colors.transparent,
                    child: Text('None',
                        style: TextStyle(
                            color: _selectedLocId == null ? _primary : _textLight,
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ),
                ..._locations.map((loc) {
                  final locId    = (loc['loc_id'] ?? loc['id']).toString();
                  final name     = (loc['loc_name'] ?? locId).toString();
                  final city     = (loc['loc_city_en'] ?? loc['loc_city'] ?? '').toString();
                  final selected = _selectedLocId == locId;
                  return InkWell(
                    onTap: () { Navigator.pop(context); setState(() => _selectedLocId = locId); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      color: selected ? _accentSoft : Colors.transparent,
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: TextStyle(
                              color: selected ? _primary : _textDark,
                              fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                          if (city.isNotEmpty)
                            Text(city, style: const TextStyle(color: _textLight, fontSize: 12)),
                        ])),
                        if (selected) const Icon(Icons.check_rounded, color: _primary, size: 18),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 3 — Meetup Schedule
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSchedulePage() {
    final days = [
      ('Mon', _mon,  (v) => setState(() => _mon  = v)),
      ('Tue', _tue,  (v) => setState(() => _tue  = v)),
      ('Wed', _wed,  (v) => setState(() => _wed  = v)),
      ('Thu', _thu,  (v) => setState(() => _thu  = v)),
      ('Fri', _fri,  (v) => setState(() => _fri  = v)),
      ('Sat', _sat,  (v) => setState(() => _sat  = v)),
      ('Sun', _sun,  (v) => setState(() => _sun  = v)),
    ];
    final times = [
      ('Mornings',   _mornings,   (v) => setState(() => _mornings   = v)),
      ('Afternoons', _afternoons, (v) => setState(() => _afternoons = v)),
      ('Evenings',   _evenings,   (v) => setState(() => _evenings   = v)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Meetup Schedule', 'When does this group typically meet?', Icons.calendar_today_outlined),

        _buildLabel('Typical Meetup Days'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: days.map((d) {
            final (label, value, onChanged) = d;
            return GestureDetector(
              onTap: () => onChanged(!value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52, height: 44,
                decoration: BoxDecoration(
                  color: value ? _primary : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: value ? _primary : _border, width: value ? 1.5 : 1),
                  boxShadow: value
                      ? [BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Center(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: value ? Colors.white : _textMid)),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        _buildLabel('Typical Times'),
        const SizedBox(height: 10),
        Row(
          children: times.map((t) {
            final (label, value, onChanged) = t;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(!value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: label != 'Evenings' ? 10 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value ? _primary : _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: value ? _primary : _border, width: value ? 1.5 : 1),
                    boxShadow: value
                        ? [BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: value ? Colors.white : _textMid)),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        _buildTextField(
          label: 'Participation / Booking Info',
          controller: _bookingController,
          hint: 'e.g. Free to join, ¥500 drop-in',
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 4 — Demographics
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMembersPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Demographics', 'Who is this group for?', Icons.people_outline),

        _buildLabel('Target Skill Levels'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildSkillChip('Beginner',     _skillBeginner,     (v) => setState(() => _skillBeginner = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip('Intermediate', _skillIntermediate, (v) => setState(() => _skillIntermediate = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip('Advanced',     _skillAdvance,      (v) => setState(() => _skillAdvance = v))),
        ]),

        const SizedBox(height: 24),
        _buildLabel('Age Groups'),
        const SizedBox(height: 10),
        _buildSectionCard(children: [
          _buildCategoryRow('Juniors',  _ageJuniors,  (v) => setState(() => _ageJuniors  = v), Icons.child_care_outlined),
          _buildCategoryRow('Students', _ageStudents, (v) => setState(() => _ageStudents = v), Icons.school_outlined),
          _buildCategoryRow('Adults',   _ageAdult,    (v) => setState(() => _ageAdult    = v), Icons.person_outline),
          _buildCategoryRow('Seniors',  _ageSeniors,  (v) => setState(() => _ageSeniors  = v), Icons.elderly_outlined),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 5 — Media & Notes
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMediaPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Profile & Notes', 'Cover image and internal notes', Icons.image_outlined),

        _buildLabel('Profile / Cover Picture'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _imageFile != null ? 200 : 130,
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
                child: const Icon(Icons.add_photo_alternate_outlined, color: _primary, size: 26),
              ),
              const SizedBox(height: 10),
              const Text('Select Group Image',
                  style: TextStyle(color: _textMid, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Text("Used for your group's avatar and listings",
                  style: TextStyle(color: _textLight, fontSize: 11)),
            ]),
          ),
        ),

        const SizedBox(height: 20),
        _buildTextField(
          label: 'Internal Notes (Hidden from public)',
          controller: _notesController,
          hint: 'Staff-only notes...',
          maxLines: 4,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom nav
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
              child: const Text('Back',
                  style: TextStyle(color: _textMid, fontWeight: FontWeight.w600, fontSize: 15)),
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
              isLast ? 'Create Group' : 'Continue',
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
          Text(title, style: const TextStyle(
              color: _textDark, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: _textLight, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(color: _textMid, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2));

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
            decoration: BoxDecoration(color: value ? _primary : _border, borderRadius: BorderRadius.circular(10)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(2), width: 16, height: 16,
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
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: selected ? Colors.white : _textMid, fontSize: 12, fontWeight: FontWeight.w700)),
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
              fontSize: 14, fontWeight: value ? FontWeight.w600 : FontWeight.w500))),
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