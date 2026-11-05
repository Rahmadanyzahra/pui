import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../services/backend_api_service.dart';
import '../services/platform_files.dart';
import 'behavior_screen.dart';
import 'delegate_recap_screen.dart';
import 'growth_screen.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Laporan Perkembangan: pilih periode (hari-hari terakhir atau satu bulan), lihat laporan,
/// unduh PDF kapan saja, dan kirim ke email bila server sudah diatur untuk itu.
class MonthlyReportScreen extends StatefulWidget {
  final BackendChild child;

  const MonthlyReportScreen({super.key, required this.child});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  // Kunci periode: 'last7', 'last30', atau 'YYYY-MM'.
  late String _period;
  late Future<Map<String, dynamic>> _report;
  bool _busy = false;
  bool _emailReady = true;

  @override
  void initState() {
    super.initState();
    _period = monthKey(DateTime.now());
    _report = PataraApi.monthlyReport(widget.child.id, _period);
    BackendApiService.requestJson('GET', '/api/app-config')
        .then((data) {
          final ready = (data as Map<String, dynamic>)['email_configured'] != false;
          if (mounted) setState(() { _emailReady = ready; });
        })
        .catchError((_) {});
  }

  /// Pilihan periode: hari-hari terakhir lebih dulu, lalu tiap bulan.
  List<(String, String)> get _periods => [
    ('last7', '7 hari terakhir'),
    ('last30', '30 hari terakhir'),
    for (final month in _months)
      (monthKey(month), month == _months.first ? '${formatMonth(month)} (sampai hari ini)' : formatMonth(month)),
  ];

  /// Dua belas bulan terakhir, dibatasi sampai bulan lahir anak.
  List<DateTime> get _months {
    final now = DateTime.now();
    final birth = widget.child.birthDate;
    final first = birth == null ? null : DateTime(birth.year, birth.month);
    return [
      for (var offset = 0; offset < 12; offset++) DateTime(now.year, now.month - offset),
    ].where((month) => first == null || !month.isBefore(first)).toList();
  }

  void _select(String period) => setState(() {
    _period = period;
    _report = PataraApi.monthlyReport(widget.child.id, period);
  });

