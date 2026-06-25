import 'package:flutter/material.dart';
import '../models/daily_activity.dart';
import '../services/activity_tracking_service.dart';

class ActivityInputForm extends StatefulWidget {
  final String childId;
  final String? childName;
  final int? childAge;
  final VoidCallback onActivityAdded;

  const ActivityInputForm({
    super.key,
    required this.childId,
    this.childName,
    this.childAge,
    required this.onActivityAdded,
  });

  @override
  State<ActivityInputForm> createState() => _ActivityInputFormState();
}

class _ActivityInputFormState extends State<ActivityInputForm> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;

  String _selectedActivityType = 'feeding';
  String? _selectedMoodBefore;
  String? _selectedMoodAfter;
  bool _isBreastfeeding = true;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int? _selectedRating;
  bool _isLoading = false;

  final List<String> _activityTypes = [
    'feeding',
    'meal',
    'sleep',
    'activity',
    'parenting',
  ];
  final List<String> _moods = ['happy', 'calm', 'fussy', 'sleepy', 'crying'];
  final List<String> _units = ['mL', 'gram', 'spoon', 'oz'];

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _durationController = TextEditingController();
    _quantityController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _durationController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitActivity() async {
    if (_durationController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Durasi harus diisi')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final activity = DailyActivity(
        childId: widget.childId,
        userId: '', // Will be set by service
        date: dateTime,
        activityType: _selectedActivityType,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        durationMinutes: int.tryParse(_durationController.text),
        quantity: _quantityController.text.isEmpty
            ? null
            : double.tryParse(_quantityController.text),
        isBreastfeeding: _selectedActivityType == 'feeding'
            ? _isBreastfeeding
            : null,
        moodBefore: _selectedActivityType == 'parenting'
            ? _selectedMoodBefore
            : null,
        moodAfter: _selectedActivityType == 'parenting'
            ? _selectedMoodAfter
            : null,
        rating: _selectedRating,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdAt:
            dateTime, // PATCH: createdAt = tanggal input, bukan waktu submit
      );

      await ActivityTrackingService.addActivity(
        activity,
        childName: widget.childName,
        childAge: widget.childAge,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktivitas berhasil ditambahkan'),
          duration: Duration(seconds: 2),
        ),
      );

      // Clear form
      _descriptionController.clear();
      _durationController.clear();
      _quantityController.clear();
      _notesController.clear();
      setState(() {
        _selectedActivityType = 'feeding';
        _selectedMoodBefore = null;
        _selectedMoodAfter = null;
        _isBreastfeeding = true;
        _selectedRating = null;
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
      });

      widget.onActivityAdded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Type Selection
          Text(
            'Jenis Aktivitas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _activityTypes.map((type) {
              final isSelected = type == _selectedActivityType;
              return FilterChip(
                label: Text(DailyActivity.getActivityLabel(type)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedActivityType = type);
                },
                backgroundColor: Colors.white,
                selectedColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.3),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Date and Time
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanggal',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Waktu', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTime.format(context),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const Icon(
                              Icons.access_time,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Activity Type Specific Fields
          if (_selectedActivityType == 'feeding') ...[
            Text('Tipe Menyusui', style: Theme.of(context).textTheme.bodySmall),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'ASI',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: _isBreastfeeding,
                    onChanged: (value) =>
                        setState(() => _isBreastfeeding = value ?? true),
                    dense: true,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'Botol',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: !_isBreastfeeding,
                    onChanged: (value) =>
                        setState(() => _isBreastfeeding = !(value ?? true)),
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Description/Details
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: _selectedActivityType == 'meal'
                  ? 'Jenis Makanan'
                  : _selectedActivityType == 'activity'
                  ? 'Tipe Kegiatan'
                  : 'Keterangan',
              hintText: 'Contoh: Susu formula, Nasi tim, Mainan, dsb',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          // Duration
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Durasi (Menit) *',
              hintText: '15',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quantity (for feeding/meals)
          if (_selectedActivityType == 'feeding' ||
              _selectedActivityType == 'meal')
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Jumlah',
                      hintText: '100',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    items: _units
                        .map(
                          (unit) =>
                              DropdownMenuItem(value: unit, child: Text(unit)),
                        )
                        .toList(),
                    onChanged: (_) {},
                    decoration: InputDecoration(
                      labelText: 'Satuan',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_selectedActivityType == 'feeding' ||
              _selectedActivityType == 'meal')
            const SizedBox(height: 12),

          // Mood (for parenting)
          if (_selectedActivityType == 'parenting') ...[
            Text(
              'Suasana Hati Sebelum',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              spacing: 8,
              children: _moods.map((mood) {
                return FilterChip(
                  label: Text(DailyActivity.getMoodLabel(mood)),
                  selected: mood == _selectedMoodBefore,
                  onSelected: (selected) {
                    setState(
                      () => _selectedMoodBefore = selected ? mood : null,
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Suasana Hati Sesudah',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              spacing: 8,
              children: _moods.map((mood) {
                return FilterChip(
                  label: Text(DailyActivity.getMoodLabel(mood)),
                  selected: mood == _selectedMoodAfter,
                  onSelected: (selected) {
                    setState(() => _selectedMoodAfter = selected ? mood : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Rating
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rating Aktivitas (1-5)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(5, (index) {
                  return InkWell(
                    onTap: () => setState(() => _selectedRating = index + 1),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedRating == index + 1
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade200,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: _selectedRating == index + 1
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Notes
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Catatan Tambahan',
              hintText: 'Tambahan informasi penting...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitActivity,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Tambah Aktivitas'),
            ),
          ),
        ],
      ),
    );
  }
}
