import 'package:flutter/material.dart';
import 'menu/five_menu_shell.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Dashboard Parent'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF51375F),
        centerTitle: false,
      ),
      body: const SafeArea(
        child: FiveMenuShell(
          childId: null,
          titlePrefix: 'Dashboard Parent',
          dashboardType: 'parent',
        ),
      ),
    );
  }
}

/*
    final payload = <String, dynamic>{
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    for (final entry in updates.entries) {
      payload['familySettings.${entry.key}'] = entry.value;
    }

    // await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(payload, SetOptions(merge: true));
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'parent':
        return 'Orang Tua';
      case 'child':
        return 'Anak';
      default:
        return 'Belum dipilih';
    }
  }

  String _formatHour(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  ButtonStyle get _compactOutlinedStyle => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  ButtonStyle get _compactElevatedStyle => ElevatedButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _buildBackendStatusBanner() {
    if (_backendMessage == null) return const SizedBox.shrink();

    final isError =
        _backendConnectionIssue ||
        _backendMessage!.toLowerCase().contains('gagal') ||
        _backendMessage!.toLowerCase().contains('error');
    final background = _backendConnectionIssue
        ? const Color(0xFFFFEBEE)
        : isError
        ? const Color(0xFFFFF3E0)
        : const Color(0xFFE8F5E9);
    final border = _backendConnectionIssue
        ? const Color(0xFFE53935)
        : isError
        ? const Color(0xFFFB8C00)
        : const Color(0xFF43A047);
    final icon = _backendConnectionIssue
        ? Icons.wifi_off_rounded
        : isError
        ? Icons.error_outline
        : Icons.check_circle_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: border),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _backendMessage!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: border,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_backendConnectionIssue) ...[
            const SizedBox(height: 8),
            Text(
              'Saran URL: ${BackendApiService.backendUrlHint()}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'URL aktif saat ini: ${BackendApiService.baseUrl}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return SizedBox(
      width: 152,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFamilyControlCenter({required bool isCompact}) {
    // final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      // stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? <String, dynamic>{};
        final rawSettings = userData['familySettings'];
        final settings = rawSettings is Map
            ? Map<String, dynamic>.from(rawSettings)
            : <String, dynamic>{};

        final role = (userData['selectedRole'] as String?) ?? 'parent';
        final umur = (userData['umur'] as num?)?.toInt();
        final dashboardCategory = userData['dashboardCategory'] as String?;
        final screenTimeLimit =
            (settings['screenTimeLimitMin'] as num?)?.toInt() ?? 120;
        final learnReminderHour =
            (settings['learnReminderHour'] as num?)?.toInt() ?? 19;
        final sleepReminderHour =
            (settings['sleepReminderHour'] as num?)?.toInt() ?? 21;
        final autoReminderEnabled =
            (settings['autoReminderEnabled'] as bool?) ?? true;
        final rewardSystemEnabled =
            (settings['rewardSystemEnabled'] as bool?) ?? true;
        final panicAlertsEnabled =
            (settings['panicAlertsEnabled'] as bool?) ?? true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isCompact ? 14 : 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFCE4EC), Color(0xFFEDE7F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: isCompact ? 46 : 52,
                        height: isCompact ? 46 : 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.verified_user,
                          color: Color(0xFFAD1457),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data User & Koneksi',
                              style: TextStyle(
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6A1B9A),
                              ),
                            ),
                            SizedBox(height: isCompact ? 2 : 4),
                            Text(
                              user.email ?? 'Email belum tersedia',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 12 : 16),
                  Center(
                    child: Wrap(
                      spacing: isCompact ? 8 : 10,
                      runSpacing: isCompact ? 8 : 10,
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      children: [
                        _buildStatChip(
                          icon: Icons.badge,
                          label: 'Role',
                          value: _roleLabel(role),
                          color: const Color(0xFF8E24AA),
                        ),
                        _buildStatChip(
                          icon: Icons.link,
                          label: 'Backend',
                          value: BackendApiService.hasSession
                              ? 'Terhubung'
                              : 'Offline',
                          color: const Color(0xFFE91E63),
                        ),
                        _buildStatChip(
                          icon: Icons.family_restroom,
                          label: 'Akun Anak',
                          value: '${_backendChildren.length} terhubung',
                          color: const Color(0xFF6A1B9A),
                        ),
                        _buildStatChip(
                          icon: Icons.dashboard_customize,
                          label: 'Dashboard',
                          value: dashboardCategory ?? 'Akses semua',
                          color: const Color(0xFFAD1457),
                        ),
                      ],
                    ),
                  ),
                  if (umur != null) ...[
                    SizedBox(height: isCompact ? 8 : 10),
                    Center(
                      child: _buildStatChip(
                        icon: Icons.cake,
                        label: 'Umur',
                        value: '$umur tahun',
                        color: const Color(0xFFEC407A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: isCompact ? 12 : 18),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings Keluarga',
                      style: TextStyle(
                        fontSize: isCompact ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 6),
                    const Text(
                      'Atur panic alert, reward, screen time, dan reminder.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    SizedBox(height: isCompact ? 8 : 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: panicAlertsEnabled,
                      title: const Text('Panic button darurat aktif'),
                      subtitle: const Text(
                        'Jika anak menekan tombol darurat, parent melihat alert live.',
                      ),
                      onChanged: (value) =>
                          _updateUserSettings({'panicAlertsEnabled': value}),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: autoReminderEnabled,
                      title: const Text('Reminder otomatis aktif'),
                      subtitle: Text(
                        'Belajar ${_formatHour(learnReminderHour)} • Tidur ${_formatHour(sleepReminderHour)}',
                      ),
                      onChanged: (value) =>
                          _updateUserSettings({'autoReminderEnabled': value}),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: rewardSystemEnabled,
                      title: const Text('Reward system anak aktif'),
                      subtitle: const Text(
                        'Checklist kebiasaan dan tugas memberi poin jika diaktifkan.',
                      ),
                      onChanged: (value) =>
                          _updateUserSettings({'rewardSystemEnabled': value}),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Batas screen time harian'),
                      subtitle: Text('$screenTimeLimit menit per hari'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: screenTimeLimit <= 30
                                ? null
                                : () => _updateUserSettings({
                                    'screenTimeLimitMin': screenTimeLimit - 15,
                                  }),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            onPressed: screenTimeLimit >= 240
                                ? null
                                : () => _updateUserSettings({
                                    'screenTimeLimitMin': screenTimeLimit + 15,
                                  }),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('Jam reminder belajar'),
                      subtitle: Text(_formatHour(learnReminderHour)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: learnReminderHour <= 15
                                ? null
                                : () => _updateUserSettings({
                                    'learnReminderHour': learnReminderHour - 1,
                                  }),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            onPressed: learnReminderHour >= 22
                                ? null
                                : () => _updateUserSettings({
                                    'learnReminderHour': learnReminderHour + 1,
                                  }),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bedtime_outlined),
                      title: const Text('Jam reminder tidur'),
                      subtitle: Text(_formatHour(sleepReminderHour)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: sleepReminderHour <= 18
                                ? null
                                : () => _updateUserSettings({
                                    'sleepReminderHour': sleepReminderHour - 1,
                                  }),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            onPressed: sleepReminderHour >= 23
                                ? null
                                : () => _updateUserSettings({
                                    'sleepReminderHour': sleepReminderHour + 1,
                                  }),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Live Monitor ────────────────────────────────────────────────────────
  Widget _buildLiveMonitor({required bool isCompact}) {
    return StreamBuilder<DatabaseEvent>(
      stream: _liveMonitorStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Gagal memuat live data: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFFE91E63)),
            ),
          );
        }

        final raw = snapshot.data?.snapshot.value;
        if (raw == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Belum ada anak aktif saat ini.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        final children = (raw as Map<dynamic, dynamic>).entries.toList();
        final panicChildren = children.where((entry) {
          final data = entry.value as Map<dynamic, dynamic>;
          return data['panicActive'] == true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (panicChildren.isNotEmpty)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: isCompact ? 8 : 12),
                padding: EdgeInsets.all(isCompact ? 10 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE53935)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFC62828),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Alert Darurat Aktif',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 6 : 8),
                    ...panicChildren.map((entry) {
                      final data = entry.value as Map<dynamic, dynamic>;
                      final displayName =
                          (data['displayName'] as String?) ?? 'Anak';
                      final panicMessage =
                          (data['panicMessage'] as String?) ??
                          'Butuh bantuan orang tua sekarang.';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $displayName: $panicMessage'),
                      );
                    }),
                  ],
                ),
              ),
            ...children.map((entry) {
              final uid = entry.key as String;
              final data = entry.value as Map<dynamic, dynamic>;
              final category = (data['category'] as String?) ?? 'unknown';
              final displayName =
                  (data['displayName'] as String?) ?? uid.substring(0, 8);
              final lastUpdateMs = data['lastUpdate'];
              String lastUpdateStr = '-';
              if (lastUpdateMs != null) {
                final dt = DateTime.fromMillisecondsSinceEpoch(
                  (lastUpdateMs as int),
                );
                lastUpdateStr =
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              }
              final summary = liveStatusSummary(category, data);
              final color = categoryColor(category);
              final label = categoryLabel(category);
              final panicActive = data['panicActive'] == true;
              final panicMessage =
                  (data['panicMessage'] as String?) ??
                  'Butuh bantuan orang tua.';

              return Card(
                margin: EdgeInsets.only(bottom: isCompact ? 8 : 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: panicActive
                        ? const Color(0xFFE53935)
                        : color.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 12 : 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        radius: isCompact ? 20 : 22,
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              summary,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                            if (panicActive) ...[
                              SizedBox(height: isCompact ? 6 : 8),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(isCompact ? 8 : 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Darurat: $panicMessage',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (panicActive
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFFE91E63))
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: panicActive
                                        ? const Color(0xFFE53935)
                                        : const Color(0xFFE91E63),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  panicActive ? 'Darurat' : 'Live',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: panicActive
                                        ? const Color(0xFFE53935)
                                        : const Color(0xFFE91E63),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastUpdateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildBackendBridgeCard({required bool isCompact}) {
    final backendStatusText = BackendApiService.hasSession
        ? 'Aktif'
        : 'Offline';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE8F3), Color(0xFFF1E6FF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link, color: Color(0xFF9C27B0)),
              SizedBox(width: 8),
              Text(
                'Super Admin Backend (Node)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B1FA2),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 4 : 6),
          const Text(
            'Satu panel untuk URL, login, invite, refresh, dan resync. Backend auto-init sekali saat startup.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          SizedBox(height: isCompact ? 10 : 12),
          Wrap(
            spacing: isCompact ? 6 : 8,
            runSpacing: isCompact ? 6 : 8,
            children: [
              _buildStatChip(
                icon: Icons.link,
                label: 'Status',
                value: backendStatusText,
                color: const Color(0xFF9C27B0),
              ),
              _buildStatChip(
                icon: Icons.family_restroom,
                label: 'Anak',
                value: '${_backendChildren.length} terhubung',
                color: const Color(0xFF6A1B9A),
              ),
              _buildStatChip(
                icon: Icons.settings_ethernet,
                label: 'URL',
                value: BackendApiService.baseUrl,
                color: const Color(0xFFE91E63),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 12),
          TextField(
            controller: _backendUrlController,
            decoration: const InputDecoration(
              labelText: 'Backend URL',
              hintText: 'http://127.0.0.1:5000 atau http://10.0.2.2:5000',
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (value) {
              BackendApiService.setBaseUrl(value).then((_) {
                if (!mounted) return;
                setState(() {
                  _backendMessage =
                      'Backend URL di-set ke ${BackendApiService.baseUrl}';
                });
              });
            },
          ),
          SizedBox(height: isCompact ? 6 : 8),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: isCompact ? 6 : 8,
              runSpacing: isCompact ? 6 : 8,
              alignment: WrapAlignment.end,
              children: [
                ElevatedButton.icon(
                  style: _compactElevatedStyle,
                  onPressed: _backendLoading ? null : _bootstrapBackendSession,
                  icon: _backendLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restart_alt),
                  label: const Text('Sync Ulang'),
                ),
                OutlinedButton.icon(
                  style: _compactOutlinedStyle,
                  onPressed: _backendTestLoading
                      ? null
                      : _testBackendConnection,
                  icon: _backendTestLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_outlined),
                  label: const Text('Test Koneksi'),
                ),
                OutlinedButton.icon(
                  style: _compactOutlinedStyle,
                  onPressed: () async {
                    await BackendApiService.setBaseUrl(
                      _backendUrlController.text,
                    );
                    if (!mounted) return;
                    setState(() {
                      _backendConnectionIssue = false;
                      _backendMessage =
                          'Backend URL di-set ke ${BackendApiService.baseUrl}';
                    });
                  },
                  icon: const Icon(Icons.settings_ethernet),
                  label: const Text('Set URL'),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 6 : 8),
          TextField(
            controller: _backendEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Backend',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          SizedBox(height: isCompact ? 6 : 8),
          TextField(
            controller: _backendPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password Backend',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          SizedBox(height: isCompact ? 8 : 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _rememberBackendPassword = !_rememberBackendPassword;
                });
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _rememberBackendPassword,
                    onChanged: (v) {
                      setState(() => _rememberBackendPassword = v ?? true);
                    },
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Simpan password backend',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Untuk auto-connect saat session expired.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isCompact ? 2 : 4),
          const Text(
            'Gunakan panel ini kalau ada masalah backend. Semua anak, token, dan recap tetap ikut lewat sini.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          SizedBox(height: isCompact ? 6 : 8),
          Wrap(
            spacing: isCompact ? 6 : 8,
            runSpacing: isCompact ? 6 : 8,
            children: [
              ElevatedButton.icon(
                style: _compactElevatedStyle,
                onPressed: _backendLoading
                    ? null
                    : _loginBackendAndLoadChildren,
                icon: _backendLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Text('Login'),
              ),
              OutlinedButton.icon(
                style: _compactOutlinedStyle,
                onPressed: _backendLoading
                    ? null
                    : _registerBackendAndLoadChildren,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Daftar'),
              ),
              OutlinedButton.icon(
                style: _compactOutlinedStyle,
                onPressed: _backendLoading || !BackendApiService.hasSession
                    ? null
                    : _refreshBackendChildren,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              OutlinedButton.icon(
                style: _compactOutlinedStyle,
                onPressed: _backendLoading || !BackendApiService.hasSession
                    ? null
                    : () async {
                        await BackendApiService.clearSession(
                          clearPassword: true,
                        );
                        if (!mounted) return;
                        setState(() {
                          _backendChildren = const [];
                          _backendMessage =
                              'Session backend + password terenkripsi dihapus.';
                        });
                      },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _inviteCodeController,
                decoration: const InputDecoration(
                  labelText: 'Kode Invite',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: isCompact ? 6 : 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: _compactElevatedStyle,
                  onPressed:
                      _backendActionLoading || !BackendApiService.hasSession
                      ? null
                      : _redeemInviteCode,
                  child: const Text('Redeem'),
                ),
              ),
            ],
          ),
          if (_backendMessage != null) ...[
            SizedBox(height: isCompact ? 8 : 10),
            _buildBackendStatusBanner(),
          ],
          SizedBox(height: isCompact ? 10 : 12),
          if (_backendChildren.isEmpty)
            const Text(
              'Belum ada data anak.',
              style: TextStyle(color: Colors.black54),
            )
          else
            ..._backendChildren.map(
              (child) => Card(
                child: ListTile(
                  leading: const Icon(Icons.child_care),
                  title: Text('${child.nama} (${child.umur} th)'),
                  subtitle: Text(
                    'Dashboard: ${mapCategoryFromAge(child.umur)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openBackendChild(child),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final pagePadding = isCompact ? 12.0 : 16.0;
    final majorGap = isCompact ? 18.0 : 24.0;

    // legacy helpers intentionally kept for possible reuse

    final themedData = Theme.of(context).copyWith(
      textTheme: Theme.of(
        context,
      ).textTheme.apply(fontFamily: _theme.fontFamily),
      primaryTextTheme: Theme.of(
        context,
      ).primaryTextTheme.apply(fontFamily: _theme.fontFamily),
      appBarTheme: Theme.of(context).appBarTheme.copyWith(
        backgroundColor: _theme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );

    return Theme(
      data: themedData,
      child: Scaffold(
        backgroundColor: _theme.backgroundColor,
        appBar: AppBar(
          title: const Text('Dashboard Parent'),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) => FiveMenuShell(
                          themeColor: _theme.primaryColor,
                          titlePrefix: 'Menu Parent',
                          dashboardType: 'parent',
                        ),
                      ),
                    )
                    .then((_) => _loadTheme());
              },
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: '5 Menu',
            ),
            IconButton(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UnifiedParentDashboard(),
              SizedBox(height: majorGap),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE4F1), Color(0xFFEDE7F6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.all(isCompact ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sensors, color: Color(0xFF7B1FA2)),
                        SizedBox(width: 8),
                        Text(
                          'Live Monitor Anak',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7B1FA2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Update otomatis saat anak menekan simpan',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    SizedBox(height: isCompact ? 10 : 14),
                    _buildLiveMonitor(isCompact: isCompact),
                  ],
                ),
              ),
              SizedBox(height: majorGap),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isCompact ? 12 : 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0F2F1), Color(0xFFCCE7FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.assessment,
                                    color: Color(0xFF00838F),
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Activity Tracker 📊',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00838F),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Track aktivitas harian anak dan dapatkan AI insights',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 12 : 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ActivityTrackerListScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.track_changes),
                        label: const Text('Mulai Tracking Aktivitas'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00838F),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 12 : 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: majorGap),
              const Text(
                'Buka Dashboard Bayi / Toddler / Balita / Anak',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: isCompact ? 8 : 12),
              _dashboardButton(context, 'baby'),
              SizedBox(height: isCompact ? 8 : 10),
              _dashboardButton(context, 'toddler'),
              SizedBox(height: isCompact ? 8 : 10),
              _dashboardButton(context, 'anak'),
              SizedBox(height: isCompact ? 8 : 10),
              _dashboardButton(context, 'balita'),
            ],
          ),
        ),
      ),
    );
  }
}
*/
