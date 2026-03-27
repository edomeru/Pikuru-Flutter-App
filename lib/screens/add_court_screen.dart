import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// pubspec.yaml dependencies to add:
//   google_maps_flutter: ^2.5.0
//   geocoding: ^3.0.0
//   geolocator: ^11.0.0
//   image_picker: ^1.0.7
//   firebase_storage: ^11.6.0
//
// Android → AndroidManifest.xml (inside <manifest>):
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//   <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
//   <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_MAPS_KEY"/>
//
// iOS → Info.plist:
//   NSLocationWhenInUseUsageDescription → "We use your location to find nearby courts."
//   NSPhotoLibraryUsageDescription → "Select a cover photo for this court."
// iOS → AppDelegate.swift:
//   GMSServices.provideAPIKey("YOUR_MAPS_KEY")
// ─────────────────────────────────────────────────────────────────────────────

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
  bool _isUploadingImage = false;

  // ── Form Controllers ──────────────────────────────────────────────────────
  late TextEditingController _nameEnController;
  late TextEditingController _nameJpController;
  late TextEditingController _typeController;
  late TextEditingController _courtCountController;
  late TextEditingController _addressEnController;
  late TextEditingController _addressJpController;
  late TextEditingController _cityEnController;
  late TextEditingController _cityJpController;
  late TextEditingController _prefectureEnController;
  late TextEditingController _prefectureJpController;
  late TextEditingController _countryController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _googlelinkController;
  late TextEditingController _websiteController;
  late TextEditingController _contactEmailController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;
  late TextEditingController _hoursMonController;
  late TextEditingController _hoursTuesController;
  late TextEditingController _hoursWedsController;
  late TextEditingController _hoursThursController;
  late TextEditingController _hoursFriController;
  late TextEditingController _hoursSatController;
  late TextEditingController _hoursSunController;
  late TextEditingController _mapSearchController;

  // ── Form State ────────────────────────────────────────────────────────────
  String _selectedCourtType    = 'INDOOR COURTS';
  bool   _isPriceFree          = false;
  bool   _isDedicated          = false;
  bool   _requiresMembership   = false;
  bool   _hasOpenPlay          = false;
  bool   _requiresReservations = false;
  bool   _hasLessons           = false;
  bool   _hasPaddleRentals     = false;
  bool   _isPublic             = true;
  bool   _isLoading            = false;

  final List<String> _stepLabels = ['Basics', 'Location', 'Amenities', 'Hours', 'Review'];

  @override
  void initState() {
    super.initState();
    _pageController         = PageController();
    _nameEnController       = TextEditingController();
    _nameJpController       = TextEditingController();
    _typeController         = TextEditingController(text: 'Gym/Club');
    _courtCountController   = TextEditingController();
    _addressEnController    = TextEditingController();
    _addressJpController    = TextEditingController();
    _cityEnController       = TextEditingController();
    _cityJpController       = TextEditingController();
    _prefectureEnController = TextEditingController(text: 'Tokyo');
    _prefectureJpController = TextEditingController(text: '東京都');
    _countryController      = TextEditingController(text: 'Japan');
    _latitudeController     = TextEditingController();
    _longitudeController    = TextEditingController();
    _googlelinkController   = TextEditingController();
    _websiteController      = TextEditingController();
    _contactEmailController = TextEditingController();
    _priceController        = TextEditingController();
    _notesController        = TextEditingController();
    _hoursMonController     = TextEditingController();
    _hoursTuesController    = TextEditingController();
    _hoursWedsController    = TextEditingController();
    _hoursThursController   = TextEditingController();
    _hoursFriController     = TextEditingController();
    _hoursSatController     = TextEditingController();
    _hoursSunController     = TextEditingController();
    _mapSearchController    = TextEditingController();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pageController.dispose();
    for (final c in [
      _nameEnController, _nameJpController, _typeController, _courtCountController,
      _addressEnController, _addressJpController, _cityEnController, _cityJpController,
      _prefectureEnController, _prefectureJpController, _countryController,
      _latitudeController, _longitudeController, _googlelinkController,
      _websiteController, _contactEmailController, _priceController, _notesController,
      _hoursMonController, _hoursTuesController, _hoursWedsController, _hoursThursController,
      _hoursFriController, _hoursSatController, _hoursSunController, _mapSearchController,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Pick image from gallery ───────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  // ── Place a pin on the map and populate all fields ────────────────────────
  Future<void> _pinLocation(LatLng position) async {
    final lat = position.latitude.toStringAsFixed(6);
    final lng = position.longitude.toStringAsFixed(6);

    setState(() {
      _pickedLocation        = position;
      _isReverseGeocoding    = true;
      _markers = {
        Marker(
          markerId: const MarkerId('picked'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      };
      _latitudeController.text   = lat;
      _longitudeController.text  = lng;
      _googlelinkController.text =
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    });

    await _reverseGeocode(position.latitude, position.longitude);
  }

  // ── Reverse geocode using the native geocoding package ────────────────────
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          final street = [p.subThoroughfare, p.thoroughfare]
              .where((s) => s != null && s.isNotEmpty)
              .join(' ');
          if (street.isNotEmpty) _addressEnController.text = street;

          if ((p.locality ?? '').isNotEmpty)
            _cityEnController.text = p.locality!;
          else if ((p.subAdministrativeArea ?? '').isNotEmpty)
            _cityEnController.text = p.subAdministrativeArea!;

          if ((p.administrativeArea ?? '').isNotEmpty)
            _prefectureEnController.text = p.administrativeArea!;

          if ((p.country ?? '').isNotEmpty)
            _countryController.text = p.country!;
        });
      }
    } catch (_) {
      // Device geocoder unavailable — user fills manually
    } finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  // ── Search using the native geocoding package ─────────────────────────────
  Future<void> _searchLocation(String query) async {
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
          CameraUpdate.newLatLngZoom(pos, 13),
        );

        await Future.delayed(const Duration(milliseconds: 400));
        await _pinLocation(pos);
      } else {
        _showSnack('Location not found — try a different search.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Could not find "$trimmed". Try adding a country or city.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  // ── Use device GPS location ───────────────────────────────────────────────
  Future<void> _useMyLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        _showSnack('Location permission denied.', isError: true);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latlng, 16));
      await _pinLocation(latlng);
    } catch (_) {
      if (mounted) _showSnack('Could not get your location.', isError: true);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── Submit to Firestore ───────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (_nameEnController.text.isEmpty || _googlelinkController.text.isEmpty) {
      _showSnack('Please fill in required fields', isError: false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Upload cover image if selected
      String imageUrl = '';
      if (_pickedImage != null) {
        setState(() => _isUploadingImage = true);
        final fileRef = FirebaseStorage.instance.ref(
          'loc_images/${DateTime.now().millisecondsSinceEpoch}_${_pickedImage!.path.split('/').last}',
        );
        final snapshot = await fileRef.putFile(_pickedImage!);
        imageUrl = await snapshot.ref.getDownloadURL();
        if (mounted) setState(() => _isUploadingImage = false);
      }

      await FirebaseFirestore.instance.collection('locations').add({
        'loc_active': true,
        'loc_added': true,
        'loc_addedby': true,
        'loc_address_en': _addressEnController.text,
        'loc_address_jp': _addressJpController.text,
        'loc_amenities_dedicated': _isDedicated,
        'loc_amenities_lessons': _hasLessons,
        'loc_amenities_membership': _requiresMembership ? 'Required' : '',
        'loc_amenities_openplay': _hasOpenPlay,
        'loc_amenities_paddlerentals': _hasPaddleRentals,
        'loc_amenities_reservation': _requiresReservations,
        'loc_checked': false,
        'loc_city_en': _cityEnController.text,
        'loc_city_jp': _cityJpController.text,
        'loc_contact_email': _contactEmailController.text,
        'loc_country': _countryController.text,
        'loc_court_count': int.tryParse(_courtCountController.text) ?? 0,
        'loc_court_type_indoor':
        _selectedCourtType == 'INDOOR COURTS' || _selectedCourtType == 'INDOOR/OUTDOOR COURTS',
        'loc_court_type_outdoor':
        _selectedCourtType == 'OUTDOOR COURTS' || _selectedCourtType == 'INDOOR/OUTDOOR COURTS',
        'loc_created_at': DateTime.now().toIso8601String(),
        'loc_googlelink': _googlelinkController.text,
        'loc_hours_fri': _hoursFriController.text,
        'loc_hours_mon': _hoursMonController.text,
        'loc_hours_sat': _hoursSatController.text,
        'loc_hours_sun': _hoursSunController.text,
        'loc_hours_thurs': _hoursThursController.text,
        'loc_hours_tues': _hoursTuesController.text,
        'loc_hours_weds': _hoursWedsController.text,
        'loc_image': imageUrl,
        'loc_latitude': _latitudeController.text,
        'loc_longitude': _longitudeController.text,
        'loc_name': _nameEnController.text,
        'loc_name_jp': _nameJpController.text,
        'loc_notes': _notesController.text,
        'loc_org_id': '',
        'loc_prefecture_en': _prefectureEnController.text,
        'loc_prefecture_jp': _prefectureJpController.text,
        'loc_price': _priceController.text,
        'loc_price_free': _isPriceFree,
        'loc_public': _isPublic,
        'loc_type': _typeController.text,
        'loc_updated_at': DateTime.now().toIso8601String(),
        'loc_website': _websiteController.text,
      });
      if (mounted) {
        _showSnack('Court added successfully!');
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
      backgroundColor: isError ? Colors.red.shade400 : _primary,
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
              boxShadow: [BoxShadow(color: _primary.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          const Text('Add a Court',
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
              _buildBasicInfoPage(),
              _buildLocationPage(),
              _buildAmenitiesPage(),
              _buildHoursPage(),
              _buildSummaryPage(),
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

  // ── Page 1: Basic Info ────────────────────────────────────────────────────
  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Basic Information', 'Tell us about the court', Icons.sports_tennis),
        _buildTextField(label: 'Court Name (EN) *', controller: _nameEnController, hint: 'e.g. WELL RACKET CLUB'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Court Name (JP)', controller: _nameJpController, hint: 'e.g. ウェルラケットクラブ'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Location Type', controller: _typeController, hint: 'e.g. Gym/Club'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Number of Courts', controller: _courtCountController, hint: 'e.g. 4', keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        _buildCheckbox('Publicly Listed', _isPublic, (v) => setState(() => _isPublic = v ?? false)),
        const SizedBox(height: 24),

        // ── Cover Picture ─────────────────────────────────────────────────
        _buildLabel('Cover Picture'),
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
              boxShadow: [BoxShadow(color: _primary.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            clipBehavior: Clip.hardEdge,
            child: _pickedImage != null
                ? Stack(fit: StackFit.expand, children: [
              Image.file(_pickedImage!, fit: BoxFit.cover),
              // Overlay with "tap to change"
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.black.withOpacity(0.45),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text('Tap to change',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(color: _textDark, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 12),
              const Text('Select an Image',
                  style: TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'This will be used as the location\'s cover photo in listings.',
                  style: TextStyle(color: _textLight, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Page 2: Location ──────────────────────────────────────────────────────
  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Location Details', 'Search or tap the map to set coordinates', Icons.place_outlined),

        // ── Map card ───────────────────────────────────────────────────────
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [BoxShadow(color: _primary.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(children: [

            // Google Map
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _defaultCenter, zoom: 12),
              onMapCreated: (c) => _mapController = c,
              onTap: _pinLocation,
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

            // ── Search bar overlay ─────────────────────────────────────────
            Positioned(
              top: 12, left: 12, right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  controller: _mapSearchController,
                  style: const TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w500),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchLocation,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. "Paris, France" or "Shibuya, Tokyo"',
                    hintStyle: const TextStyle(color: _textLight, fontSize: 13),
                    prefixIcon: _isSearchLoading
                        ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_accent),
                        ),
                      ),
                    )
                        : const Icon(Icons.search_rounded, color: _accent, size: 20),
                    suffixIcon: _mapSearchController.text.isNotEmpty && !_isSearchLoading
                        ? IconButton(
                      icon: const Icon(Icons.close, color: _textLight, size: 18),
                      onPressed: () { _mapSearchController.clear(); setState(() {}); },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // ── "Use my location" button ───────────────────────────────────
            Positioned(
              top: 72, right: 12,
              child: GestureDetector(
                onTap: _isLocating ? null : _useMyLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                  ),
                  child: _isLocating
                      ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_accent)),
                  )
                      : const Icon(Icons.my_location_rounded, color: _primary, size: 20),
                ),
              ),
            ),

            // ── "Tap to pin" hint ──────────────────────────────────────────
            if (_pickedLocation == null && !_isSearchLoading)
              Positioned(
                bottom: 12, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _textDark.withOpacity(0.82),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, color: _accent, size: 16),
                        SizedBox(width: 6),
                        Text('Tap the map to place a pin',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Reverse geocoding spinner ──────────────────────────────────
            if (_isReverseGeocoding)
              Positioned(
                bottom: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_accent))),
                    SizedBox(width: 8),
                    Text('Getting address...', style: TextStyle(color: _textMid, fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
          ]),
        ),

        // ── Info / success banner ──────────────────────────────────────────
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(
              _pickedLocation != null ? Icons.check_circle_outline : Icons.info_outline,
              size: 16, color: _primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _pickedLocation != null
                    ? 'Coordinates & address auto-filled. Edit below if needed.'
                    : 'Search a city above or tap the map to auto-fill all fields.',
                style: const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Auto-populated + manual fields ─────────────────────────────────
        _buildTextField(
          label: 'Google Maps Link *',
          controller: _googlelinkController,
          hint: 'https://www.google.com/maps/...',
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _buildTextField(
            label: 'Latitude', controller: _latitudeController, hint: '35.791',
            keyboardType: TextInputType.number,
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(
            label: 'Longitude', controller: _longitudeController, hint: '139.852',
            keyboardType: TextInputType.number,
          )),
        ]),
        const SizedBox(height: 14),
        _buildTextField(label: 'Address (EN)', controller: _addressEnController, hint: '6 Chome-5-1 Nishimizumoto...'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Address (JP)', controller: _addressJpController, hint: '〒125-0031 東京都...'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _buildTextField(label: 'City (EN)', controller: _cityEnController, hint: 'Katsushika')),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(label: 'City (JP)', controller: _cityJpController, hint: '葛飾区')),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _buildTextField(label: 'Prefecture (EN)', controller: _prefectureEnController, hint: 'Tokyo')),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(label: 'Prefecture (JP)', controller: _prefectureJpController, hint: '東京都')),
        ]),
        const SizedBox(height: 14),
        _buildTextField(label: 'Country', controller: _countryController, hint: 'Japan'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Website', controller: _websiteController, hint: 'https://example.com'),
        const SizedBox(height: 14),
        _buildTextField(label: 'Contact Email', controller: _contactEmailController, hint: 'https://example.com/contact'),
      ]),
    );
  }

  // ── Page 3: Amenities ─────────────────────────────────────────────────────
  Widget _buildAmenitiesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Court Type & Amenities', 'What does this venue offer?', Icons.star_outline),
        _buildLabel('Court Type *'),
        const SizedBox(height: 10),
        _buildCourtTypeSelector(),
        const SizedBox(height: 22),
        _buildLabel('Pricing'),
        const SizedBox(height: 10),
        _buildTextField(label: 'Price Info', controller: _priceController, hint: '¥4,000+ per hour'),
        const SizedBox(height: 10),
        _buildCheckbox('Courts are Free', _isPriceFree, (v) => setState(() => _isPriceFree = v ?? false)),
        const SizedBox(height: 22),
        _buildLabel('Amenities'),
        const SizedBox(height: 10),
        _buildCheckbox('Dedicated Pickleball Court', _isDedicated, (v) => setState(() => _isDedicated = v ?? false)),
        const SizedBox(height: 8),
        _buildCheckbox('Requires Membership', _requiresMembership, (v) => setState(() => _requiresMembership = v ?? false)),
        const SizedBox(height: 8),
        _buildCheckbox('Open Play Available', _hasOpenPlay, (v) => setState(() => _hasOpenPlay = v ?? false)),
        const SizedBox(height: 8),
        _buildCheckbox('Reservations Required', _requiresReservations, (v) => setState(() => _requiresReservations = v ?? false)),
        const SizedBox(height: 8),
        _buildCheckbox('Lessons Available', _hasLessons, (v) => setState(() => _hasLessons = v ?? false)),
        const SizedBox(height: 8),
        _buildCheckbox('Paddle Rentals', _hasPaddleRentals, (v) => setState(() => _hasPaddleRentals = v ?? false)),
      ]),
    );
  }

  // ── Page 4: Hours ─────────────────────────────────────────────────────────
  Widget _buildHoursPage() {
    final days = [
      ('Monday',    _hoursMonController),
      ('Tuesday',   _hoursTuesController),
      ('Wednesday', _hoursWedsController),
      ('Thursday',  _hoursThursController),
      ('Friday',    _hoursFriController),
      ('Saturday',  _hoursSatController),
      ('Sunday',    _hoursSunController),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Operating Hours', 'When is the court open?', Icons.schedule_outlined),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: _primary),
            const SizedBox(width: 8),
            const Text('Format: HH:MM-HH:MM  (e.g. 09:00-22:00)',
                style: TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
        ...days.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTextField(label: d.$1, controller: d.$2, hint: '09:00-22:00'),
        )),
        const SizedBox(height: 8),
        _buildTextField(label: 'Additional Notes', controller: _notesController,
            hint: 'e.g. online contact required', maxLines: 4),
      ]),
    );
  }

  // ── Page 5: Summary ───────────────────────────────────────────────────────
  Widget _buildSummaryPage() {
    final amenities = [
      if (_isDedicated)          'Dedicated Court',
      if (_requiresMembership)   'Requires Membership',
      if (_hasOpenPlay)          'Open Play',
      if (_requiresReservations) 'Reservations',
      if (_hasLessons)           'Lessons',
      if (_hasPaddleRentals)     'Paddle Rentals',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader('Review & Submit', 'Everything look good?', Icons.check_circle_outline),

        // ── Cover image preview in summary ─────────────────────────────────
        if (_pickedImage != null) ...[
          _buildLabel('Cover Picture'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              _pickedImage!,
              width: double.infinity,
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
        ],

        _buildSummarySection('Court', [
          ('Name',   _nameEnController.text.isEmpty ? '—' : _nameEnController.text),
          ('Type',   _typeController.text.isEmpty ? '—' : _typeController.text),
          ('Courts', _courtCountController.text.isEmpty ? '—' : _courtCountController.text),
        ]),
        const SizedBox(height: 12),
        _buildSummarySection('Location', [
          ('Lat',        _latitudeController.text.isEmpty ? '—' : _latitudeController.text),
          ('Lng',        _longitudeController.text.isEmpty ? '—' : _longitudeController.text),
          ('City',       _cityEnController.text.isEmpty ? '—' : _cityEnController.text),
          ('Prefecture', _prefectureEnController.text.isEmpty ? '—' : _prefectureEnController.text),
        ]),
        const SizedBox(height: 12),
        _buildSummarySection('Pricing', [
          ('Price',      _isPriceFree ? 'Free' : (_priceController.text.isEmpty ? '—' : _priceController.text)),
          ('Court Type', _selectedCourtType),
        ]),
        if (amenities.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildLabel('Amenities'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: amenities.map(_buildAmenityBadge).toList()),
        ],
        const SizedBox(height: 24),

        // ── Upload progress indicator ──────────────────────────────────────
        if (_isUploadingImage) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_primary))),
              SizedBox(width: 12),
              Text('Uploading cover image...', style: TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 18, color: _primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'By submitting, you agree that this information will be reviewed by our team before appearing on the app.',
                style: TextStyle(color: _textMid, fontSize: 13, height: 1.5),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
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
              if (_currentPage == 4) {
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
              _currentPage == 4 ? 'Submit Court' : 'Continue',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────
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
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                color: _textDark, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: _textLight, fontSize: 12)),
          ]),
        ),
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
          filled: true,
          fillColor: _surface,
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border, width: 1)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    ]);
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? _accentSoft : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? _accent : _border, width: value ? 1.5 : 1),
          boxShadow: [BoxShadow(color: _primary.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: value ? _primary : Colors.transparent,
              border: Border.all(color: value ? _primary : _border, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: value ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(
              color: value ? _textDark : _textMid,
              fontSize: 14,
              fontWeight: value ? FontWeight.w600 : FontWeight.w500,
            )),
          ),
        ]),
      ),
    );
  }

  Widget _buildCourtTypeSelector() {
    final labels = ['INDOOR\nCOURTS', 'OUTDOOR\nCOURTS', 'INDOOR/\nOUTDOOR'];
    final values = ['INDOOR COURTS', 'OUTDOOR COURTS', 'INDOOR/OUTDOOR COURTS'];
    return Row(
      children: List.generate(3, (i) {
        final isSelected = _selectedCourtType == values[i];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedCourtType = values[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? _primary : _surface,
                border: Border.all(color: isSelected ? _primary : _border, width: isSelected ? 1.5 : 1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [BoxShadow(color: _primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: _primary.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Text(labels[i], textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _textLight,
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3, height: 1.4,
                  )),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSummarySection(String title, List<(String, String)> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(title, style: const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
        const Divider(height: 1, color: _border),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(r.$1, style: const TextStyle(color: _textLight, fontSize: 13, fontWeight: FontWeight.w500)),
            Flexible(child: Text(r.$2,
                style: const TextStyle(color: _textDark, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.end)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildAmenityBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _accentSoft, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.4)),
      ),
      child: Text(label, style: const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}