  Future<void> _download() async {
    setState(() { _busy = true; });
    try {
      final path = await PataraApi.downloadMonthlyReport(widget.child.id, _period, widget.child.nama);
      // Di browser berkas langsung masuk ke folder unduhan, jadi tidak ada yang perlu dibuka.
      if (!savedFilesOpenInApp) {
        if (mounted) showMessage(context, 'Laporan PDF diunduh oleh browser: $path');
        return;
      }
      final result = await OpenFilex.open(path, type: 'application/pdf');
      if (!mounted) return;
      showMessage(
        context,
        result.type == ResultType.done
            ? 'Laporan PDF berhasil diunduh.'
            : 'PDF tersimpan di $path, tetapi tidak ada aplikasi pembuka PDF.',
      );
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _email() async {
    setState(() { _busy = true; });
    try {
      final email = await PataraApi.emailMonthlyReport(widget.child.id, _period);
      if (mounted) showMessage(context, 'Laporan dikirim ke $email.');
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar('Laporan Perkembangan', pataraPink, icon: Icons.picture_as_pdf_outlined),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _period,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Periode laporan',
                helperText: 'Laporan bisa dilihat dan diunduh kapan saja.',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final (key, label) in _periods) DropdownMenuItem(value: key, child: Text(label)),
              ],
              onChanged: (period) => period == null ? null : _select(period),
            ),
          ),
          Expanded(
            child: AsyncView<Map<String, dynamic>>(
              future: _report,
              onRetry: () => _select(_period),
              builder: (context, report) => _buildReport(report),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _download,
                          icon: const Icon(Icons.download),
                          label: const Text('Download PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy || !_emailReady ? null : _email,
                          icon: const Icon(Icons.email_outlined),
                          label: const Text('Kirim ke Email'),
                        ),
                      ),
                    ],
                  ),
                  if (!_emailReady)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Kirim ke email belum aktif karena server belum diatur untuk mengirim email. Gunakan Download PDF.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthHealth(Map<String, dynamic> growth, Map<String, dynamic> health) {
    final latest = growth['latest'] as Map<String, dynamic>?;
    final change = growth['change'] as Map<String, dynamic>? ?? const {};
    final records = ((health['records_in_period'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final who = growth['who'] as Map<String, dynamic>?;
    final whoItems = who?['available'] == true
        ? (who!['indicators'] as List).cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    String measure(String field, String unit) {
      final value = latest?[field] as num?;
      if (value == null) return '–';
      final delta = change[field] as num?;
      final suffix = delta == null ? '' : ' (${delta > 0 ? '+' : ''}${formatNumber(delta)})';
      return '${formatNumber(value)} $unit$suffix';
    }

    return PataraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latest == null)
            const Text('Belum ada data pengukuran berat dan tinggi badan.')
          else ...[
            Text('Berat badan: ${measure('weight_kg', 'kg')}'),
            Text('Tinggi badan: ${measure('height_cm', 'cm')}'),
            Text('Lingkar kepala: ${measure('head_circumference_cm', 'cm')}'),
            Text(
              'Pengukuran terakhir ${formatDate(DateTime.parse('${latest['measured_at']}').toLocal())}; angka dalam kurung adalah perubahan dari pengukuran sebelumnya.',
              style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
            ),
            for (final item in whoItems)
              Text(
                'Kurva WHO ${item['short']}: z-score ${'${item['z_score']}'.replaceAll('.', ',')}. ${item['text']}',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
          ],
          const Divider(height: 22),
          Text(
            'Imunisasi tercatat: ${health['immunizations_given'] ?? 0} dari ${health['immunizations_total'] ?? 0}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (records.isEmpty)
            const Text('Tidak ada catatan kesehatan pada periode ini.')
          else
            for (final record in records)
              Text('•  ${formatDate(DateTime.parse('${record['record_date']}'))} — ${record['title']}'),
        ],
      ),
    );
  }

  Widget _buildReport(Map<String, dynamic> report) {
    final child = report['child'] as Map<String, dynamic>;
    final period = report['period'] as Map<String, dynamic>;
    final insight = report['insight'] as Map<String, dynamic>;
    final development = (report['development'] as List).cast<Map<String, dynamic>>();
    final recommendations = (report['recommendations'] as List).cast<Map<String, dynamic>>();
    final delegates = ((report['delegate_performance'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PataraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${child['nama']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${child['age_formatted']} • ${child['gender_label']}'),
              Text('Periode ${period['label']}', style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        const SectionTitle('Pertumbuhan dan kesehatan'),
        _buildGrowthHealth(
          report['growth'] as Map<String, dynamic>? ?? const {},
          report['health'] as Map<String, dynamic>? ?? const {},
        ),
        // Bagian Delegasi hanya tampil bila memang ada laporan dari Delegasi; laporan tetap lengkap tanpa itu.
        if (delegates.isNotEmpty) ...[
          const SectionTitle('Kinerja Delegasi'),
          for (final item in delegates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DelegatePerformanceCard(item: item),
            ),
        ],
        const SectionTitle('AI Insight'),
        PataraCard(child: Text('${insight['text']}', style: const TextStyle(height: 1.45))),
        const SectionTitle('AI Recommendation'),
        if (recommendations.isEmpty)
          const PataraCard(child: Text('Belum ada rekomendasi untuk periode ini.'))
        else
          for (final item in recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PataraCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['text']}', style: const TextStyle(height: 1.35)),
                    const SizedBox(height: 4),
                    Text('Dasar: ${item['basis']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ),
        const SectionTitle('Perkembangan'),
        PataraCard(
          child: Column(
            children: [
              for (final aspect in development)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 80, child: Text('${aspect['label']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Expanded(
                        child: Text(
                          aspect['total'] == 0
                              ? '${aspect['summary']}'
                              : '${aspect['tercapai']}/${aspect['total']} indikator terlihat. ${aspect['summary']}',
                          style: const TextStyle(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SectionTitle('Aktivitas dan perilaku'),
        BehaviorSummaryView(data: report['behavior'] as Map<String, dynamic>, embedded: true),
      ],
    );
  }
}
