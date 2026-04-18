import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AddGroupScreen extends ConsumerStatefulWidget {
  const AddGroupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends ConsumerState<AddGroupScreen> {
  late PageController _pageController;
  int _currentPage = 0;

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

  final List<String> _stepLabels = ['Basics', 'Location', 'Schedule', 'Members', 'Media', 'Review'];

  late TextEditingController _nameController;
  late TextEditingController _handleController;
  late TextEditingController _descController;
  late TextEditingController _locNameController;
  late TextEditingController _cityController;
  late TextEditingController _prefController;
  late TextEditingController _countryController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _socialController;

  String _orgType = 'For-Profit Club / Facility';

  static const List<String> _orgTypes = [
    'For-Profit Club / Facility',
    'Nonprofit / Federation',
    'Local Group',
  ];

  bool _mon = false, _tue = false, _wed = false, _thu = false;
  bool _fri = false, _sat = false, _sun = false;
  bool _mornings = false, _afternoons = false, _evenings = false;

  bool _skillBeginner     = false;
  bool _skillIntermediate = false;
  bool _skillAdvance      = false;
  bool _ageJuniors  = false;
  bool _ageStudents = false;
  bool _ageAdult    = true;
  bool _ageSeniors  = false;

  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController    = PageController();
    _nameController    = TextEditingController();
    _handleController  = TextEditingController();
    _descController    = TextEditingController();
    _locNameController = TextEditingController();
    _cityController    = TextEditingController();
    _prefController    = TextEditingController();
    _countryController = TextEditingController(text: 'Japan');
    _emailController   = TextEditingController();
    _websiteController = TextEditingController();
    _socialController  = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _nameController, _handleController, _descController,
      _locNameController, _cityController,
      _prefController, _countryController,
      _emailController, _websiteController, _socialController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Image Picker ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  // ── Generate Org ID ───────────────────────────────────────────────────────
  Future<String> _generateOrgId() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('organizations')
          .get();

      int maxNum = 0;
      for (final doc in snap.docs) {
        final id  = doc.data()['org_id']?.toString() ?? '';
        final num = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (num > maxNum) maxNum = num;
      }
      return 'O-${(maxNum + 1).toString().padLeft(10, '0')}';
    } catch (_) {
      final fallback = DateTime.now().millisecondsSinceEpoch % 10000000000;
      return 'O-${fallback.toString().padLeft(10, '0')}';
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('You must be signed in to create a group.', isError: true);
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        _handleController.text.trim().isEmpty) {
      _showSnack('Please fill in Group Name and Handle.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── Image upload ────────────────────────────────────────────────────
      String imageUrl = '';
      if (_imageFile != null) {
        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}';
          final storageRef =
          FirebaseStorage.instance.ref('org_images/$fileName');

          final snapshot = await storageRef
              .putFile(_imageFile!)
              .timeout(const Duration(seconds: 60));

          if (snapshot.state == TaskState.success) {
            imageUrl = await snapshot.ref.getDownloadURL();
          }
        } on TimeoutException {
          debugPrint('Image upload timed out');
          if (mounted) {
            _showSnack('Image upload timed out — saving without image.');
          }
        } catch (e) {
          debugPrint('Image upload failed: $e');
          if (mounted) {
            _showSnack('Image upload failed — saving without image.');
          }
        }
      }

      final orgId = await _generateOrgId();

      // ── Firestore document — fields match web app exactly ───────────────
      await FirebaseFirestore.instance.collection('organizations').add({
        'org_id':              orgId,
        'org_active':          false,
        'org_pending_review':  true,
        'org_checked':         false,
        'org_addedby':         user.uid,
        'org_added':           FieldValue.serverTimestamp(),
        'org_age_adult':       _ageAdult,
        'org_age_juniors':     _ageJuniors,
        'org_age_seniors':     _ageSeniors,
        'org_age_students':    _ageStudents,
        'org_city':            _cityController.text.trim(),
        'org_contact_email':   _emailController.text.trim(),
        'org_country':         _countryController.text.trim(),
        'org_created_at':      FieldValue.serverTimestamp(),
        'org_description':     _descController.text.trim(),
        'org_handle_name':     _handleController.text.trim(),
        'org_image':           imageUrl,
        'org_loc_id':          '',
        'org_venue_loc_name':  _locNameController.text.trim(),
        'org_meetup_fri':      _fri,
        'org_meetup_mon':      _mon,
        'org_meetup_sat':      _sat,
        'org_meetup_sun':      _sun,
        'org_meetup_thurs':    _thu,
        'org_meetup_time_afternoons': _afternoons,
        'org_meetup_time_evenings':   _evenings,
        'org_meetup_time_mornings':   _mornings,
        'org_meetup_tues':     _tue,
        'org_meetup_weds':     _wed,
        'org_name':            _nameController.text.trim(),
        'org_prefecture':      _prefController.text.trim(),
        'org_public':          false,
        'org_skill_advance':   _skillAdvance,
        'org_skill_beginner':  _skillBeginner,
        'org_skill_intermediate': _skillIntermediate,
        'org_social':          _socialController.text.trim(),
        'org_type':            _orgType,
        'org_website':         _websiteController.text.trim(),
        'submittedBy':         user.uid,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Group is under review. It will be added to our system within 48 hours!');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error saving group: $e', isError: true);
      }
    }
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _errorRed : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: _textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          const Text(
            'Add a Group',
            style: TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            _stepLabels[_currentPage],
            style: const TextStyle(
              color: _accent,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
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
              _buildReviewPage(),
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

  // ── Page 1 — Basic Details ────────────────────────────────────────────────
  Widget _buildBasicsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            'Basic Details', 'Name, type & description', Icons.groups_outlined),
        _buildTextField(
          label: 'Group / Org Name *',
          controller: _nameController,
          hint: 'e.g. Tokyo Pickleball Club',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: 'Handle / Short Name *',
          controller: _handleController,
          hint: 'e.g. tokyo_pickleball',
        ),
        const SizedBox(height: 14),
        _buildLabel('Group Type'),
        const SizedBox(height: 8),
        _buildSegmentedType(),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Description',
          controller: _descController,
          hint: 'Tell people about this group...',
          maxLines: 3,
        ),
      ]),
    );
  }

  Widget _buildSegmentedType() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _orgTypes.map((type) {
        final selected = _orgType == type;
        final displayLabel = switch (type) {
          'For-Profit Club / Facility' => 'Club / Facility',
          'Nonprofit / Federation'     => 'Nonprofit / Federation',
          'Local Group'                => 'Local Group',
          _                            => type,
        };
        return GestureDetector(
          onTap: () => setState(() => _orgType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _primary : _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? _primary : _border,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: _primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
                  : [],
            ),
            child: Text(
              displayLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _textMid,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Page 2 — Location & Contact ───────────────────────────────────────────
  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Location & Contact',
            'Where does this group meet?', Icons.place_outlined),
        _buildTextField(
          label: 'Home Court / Primary Location',
          controller: _locNameController,
          hint: 'e.g. Yoyogi Park Court 3',
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _buildTextField(
              label: 'City',
              controller: _cityController,
              hint: 'e.g. Shinjuku',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTextField(
              label: 'Prefecture',
              controller: _prefController,
              hint: 'e.g. Tokyo',
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _buildTextField(
          label: 'Country',
          controller: _countryController,
          hint: 'Japan',
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Contact Email',
          controller: _emailController,
          hint: 'info@group.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: 'Website',
          controller: _websiteController,
          hint: 'https://example.com',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: 'Social Media Link (e.g. Instagram)',
          controller: _socialController,
          hint: 'https://instagram.com/...',
          keyboardType: TextInputType.url,
        ),
      ]),
    );
  }

  // ── Page 3 — Schedule ─────────────────────────────────────────────────────
  Widget _buildSchedulePage() {
    final days = [
      ('Mon', _mon, (bool v) => setState(() => _mon = v)),
      ('Tue', _tue, (bool v) => setState(() => _tue = v)),
      ('Wed', _wed, (bool v) => setState(() => _wed = v)),
      ('Thu', _thu, (bool v) => setState(() => _thu = v)),
      ('Fri', _fri, (bool v) => setState(() => _fri = v)),
      ('Sat', _sat, (bool v) => setState(() => _sat = v)),
      ('Sun', _sun, (bool v) => setState(() => _sun = v)),
    ];
    final times = [
      ('Mornings',   _mornings,   (bool v) => setState(() => _mornings   = v)),
      ('Afternoons', _afternoons, (bool v) => setState(() => _afternoons = v)),
      ('Evenings',   _evenings,   (bool v) => setState(() => _evenings   = v)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Meetup Schedule',
            'When does this group typically meet?',
            Icons.calendar_today_outlined),
        _buildLabel('Typical Meetup Days'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: days.map((d) {
            final (label, value, onChanged) = d;
            return GestureDetector(
              onTap: () => onChanged(!value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 44,
                decoration: BoxDecoration(
                  color: value ? _primary : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: value ? _primary : _border,
                    width: value ? 1.5 : 1,
                  ),
                  boxShadow: value
                      ? [
                    BoxShadow(
                      color: _primary.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: value ? Colors.white : _textMid,
                    ),
                  ),
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
                  margin:
                  EdgeInsets.only(right: label != 'Evenings' ? 10 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value ? _primary : _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: value ? _primary : _border,
                      width: value ? 1.5 : 1,
                    ),
                    boxShadow: value
                        ? [
                      BoxShadow(
                        color: _primary.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                        : [],
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: value ? Colors.white : _textMid,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── Page 4 — Demographics ─────────────────────────────────────────────────
  Widget _buildMembersPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            'Demographics', 'Who is this group for?', Icons.people_outline),
        _buildLabel('Target Skill Levels'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _buildSkillChip('Beginner', _skillBeginner,
                    (v) => setState(() => _skillBeginner = v)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSkillChip('Intermediate', _skillIntermediate,
                    (v) => setState(() => _skillIntermediate = v)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSkillChip('Advanced', _skillAdvance,
                    (v) => setState(() => _skillAdvance = v)),
          ),
        ]),
        const SizedBox(height: 24),
        _buildLabel('Age Groups'),
        const SizedBox(height: 10),
        _buildSectionCard(children: [
          _buildCategoryRow('Juniors', _ageJuniors,
                  (v) => setState(() => _ageJuniors = v),
              Icons.child_care_outlined),
          _buildCategoryRow('Students', _ageStudents,
                  (v) => setState(() => _ageStudents = v),
              Icons.school_outlined),
          _buildCategoryRow('Adults', _ageAdult,
                  (v) => setState(() => _ageAdult = v),
              Icons.person_outline),
          _buildCategoryRow('Seniors', _ageSeniors,
                  (v) => setState(() => _ageSeniors = v),
              Icons.elderly_outlined),
        ]),
      ]),
    );
  }

  // ── Page 5 — Media ────────────────────────────────────────────────────────
  Widget _buildMediaPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Profile Image', 'Cover image for your group',
            Icons.image_outlined),
        _buildLabel('Profile / Cover Picture'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _imageFile != null ? 200 : 130,
            decoration: BoxDecoration(
              color:
              _imageFile != null ? Colors.transparent : _surface,
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
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _textDark.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 13, color: Colors.white),
                        SizedBox(width: 5),
                        Text('Change',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                      ]),
                ),
              ),
            ])
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _primary,
                      size: 26),
                ),
                const SizedBox(height: 10),
                const Text('Select Group Image',
                    style: TextStyle(
                      color: _textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                const Text(
                    "We'll use this for your group's avatar and listings",
                    style: TextStyle(
                        color: _textLight, fontSize: 11)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Page 6 — Review ───────────────────────────────────────────────────────
  Widget _buildReviewPage() {
    final selectedDays = [
      if (_mon) 'Mon', if (_tue) 'Tue', if (_wed) 'Wed', if (_thu) 'Thu',
      if (_fri) 'Fri', if (_sat) 'Sat', if (_sun) 'Sun',
    ];
    final selectedTimes = [
      if (_mornings) 'Mornings',
      if (_afternoons) 'Afternoons',
      if (_evenings) 'Evenings',
    ];
    final selectedSkills = [
      if (_skillBeginner) 'Beginner',
      if (_skillIntermediate) 'Intermediate',
      if (_skillAdvance) 'Advanced',
    ];
    final selectedAges = [
      if (_ageJuniors) 'Juniors',
      if (_ageStudents) 'Students',
      if (_ageAdult) 'Adults',
      if (_ageSeniors) 'Seniors',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Review & Submit',
            'Double-check before submitting', Icons.checklist_outlined),

        _buildReviewSection('Basic Details', Icons.groups_outlined, [
          _buildReviewRow('Name', _nameController.text.trim()),
          _buildReviewRow('Handle', _handleController.text.trim()),
          _buildReviewRow('Type', _orgType),
          _buildReviewRow('Description', _descController.text.trim()),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection('Location & Contact', Icons.place_outlined, [
          _buildReviewRow('Location', _locNameController.text.trim()),
          _buildReviewRow('City', _cityController.text.trim()),
          _buildReviewRow('Prefecture', _prefController.text.trim()),
          _buildReviewRow('Country', _countryController.text.trim()),
          _buildReviewRow('Email', _emailController.text.trim()),
          _buildReviewRow('Website', _websiteController.text.trim()),
          _buildReviewRow('Social', _socialController.text.trim()),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection('Schedule', Icons.calendar_today_outlined, [
          _buildReviewRow('Days',
              selectedDays.isEmpty ? '—' : selectedDays.join(', ')),
          _buildReviewRow('Times',
              selectedTimes.isEmpty ? '—' : selectedTimes.join(', ')),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection('Demographics', Icons.people_outline, [
          _buildReviewRow('Skills',
              selectedSkills.isEmpty ? '—' : selectedSkills.join(', ')),
          _buildReviewRow(
              'Ages', selectedAges.isEmpty ? '—' : selectedAges.join(', ')),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection('Media', Icons.image_outlined, [
          _buildReviewRow(
              'Image', _imageFile != null ? 'Selected ✓' : 'None'),
        ]),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _accent.withOpacity(0.4)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: _primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Your group will be submitted for review. Once approved, it will appear publicly.',
                style: TextStyle(
                  color: _textMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildReviewSection(
      String title, IconData icon, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(icon, size: 16, color: _primary),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        ),
        const Divider(height: 1, color: _border),
        ...rows,
      ]),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    final display = value.isEmpty ? '—' : value;
    final isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                color: _textLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ),
        Expanded(
          child: Text(
            display,
            style: TextStyle(
              color: isEmpty ? _textLight : _textDark,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isLast = _currentPage == _stepLabels.length - 1;
    return Container(
      color: _surface,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Row(children: [
        if (_currentPage > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
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
                    fontSize: 15,
                  )),
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
                  curve: Curves.easeInOut,
                );
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
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : Text(
              isLast ? 'Submit for Review' : 'Continue',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────
  Widget _buildPageHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
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
                      letterSpacing: -0.3,
                    )),
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
      letterSpacing: 0.2,
    ),
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
          color: _textDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          const TextStyle(color: _textLight, fontSize: 14),
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 13),
        ),
      ),
    ]);
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
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: _primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ]
              : [
            BoxShadow(
              color: _primary.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : _textMid,
            fontSize: 12,
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
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            e.value,
            if (!isLast)
              const Divider(
                  height: 1,
                  color: _border,
                  indent: 16,
                  endIndent: 16),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryRow(String label, bool value,
      ValueChanged<bool> onChanged, IconData icon) {
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
            child: Text(
              label,
              style: TextStyle(
                color: value ? _textDark : _textMid,
                fontSize: 14,
                fontWeight:
                value ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? _primary : Colors.transparent,
              border: Border.all(
                color: value ? _primary : _border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: value
                ? const Icon(Icons.check,
                size: 14, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }
}