import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';

class HealthTrackingScreen extends StatefulWidget {
  final int? childId;
  final String title;
  final bool isParentContext;

  const HealthTrackingScreen({
    super.key,
    required this.title,
    this.childId,
    this.isParentContext = false,
  });

  @override
  State<HealthTrackingScreen> createState() => _HealthTrackingScreenState();
}

class _HealthTrackingScreenState extends State<HealthTrackingScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _headController = TextEditingController();
  final _immunizationController = TextEditingController();
  final _milestonesController = TextEditingController();
  final _foodQuantityController = TextEditingController(text: '100');

  Future<List<BackendChild>>? _childrenFuture;
  Future<Map<String, dynamic>>? _growthFuture;
  Future<Map<String, dynamic>>? _nutritionFuture;
  Future<List<String>>? _foodsFuture;
  Future<Map<String, dynamic>>? _emailPrefsFuture;
  Future<int>? _childAgeFuture;

  int? _selectedChildId;
  String? _selectedFood;
  String _mealType = 'main';
  String _nutritionDate = _todayKey;
  bool _savingGrowth = false;
  bool _savingNutrition = false;
  bool _savingPrefs = false;
  bool _weeklyRecap = true;
  bool _alerts = true;
  bool _notifyDeviations = true;

  static String get _todayKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.childId;
    _initialize();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _headController.dispose();
    _immunizationController.dispose();
    _milestonesController.dispose();
    _foodQuantityController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (widget.isParentContext && widget.childId == null) {
      _childrenFuture = BackendApiService.getChildren();
      try {
        final children = await _childrenFuture!;
        if (!mounted) return;
        if (children.isNotEmpty) {
          _selectedChildId = children.first.id;
          _loadChildData();
        }
      } catch (_) {
        // Keep screen usable even if children list fails.
      }
    } else {
      _loadChildData();
    }

    if (widget.isParentContext) {
      _emailPrefsFuture = BackendApiService.getEmailPreferences();
      _emailPrefsFuture!
          .then((prefs) {
            if (!mounted) return;
            setState(() {
              _weeklyRecap =
                  prefs['weekly_recap'] == true || prefs['weeklyRecap'] == true;
              _alerts = prefs['alerts'] == true;
              _notifyDeviations =
                  prefs['notify_deviations'] == true ||
                  prefs['notifyDeviations'] == true;
            });
          })
          .catchError((_) {});
    }
  }

  void _loadChildData() {
    final childId = _selectedChildId;
    if (childId == null) return;
    setState(() {
      _growthFuture = BackendApiService.getGrowthBundle(childId);
      _nutritionFuture = BackendApiService.getDailyNutritionAnalysis(
        childId: childId,
        date: _nutritionDate,
      );
      _foodsFuture = BackendApiService.getNutritionFoods();
      _childAgeFuture = _resolveSelectedChildAge();
    });
    _foodsFuture
        ?.then((foods) {
          if (!mounted || foods.isEmpty || _selectedFood != null) return;
          setState(() => _selectedFood = foods.first);
        })
        .catchError((_) {});
  }

  Future<void> _pickNutritionDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _nutritionDate =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      final childId = _selectedChildId;
      if (childId != null) {
        _nutritionFuture = BackendApiService.getDailyNutritionAnalysis(
          childId: childId,
          date: _nutritionDate,
        );
      }
    });
  }

  Future<void> _submitGrowth() async {
    final childId = _selectedChildId;
    if (childId == null) return;

    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final head = double.tryParse(_headController.text.trim());

    if (height == null || weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tinggi dan berat harus diisi dengan angka.'),
        ),
      );
      return;
    }

    setState(() => _savingGrowth = true);
    try {
      await BackendApiService.createGrowthRecord(
        childId: childId,
        heightCm: height,
        weightKg: weight,
        headCircumferenceCm: head,
        immunizationNotes: _immunizationController.text.trim(),
        milestonesNotes: _milestonesController.text.trim(),
      );
      if (!mounted) return;
      _loadChildData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data pertumbuhan tersimpan.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal simpan growth: $e')));
    } finally {
      if (mounted) setState(() => _savingGrowth = false);
    }
  }

  Future<int> _resolveSelectedChildAge() async {
    final childId = _selectedChildId;
    if (childId == null) return 0;

    try {
      final analytics = await BackendApiService.getChildAnalytics(childId);
      return analytics.child.umur;
    } catch (_) {
      try {
        final children = await BackendApiService.getChildren();
        final match = children.where((child) => child.id == childId).toList();
        if (match.isNotEmpty) {
          return match.first.umur;
        }
      } catch (_) {
        // Ignore fallback lookup failures.
      }
    }

    return 0;
  }

  Future<void> _submitNutrition() async {
    final childId = _selectedChildId;
    if (childId == null) return;
    final food = _selectedFood;
    final qty = double.tryParse(_foodQuantityController.text.trim());
    if (food == null || food.isEmpty || qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih makanan dan jumlah yang valid.')),
      );
      return;
    }

    setState(() => _savingNutrition = true);
    try {
      await BackendApiService.recordFoodIntake(
        childId: childId,
        foodName: food,
        quantityGrams: qty,
        mealType: _mealType,
      );
      if (!mounted) return;
      setState(() {
        _nutritionFuture = BackendApiService.getDailyNutritionAnalysis(
          childId: childId,
          date: _nutritionDate,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asupan makanan tersimpan.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal simpan nutrisi: $e')));
    } finally {
      if (mounted) setState(() => _savingNutrition = false);
    }
  }

  Future<void> _saveEmailPreferences() async {
    if (!widget.isParentContext) return;
    setState(() => _savingPrefs = true);
    try {
      await BackendApiService.updateEmailPreferences(
        weeklyRecap: _weeklyRecap,
        alerts: _alerts,
        notifyDeviations: _notifyDeviations,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferensi email diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal update preferensi email: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  Future<void> _refreshAll() async {
    if (widget.isParentContext && widget.childId == null) {
      _childrenFuture = BackendApiService.getChildren();
      final children = await _childrenFuture!;
      if (children.isNotEmpty && _selectedChildId == null) {
        _selectedChildId = children.first.id;
      }
    }
    if (_selectedChildId != null) {
      _loadChildData();
    }
    if (widget.isParentContext) {
      _emailPrefsFuture = BackendApiService.getEmailPreferences();
    }
    setState(() {});
  }

  String _resolveStatus(Map<String, dynamic>? assessment) {
    if (assessment == null) return 'Belum ada penilaian';
    final warnings = (assessment['warnings'] as List?)?.length ?? 0;
    if (warnings > 0) return 'Ada $warnings peringatan';
    final height = assessment['height_status'] ?? assessment['heightStatus'];
    final weight = assessment['weight_status'] ?? assessment['weightStatus'];
    final bmi = assessment['bmi_status'] ?? assessment['bmiStatus'];
    return 'Tinggi: $height | Berat: $weight | BMI: $bmi';
  }

  Color _statusColor(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('peringatan') ||
        lower.contains('di bawah') ||
        lower.contains('below')) {
      return const Color(0xFFC62828);
    }
    if (lower.contains('normal') || lower.contains('baik')) {
      return const Color(0xFF2E7D32);
    }
    return const Color(0xFF6D4C41);
  }

  String _ageGroupForAge(int age) {
    if (age <= 1) return 'baby';
    if (age <= 3) return 'toddler';
    if (age <= 12) return 'anak';
    return 'remaja';
  }

  String _ageGroupTitle(String ageGroup) {
    switch (ageGroup) {
      case 'baby':
        return 'Bayi (0-1 tahun)';
      case 'toddler':
        return 'Toddler (1-2 tahun)';
      case 'anak':
        return 'Anak (6-12 tahun)';
      case 'remaja':
        return 'Anak Lanjutan (13-17 tahun)';
      default:
        return 'Fitur Usia';
    }
  }

  String _ageGroupSummary(String ageGroup) {
    switch (ageGroup) {
      case 'baby':
        return 'Pantau pertumbuhan, imunisasi, nutrisi dasar, milestone, dan recap mingguan.';
      case 'toddler':
        return 'Catat kemandirian awal, bahasa & sosial, aktivitas motorik, dan recap perkembangan.';
      case 'anak':
        return 'Kelola pertumbuhan, akademik, sosial-emosional, aktivitas fisik, dan kebiasaan sehat.';
      case 'remaja':
        return 'Pantau pubertas, nutrisi, kesehatan mental, akademik, dan rencana masa depan.';
      default:
        return 'Sesuaikan fitur berdasarkan usia anak yang dipilih.';
    }
  }

  List<_AgeFeatureAction> _ageActions(String ageGroup) {
    switch (ageGroup) {
      case 'baby':
        return const [
          _AgeFeatureAction(
            title: 'Imunisasi & kesehatan',
            subtitle: 'Catat jadwal vaksin dan kunjungan dokter',
            activityType: 'baby_immunization',
            promptLabel: 'Catatan imunisasi / dokter',
            hintText: 'Contoh: DPT lengkap, kontrol tumbuh kembang besok',
            icon: Icons.vaccines_outlined,
          ),
          _AgeFeatureAction(
            title: 'Nutrisi dasar',
            subtitle: 'ASI, formula, dan pengenalan MPASI',
            activityType: 'baby_nutrition',
            promptLabel: 'Catatan nutrisi bayi',
            hintText: 'Contoh: ASI 8x, formula 180 ml, MPASI labu',
            icon: Icons.child_friendly_outlined,
          ),
          _AgeFeatureAction(
            title: 'Milestone motorik & sensorik',
            subtitle: 'Kepala tegak, duduk, merangkak, senyum sosial',
            activityType: 'baby_milestone',
            promptLabel: 'Milestone bayi',
            hintText: 'Contoh: Sudah bisa tengkurap 5 menit',
            icon: Icons.motion_photos_on_outlined,
          ),
        ];
      case 'toddler':
        return const [
          _AgeFeatureAction(
            title: 'Kemandirian awal',
            subtitle: 'Toilet training, makan sendiri, pilih pakaian',
            activityType: 'toddler_independence',
            promptLabel: 'Catatan kemandirian',
            hintText: 'Contoh: Sukses toilet training pagi ini',
            icon: Icons.self_improvement_outlined,
          ),
          _AgeFeatureAction(
            title: 'Bahasa & sosial',
            subtitle: 'Kosakata baru, interaksi, kemampuan berbicara',
            activityType: 'toddler_language_social',
            promptLabel: 'Catatan bahasa & sosial',
            hintText: 'Contoh: Menyebut 15 kosakata baru hari ini',
            icon: Icons.record_voice_over_outlined,
          ),
          _AgeFeatureAction(
            title: 'Aktivitas & motorik',
            subtitle: 'Jalan, lari, lempar-tangkap, bermain aktif',
            activityType: 'toddler_motor_activity',
            promptLabel: 'Catatan aktivitas motorik',
            hintText: 'Contoh: Bermain bola 20 menit di halaman',
            icon: Icons.directions_run_outlined,
          ),
        ];
      case 'anak':
        return const [
          _AgeFeatureAction(
            title: 'Akademik & kognitif',
            subtitle: 'Catatan belajar, pencapaian sekolah, hobi',
            activityType: 'anak_academic',
            promptLabel: 'Catatan akademik',
            hintText: 'Contoh: Selesai PR matematika dan membaca 20 menit',
            icon: Icons.menu_book_outlined,
          ),
          _AgeFeatureAction(
            title: 'Sosial & emosional',
            subtitle: 'Kerja sama, empati, regulasi emosi',
            activityType: 'anak_social_emotional',
            promptLabel: 'Catatan sosial & emosional',
            hintText: 'Contoh: Berhasil bergiliran saat bermain',
            icon: Icons.favorite_border,
          ),
          _AgeFeatureAction(
            title: 'Aktivitas fisik & hobi',
            subtitle: 'Olahraga, seni, screen time, minat khusus',
            activityType: 'anak_activity_hobby',
            promptLabel: 'Catatan aktivitas & hobi',
            hintText: 'Contoh: Berenang 30 menit, screen time 45 menit',
            icon: Icons.sports_soccer_outlined,
          ),
        ];
      case 'remaja':
        return const [
          _AgeFeatureAction(
            title: 'Pubertas & pertumbuhan',
            subtitle: 'Perubahan tubuh, menstruasi, BMI, tinggi & berat',
            activityType: 'remaja_puberty',
            promptLabel: 'Catatan pubertas & pertumbuhan',
            hintText: 'Contoh: Menstruasi teratur, tinggi bertambah 1 cm',
            icon: Icons.accessibility_new_outlined,
          ),
          _AgeFeatureAction(
            title: 'Kesehatan mental & sosial',
            subtitle: 'Stres, self-esteem, interaksi sosial, media sosial',
            activityType: 'remaja_mental_health',
            promptLabel: 'Catatan kesehatan mental',
            hintText: 'Contoh: Stres ujian sedang, perlu jeda 15 menit',
            icon: Icons.psychology_outlined,
          ),
          _AgeFeatureAction(
            title: 'Akademik & masa depan',
            subtitle: 'Nilai, target karier, tanggung jawab pribadi',
            activityType: 'remaja_future_plan',
            promptLabel: 'Catatan akademik / masa depan',
            hintText: 'Contoh: Target rapor naik dan eksplorasi jurusan',
            icon: Icons.workspace_premium_outlined,
          ),
        ];
      default:
        return const [];
    }
  }

  Future<void> _logAgeFeature(_AgeFeatureAction action) async {
    final childId = _selectedChildId;
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih anak terlebih dahulu.')),
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action.promptLabel),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: action.hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();

    final note = result?.trim() ?? '';
    if (note.isEmpty) return;

    try {
      await BackendApiService.logActivity(
        childId: childId,
        activityType: action.activityType,
        value: note,
      );
      if (!mounted) return;
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${action.title} tersimpan.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal simpan ${action.title}: $e')),
      );
    }
  }

  Widget _buildAgeSpecificSection() {
    final ageFuture = _childAgeFuture ?? Future<int>.value(0);

    return FutureBuilder<int>(
      future: ageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _sectionCard(
            title: 'Fitur Usia Spesifik',
            icon: Icons.child_care_outlined,
            child: const LinearProgressIndicator(minHeight: 2),
          );
        }

        final age = snapshot.data ?? 0;
        final ageGroup = _ageGroupForAge(age);
        final actions = _ageActions(ageGroup);

        if (actions.isEmpty) {
          return _sectionCard(
            title: 'Fitur Usia Spesifik',
            icon: Icons.child_care_outlined,
            child: const Text(
              'Pilih anak agar fitur usia yang relevan muncul di sini.',
            ),
          );
        }

        return _sectionCard(
          title: _ageGroupTitle(ageGroup),
          icon: Icons.child_care_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_ageGroupSummary(ageGroup)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions
                    .map(
                      (action) => Chip(
                        avatar: Icon(action.icon, size: 16),
                        label: Text(action.title),
                        backgroundColor: const Color(0xFFFCE4EC),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              ...actions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _logAgeFeature(action),
                        icon: Icon(action.icon),
                        label: Text(action.title),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          foregroundColor: const Color(0xFFF06292),
                          side: const BorderSide(color: Color(0xFFF0C5DA)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData icon = Icons.circle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D7E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFF06292)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildChildSelector() {
    if (!widget.isParentContext && widget.childId != null) {
      return Chip(
        label: Text('Anak aktif: #${widget.childId}'),
        backgroundColor: const Color(0xFFFCE4EC),
      );
    }

    return FutureBuilder<List<BackendChild>>(
      future: _childrenFuture,
      builder: (context, snapshot) {
        final children = snapshot.data ?? const <BackendChild>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        if (children.isEmpty) {
          return const Text(
            'Belum ada anak terhubung. Tambahkan anak dulu agar growth dan nutrisi bisa dicatat.',
            style: TextStyle(color: Colors.black54),
          );
        }

        return DropdownButtonFormField<int>(
          value: _selectedChildId,
          decoration: const InputDecoration(
            labelText: 'Pilih anak',
            border: OutlineInputBorder(),
          ),
          items: children
              .map(
                (child) => DropdownMenuItem<int>(
                  value: child.id,
                  child: Text('${child.nama} (${child.umur} th)'),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedChildId = value;
            });
            _loadChildData();
          },
        );
      },
    );
  }

  Widget _buildGrowthSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _growthFuture,
      builder: (context, snapshot) {
        final bundle = snapshot.data ?? const <String, dynamic>{};
        final records = (bundle['records'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        final assessment = bundle['latest_assessment'] is Map
            ? Map<String, dynamic>.from(bundle['latest_assessment'] as Map)
            : null;

        final recent = records.take(6).toList(growable: false);
        final maxHeight = recent.isEmpty
            ? 1.0
            : recent
                  .map((e) => (e['height_cm'] as num?)?.toDouble() ?? 0)
                  .fold<double>(0, math.max)
                  .clamp(1.0, double.infinity);
        final maxWeight = recent.isEmpty
            ? 1.0
            : recent
                  .map((e) => (e['weight_kg'] as num?)?.toDouble() ?? 0)
                  .fold<double>(0, math.max)
                  .clamp(1.0, double.infinity);

        return _sectionCard(
          title: 'Growth Tracking',
          icon: Icons.monitor_weight_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChildSelector(),
              const SizedBox(height: 12),
              TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tinggi badan (cm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Berat badan (kg)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _headController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Lingkar kepala (cm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _immunizationController,
                decoration: const InputDecoration(
                  labelText: 'Catatan imunisasi',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _milestonesController,
                decoration: const InputDecoration(
                  labelText: 'Milestones',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savingGrowth ? null : _submitGrowth,
                  icon: _savingGrowth
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Simpan growth'),
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(minHeight: 2),
              if (snapshot.hasError)
                Text(
                  'Gagal memuat growth: ${snapshot.error}',
                  style: const TextStyle(color: Color(0xFFC62828)),
                ),
              if (bundle.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF0C5DA)),
                  ),
                  child: Text(
                    _resolveStatus(assessment),
                    style: TextStyle(
                      color: _statusColor(_resolveStatus(assessment)),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (assessment != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statusChip(
                        'Height-for-age',
                        (assessment['height_status'] ??
                                    assessment['heightStatus'])
                                ?.toString() ??
                            'n/a',
                      ),
                      _statusChip(
                        'Weight-for-age',
                        (assessment['weight_status'] ??
                                    assessment['weightStatus'])
                                ?.toString() ??
                            'n/a',
                      ),
                      _statusChip(
                        'BMI',
                        (assessment['bmi_status'] ?? assessment['bmiStatus'])
                                ?.toString() ??
                            'n/a',
                      ),
                    ],
                  ),
                if ((assessment?['warnings'] as List?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  ...(assessment?['warnings'] as List).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${item.toString()}',
                        style: const TextStyle(color: Color(0xFFC62828)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Grafik pertumbuhan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const Text('Belum ada history growth.')
                else
                  Column(
                    children: recent
                        .map((record) {
                          final height =
                              (record['height_cm'] as num?)?.toDouble() ?? 0;
                          final weight =
                              (record['weight_kg'] as num?)?.toDouble() ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record['created_at']?.toString() ?? '-',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Height-for-age: ${height.toStringAsFixed(1)} cm',
                                          ),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: (height / maxHeight).clamp(
                                                0,
                                                1,
                                              ),
                                              minHeight: 7,
                                              color: const Color(0xFFF06292),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Weight-for-age: ${weight.toStringAsFixed(1)} kg',
                                          ),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: (weight / maxWeight).clamp(
                                                0,
                                                1,
                                              ),
                                              minHeight: 7,
                                              color: const Color(0xFF7E57C2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statusChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: const Color(0xFFFCE4EC),
    );
  }

  Widget _buildNutritionSection() {
    return FutureBuilder<List<String>>(
      future: _foodsFuture,
      builder: (context, foodSnapshot) {
        final foods = foodSnapshot.data ?? const <String>[];
        final selectedFood =
            _selectedFood ?? (foods.isNotEmpty ? foods.first : null);

        return FutureBuilder<Map<String, dynamic>>(
          future: _nutritionFuture,
          builder: (context, snapshot) {
            final data = snapshot.data ?? const <String, dynamic>{};
            final daily = data['daily_nutrition'] is Map
                ? Map<String, dynamic>.from(data['daily_nutrition'] as Map)
                : const <String, dynamic>{};
            final validation = data['validation'] is Map
                ? Map<String, dynamic>.from(data['validation'] as Map)
                : const <String, dynamic>{};

            return _sectionCard(
              title: 'Menu Makanan & Nutrisi',
              icon: Icons.restaurant_menu_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal analisis: $_nutritionDate',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickNutritionDate,
                          icon: const Icon(Icons.date_range_outlined),
                          label: const Text('Pilih tanggal'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loadChildData,
                          icon: const Icon(Icons.refresh_outlined),
                          label: const Text('Refresh'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedFood,
                    decoration: const InputDecoration(
                      labelText: 'Jenis makanan',
                      border: OutlineInputBorder(),
                    ),
                    items: foods
                        .map(
                          (food) => DropdownMenuItem<String>(
                            value: food,
                            child: Text(food),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() => _selectedFood = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _foodQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah (gram)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _mealType,
                    decoration: const InputDecoration(
                      labelText: 'Frekuensi / meal type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'breakfast',
                        child: Text('Breakfast'),
                      ),
                      DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                      DropdownMenuItem(value: 'snack', child: Text('Snack')),
                      DropdownMenuItem(value: 'main', child: Text('Main meal')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _mealType = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _savingNutrition ? null : _submitNutrition,
                      icon: _savingNutrition
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_circle_outline),
                      label: const Text('Simpan asupan makanan'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (foodSnapshot.connectionState == ConnectionState.waiting)
                    const LinearProgressIndicator(minHeight: 2),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const LinearProgressIndicator(minHeight: 2),
                  if (snapshot.hasError)
                    Text(
                      'Gagal memuat nutrisi: ${snapshot.error}',
                      style: const TextStyle(color: Color(0xFFC62828)),
                    ),
                  if (daily.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metricChip(
                          'Kalori',
                          '${daily['total_calories'] ?? 0} kcal',
                        ),
                        _metricChip(
                          'Protein',
                          '${daily['total_protein'] ?? 0} g',
                        ),
                        _metricChip('Karbo', '${daily['total_carbs'] ?? 0} g'),
                        _metricChip('Lemak', '${daily['total_fat'] ?? 0} g'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Validasi asupan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...validation.entries.map((entry) {
                      final value = entry.value;
                      final statusText = value is Map
                          ? (value['status'] ??
                                    value['alert'] ??
                                    value['message'] ??
                                    value)
                                .toString()
                          : value.toString();
                      final color = statusText.toLowerCase().contains('normal')
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${entry.key}: $statusText',
                          style: TextStyle(color: color),
                        ),
                      );
                    }),
                  ] else
                    const Text('Belum ada analisis nutrisi untuk tanggal ini.'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _metricChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: const Color(0xFFEDE7F6),
    );
  }

  Widget _buildRecapSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _growthFuture,
      builder: (context, growthSnapshot) {
        final growthBundle = growthSnapshot.data ?? const <String, dynamic>{};
        final assessment = growthBundle['latest_assessment'] is Map
            ? Map<String, dynamic>.from(
                growthBundle['latest_assessment'] as Map,
              )
            : const <String, dynamic>{};
        final warnings = (assessment['warnings'] as List?) ?? const [];

        return FutureBuilder<Map<String, dynamic>>(
          future: _nutritionFuture,
          builder: (context, nutritionSnapshot) {
            final nutrition =
                nutritionSnapshot.data ?? const <String, dynamic>{};
            final daily = nutrition['daily_nutrition'] is Map
                ? Map<String, dynamic>.from(nutrition['daily_nutrition'] as Map)
                : const <String, dynamic>{};
            final validation = nutrition['validation'] is Map
                ? Map<String, dynamic>.from(nutrition['validation'] as Map)
                : const <String, dynamic>{};

            final recapLines = <String>[];
            if (assessment.isNotEmpty) {
              recapLines.add('Pertumbuhan: ${_resolveStatus(assessment)}');
            }
            if (daily.isNotEmpty) {
              recapLines.add(
                'Nutrisi hari ini: ${daily['total_calories'] ?? 0} kcal, ${daily['total_protein'] ?? 0} g protein',
              );
            }
            if (warnings.isNotEmpty) {
              recapLines.add('Peringatan: ${warnings.join(' • ')}');
            }

            return _sectionCard(
              title: 'Recap Mingguan',
              icon: Icons.event_note_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recap mingguan dikirim otomatis setiap 7 hari ke email orang tua. Berikut ringkasan cepat berdasarkan data terbaru.',
                  ),
                  const SizedBox(height: 10),
                  ...recapLines.isEmpty
                      ? [
                          const Text(
                            'Belum ada data cukup untuk membuat recap.',
                          ),
                        ]
                      : recapLines.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $line'),
                          ),
                        ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metricChip('Peringatan', '${warnings.length} item'),
                      _metricChip(
                        'Validasi Nutrisi',
                        validation.isEmpty
                            ? 'Belum ada'
                            : '${validation.length} cek',
                      ),
                      _metricChip('Tanggal', _nutritionDate),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmailSection() {
    if (!widget.isParentContext) {
      return _sectionCard(
        title: 'Email & Akses Parent',
        icon: Icons.mail_outline,
        child: const Text(
          'Recap mingguan dan email notifikasi dikirim ke orang tua. Pada mode child, pengaturan email tidak ditampilkan.',
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _emailPrefsFuture,
      builder: (context, snapshot) {
        return _sectionCard(
          title: 'Email & Notifikasi Parent',
          icon: Icons.mark_email_read_outlined,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _weeklyRecap,
                onChanged: (value) => setState(() => _weeklyRecap = value),
                title: const Text('Weekly recap email'),
                subtitle: const Text('Kirim ringkasan otomatis setiap 7 hari'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _alerts,
                onChanged: (value) => setState(() => _alerts = value),
                title: const Text('Alert email'),
                subtitle: const Text(
                  'Notifikasi jika ada deviasi atau peringatan',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _notifyDeviations,
                onChanged: (value) => setState(() => _notifyDeviations = value),
                title: const Text('Notifikasi deviasi'),
                subtitle: const Text(
                  'Sorot status gizi dan growth yang menyimpang',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _savingPrefs ? null : _saveEmailPreferences,
                  icon: _savingPrefs
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Simpan preferensi email'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFCE4EC), Color(0xFFF3E5F5)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kesehatan Anak Terpadu',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isParentContext
                        ? 'Parent bisa input growth, nutrisi, dan set preferensi recap/email untuk tiap anak.'
                        : 'Child bisa mencatat pertumbuhan dan nutrisi harian, sementara recap otomatis tetap masuk ke parent.',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metricChip('Standar', 'WHO'),
                      _metricChip('Recap', '7 hari'),
                      _metricChip('Aman', 'Captcha login'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildGrowthSection(),
            _buildNutritionSection(),
            _buildAgeSpecificSection(),
            _buildRecapSection(),
            _buildEmailSection(),
          ],
        ),
      ),
    );
  }
}

class _AgeFeatureAction {
  final String title;
  final String subtitle;
  final String activityType;
  final String promptLabel;
  final String hintText;
  final IconData icon;

  const _AgeFeatureAction({
    required this.title,
    required this.subtitle,
    required this.activityType,
    required this.promptLabel,
    required this.hintText,
    required this.icon,
  });
}
