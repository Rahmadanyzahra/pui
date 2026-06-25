// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/child_profile_service.dart';

/// Screen untuk parent menambah anak baru secara manual.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  String? _selectedType; // 'baby', 'toddler', atau 'balita'
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _defaultBirthDateForType(_selectedType) ??
          DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2008),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _addChild() async {
    if (_nameController.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi semua data terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await BackendApiService.getCurrentUser();
      if (user == null) throw Exception('User tidak login');

      final age = _calculateAge(_selectedDate!);
      final category = _calculateCategory(age);

      final newId = await ChildProfileService.addChildProfile(
        parentId: user.id.toString(),
        name: _nameController.text.trim(),
        birthDate: _selectedDate!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anak berhasil ditambahkan! (id: $newId)')),
      );
      try {
        await BackendApiService.logParentActivity(
          activityType: 'child_added',
          value:
              'name=${_nameController.text.trim()}, age=$age, category=$category, childProfileId=$newId',
        );
      } catch (e) {
        debugPrint('Warning: failed to log parent activity child_added: $e');
      }
      Navigator.pop(context, {
        'saved': true,
        'childId': newId,
        'name': _nameController.text.trim(),
        'age': age,
        'category': category,
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String _calculateCategory(int age) {
    if (age <= 1) return 'baby';
    if (age <= 2) return 'toddler';
    if (age <= 5) return 'balita';
    return 'anak';
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final selectedMeta = _typeMetadata[_selectedType];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Anak Manual'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tambah manual tanpa token',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Gunakan ini untuk menambah bayi, toddler, atau balita langsung dari dashboard parent. Token hanya untuk menghubungkan akun delegasi orang tua.',
              style: TextStyle(color: Colors.black54),
            ),
            SizedBox(height: isCompact ? 12 : 16),
            // Use a responsive Wrap instead of GridView to avoid overflow inside
            // a SingleChildScrollView on small screens.
            LayoutBuilder(
              builder: (context, constraints) {
                final parentWidth = constraints.maxWidth;
                final spacing = 12.0;
                // two columns layout
                final itemWidth = (parentWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildTypeCard('baby', '👶', 'Bayi', '0-1 tahun'),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildTypeCard(
                        'toddler',
                        '🧒',
                        'Toddler',
                        '1-2 tahun',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildTypeCard(
                        'balita',
                        '👧',
                        'Balita',
                        '2-5 tahun',
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: isCompact ? 24 : 32),

            // Section: Input Data
            if (_selectedType != null) ...[
              Text('Data Anak', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: isCompact ? 12 : 16),

              if (selectedMeta != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE4EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedMeta['label']} | ${selectedMeta['subtitle']}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF51375F),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Nama
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Anak',
                  hintText: 'Masukkan nama anak',
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: isCompact ? 12 : 16),

              // Tanggal Lahir
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFFF06292),
                      ),
                      SizedBox(width: isCompact ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tanggal Lahir',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : 'Pilih tanggal',
                              style: TextStyle(
                                fontSize: isCompact ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 24 : 32),

              // Button Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addChild,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFFF06292),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Simpan Anak',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(
    String typeKey,
    String emoji,
    String label,
    String subtitle,
  ) {
    final isSelected = _selectedType == typeKey;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = typeKey),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF06292) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFFF06292) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : Colors.grey,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  static const Map<String, Map<String, String>> _typeMetadata = {
    'baby': {'label': 'Bayi', 'subtitle': 'Tambah manual bayi 0-1 tahun'},
    'toddler': {
      'label': 'Toddler',
      'subtitle': 'Tambah manual toddler 1-2 tahun',
    },
    'balita': {'label': 'Balita', 'subtitle': 'Tambah manual balita 2-5 tahun'},
  };

  DateTime? _defaultBirthDateForType(String? type) {
    final now = DateTime.now();
    switch (type) {
      case 'baby':
        return DateTime(now.year - 1, now.month, now.day);
      case 'toddler':
        return DateTime(now.year - 2, now.month, now.day);
      case 'balita':
        return DateTime(now.year - 4, now.month, now.day);
      default:
        return null;
    }
  }
}
