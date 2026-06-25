class DashboardProfile {
  final String key;
  final String title;
  final String ageRange;
  final String focus;
  final List<String> tracking;
  final List<String> extras;
  final List<String> aiSuggestions;

  const DashboardProfile({
    required this.key,
    required this.title,
    required this.ageRange,
    required this.focus,
    required this.tracking,
    required this.extras,
    required this.aiSuggestions,
  });
}

const Map<String, DashboardProfile> kDashboardProfiles = {
  'baby': DashboardProfile(
    key: 'baby',
    title: 'Bayi',
    ageRange: '0-1 tahun',
    focus: 'Fisik, imunisasi, dan nutrisi dasar',
    tracking: ['Tinggi', 'Berat', 'ASI/Formula'],
    extras: ['Imunisasi & kunjungan dokter', 'Milestone motorik dan sensorik'],
    aiSuggestions: ['Jadwal imunisasi bayi', 'MPASI dan ASI yang sesuai'],
  ),
  'toddler': DashboardProfile(
    key: 'toddler',
    title: 'Toddler',
    ageRange: '1-2 tahun',
    focus: 'Kemandirian dan stimulasi',
    tracking: ['Toilet training', 'Bahasa', 'Motorik aktif'],
    extras: ['Makan sendiri & pilih pakaian', 'Interaksi sosial sederhana'],
    aiSuggestions: ['Latihan bahasa toddler', 'Aktivitas motorik toddler'],
  ),
  'balita': DashboardProfile(
    key: 'balita',
    title: 'Balita',
    ageRange: '2-5 tahun',
    focus: 'Aktivitas, bahasa, dan kebiasaan harian',
    tracking: ['Makan', 'Tidur siang', 'Motorik', 'Bahasa'],
    extras: ['Rutinitas harian sederhana', 'Stimulasi bermain aktif'],
    aiSuggestions: ['Ide aktivitas balita', 'Menu sehat balita'],
  ),
  'anak': DashboardProfile(
    key: 'anak',
    title: 'Anak',
    ageRange: '6-12 tahun',
    focus: 'Belajar, kesehatan, dan hobi',
    tracking: ['BMI', 'Belajar', 'Screen time'],
    extras: ['Sosial-emosional', 'Olahraga dan hobi'],
    aiSuggestions: ['Dukungan belajar anak', 'Manajemen screen time sehat'],
  ),
  'remaja': DashboardProfile(
    key: 'remaja',
    title: 'Remaja',
    ageRange: '13-17 tahun',
    focus: 'Pubertas, mental, dan masa depan',
    tracking: ['Mood', 'Hidrasi', 'Akademik'],
    extras: ['Pubertas & pertumbuhan', 'Target karier dan tanggung jawab'],
    aiSuggestions: ['Support mental remaja', 'Rencana masa depan remaja'],
  ),
};

String mapCategoryFromAge(int umur) {
  if (umur <= 1) return 'baby';
  if (umur <= 2) return 'toddler';
  if (umur <= 5) return 'balita';
  if (umur <= 12) return 'anak';
  return 'remaja';
}
