class BackendActivityDetail {
  final String type;
  final String text;

  const BackendActivityDetail({required this.type, required this.text});

  factory BackendActivityDetail.fromJson(dynamic json) {
    if (json is String) {
      return BackendActivityDetail(type: 'Aktivitas', text: json);
    }

    final map = Map<String, dynamic>.from((json as Map?) ?? const {});
    return BackendActivityDetail(
      type: (map['type'] as String?)?.trim().isNotEmpty == true
          ? map['type'] as String
          : 'Aktivitas',
      text: (map['text'] as String?)?.trim().isNotEmpty == true
          ? map['text'] as String
          : ((map['label'] as String?) ?? 'Aktivitas'),
    );
  }
}

class BackendDashboardAnalytics {
  final int weekActivities;
  final int monthActivities;
  final int checkinRate;
  final String latestActivityLabel;
  final int? activeChildrenWeek;
  final int? inactiveChildrenWeek;
  final int? activeDaysWeek;
  final Map<String, Map<String, int>> calendarActivityMap;
  final Map<String, Map<String, List<BackendActivityDetail>>> calendarDetailMap;
  final Map<String, Map<String, Map<String, int>>> calendarTypeMap;

  const BackendDashboardAnalytics({
    required this.weekActivities,
    required this.monthActivities,
    required this.checkinRate,
    required this.latestActivityLabel,
    required this.calendarActivityMap,
    required this.calendarDetailMap,
    required this.calendarTypeMap,
    this.activeChildrenWeek,
    this.inactiveChildrenWeek,
    this.activeDaysWeek,
  });

  factory BackendDashboardAnalytics.fromJson(Map<String, dynamic> json) {
    return BackendDashboardAnalytics(
      weekActivities: _asInt(json['week_activities']),
      monthActivities: _asInt(json['month_activities']),
      checkinRate: _asInt(json['checkin_rate']),
      latestActivityLabel:
          (json['latest_activity_label'] as String?) ?? 'Belum ada aktivitas',
      activeChildrenWeek: _asNullableInt(json['active_children_week']),
      inactiveChildrenWeek: _asNullableInt(json['inactive_children_week']),
      activeDaysWeek: _asNullableInt(json['active_days_week']),
      calendarActivityMap: _parseCalendarActivityMap(
        json['calendar_activity_map'],
      ),
      calendarDetailMap: _parseCalendarDetailMap(json['calendar_detail_map']),
      calendarTypeMap: _parseCalendarTypeMap(json['calendar_type_map']),
    );
  }
}

class BackendMenuAnalytics {
  final String scope;
  final int totalActivities;
  final int weekActivities;
  final int monthActivities;
  final int activeDaysWeek;
  final int consistencyRate;
  final String topActivityType;
  final Map<String, int> activityTypes;
  final Map<String, int> weeklySeries;
  final Map<String, Map<String, int>> calendarActivityMap;
  final Map<String, Map<String, List<BackendActivityDetail>>> calendarDetailMap;
  final Map<String, Map<String, Map<String, int>>> calendarTypeMap;

  const BackendMenuAnalytics({
    required this.scope,
    required this.totalActivities,
    required this.weekActivities,
    required this.monthActivities,
    required this.activeDaysWeek,
    required this.consistencyRate,
    required this.topActivityType,
    required this.activityTypes,
    required this.weeklySeries,
    required this.calendarActivityMap,
    required this.calendarDetailMap,
    required this.calendarTypeMap,
  });

  factory BackendMenuAnalytics.fromJson(Map<String, dynamic> json) {
    return BackendMenuAnalytics(
      scope: (json['scope'] as String?) ?? 'unknown',
      totalActivities: _asInt(json['total_activities']),
      weekActivities: _asInt(json['week_activities']),
      monthActivities: _asInt(json['month_activities']),
      activeDaysWeek: _asInt(json['active_days_week']),
      consistencyRate: _asInt(json['consistency_rate']),
      topActivityType:
          (json['top_activity_type'] as String?) ?? 'Belum ada aktivitas',
      activityTypes: _parseIntMap(json['activity_types']),
      weeklySeries: _parseIntMap(json['weekly_series']),
      calendarActivityMap: _parseCalendarActivityMap(
        json['calendar_activity_map'],
      ),
      calendarDetailMap: _parseCalendarDetailMap(json['calendar_detail_map']),
      calendarTypeMap: _parseCalendarTypeMap(json['calendar_type_map']),
    );
  }
}

class BackendChildProfile {
  final String id;
  final String nama;
  final int umur;

  const BackendChildProfile({
    required this.id,
    required this.nama,
    required this.umur,
  });

  factory BackendChildProfile.fromJson(Map<String, dynamic> json) {
    return BackendChildProfile(
      id: (json['id'] ?? '').toString(),
      nama: (json['nama'] as String?) ?? 'Child',
      umur: _asInt(json['umur']),
    );
  }
}

class BackendParentAnalytics {
  final String scope;
  final int parentId;
  final int childrenCount;
  final BackendDashboardAnalytics dashboard;
  final Map<String, BackendMenuAnalytics> menus;

  const BackendParentAnalytics({
    required this.scope,
    required this.parentId,
    required this.childrenCount,
    required this.dashboard,
    required this.menus,
  });

  factory BackendParentAnalytics.fromJson(Map<String, dynamic> json) {
    return BackendParentAnalytics(
      scope: (json['scope'] as String?) ?? 'parent',
      parentId: _asInt(json['parent_id']),
      childrenCount: _asInt(json['children_count']),
      dashboard: BackendDashboardAnalytics.fromJson(
        Map<String, dynamic>.from((json['dashboard'] as Map?) ?? const {}),
      ),
      menus: _parseMenus(json['menus']),
    );
  }
}

class BackendChildAnalytics {
  final String scope;
  final BackendChildProfile child;
  final BackendDashboardAnalytics dashboard;
  final Map<String, BackendMenuAnalytics> menus;

  const BackendChildAnalytics({
    required this.scope,
    required this.child,
    required this.dashboard,
    required this.menus,
  });

  factory BackendChildAnalytics.fromJson(Map<String, dynamic> json) {
    return BackendChildAnalytics(
      scope: (json['scope'] as String?) ?? 'child',
      child: BackendChildProfile.fromJson(
        Map<String, dynamic>.from((json['child'] as Map?) ?? const {}),
      ),
      dashboard: BackendDashboardAnalytics.fromJson(
        Map<String, dynamic>.from((json['dashboard'] as Map?) ?? const {}),
      ),
      menus: _parseMenus(json['menus']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is num) {
    if (value.isNaN || value.isInfinite) return 0;
    return value.toInt();
  }
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  return _asInt(value);
}

Map<String, int> _parseIntMap(dynamic value) {
  final map = Map<String, dynamic>.from((value as Map?) ?? const {});
  return map.map((key, val) => MapEntry(key, _asInt(val)));
}

Map<String, BackendMenuAnalytics> _parseMenus(dynamic value) {
  final raw = Map<String, dynamic>.from((value as Map?) ?? const {});
  return raw.map(
    (key, val) => MapEntry(
      key,
      BackendMenuAnalytics.fromJson(
        Map<String, dynamic>.from((val as Map?) ?? const {}),
      ),
    ),
  );
}

Map<String, Map<String, int>> _parseCalendarActivityMap(dynamic value) {
  final raw = Map<String, dynamic>.from((value as Map?) ?? const {});
  return raw.map((monthKey, monthValue) {
    final dayMap = Map<String, dynamic>.from((monthValue as Map?) ?? const {});
    return MapEntry(
      monthKey,
      dayMap.map((day, count) => MapEntry(day, _asInt(count))),
    );
  });
}

Map<String, Map<String, List<BackendActivityDetail>>> _parseCalendarDetailMap(
  dynamic value,
) {
  final raw = Map<String, dynamic>.from((value as Map?) ?? const {});
  return raw.map((monthKey, monthValue) {
    final dayMap = Map<String, dynamic>.from((monthValue as Map?) ?? const {});
    final parsedDayMap = dayMap.map((day, details) {
      final detailsList = (details as List?) ?? const [];
      return MapEntry(
        day,
        detailsList.map(BackendActivityDetail.fromJson).toList(growable: false),
      );
    });
    return MapEntry(monthKey, parsedDayMap);
  });
}

Map<String, Map<String, Map<String, int>>> _parseCalendarTypeMap(
  dynamic value,
) {
  final raw = Map<String, dynamic>.from((value as Map?) ?? const {});
  return raw.map((monthKey, monthValue) {
    final dayMap = Map<String, dynamic>.from((monthValue as Map?) ?? const {});
    final parsedDayMap = dayMap.map((day, typeValue) {
      final typeMap = Map<String, dynamic>.from(
        (typeValue as Map?) ?? const {},
      );
      return MapEntry(
        day,
        typeMap.map((typeName, count) => MapEntry(typeName, _asInt(count))),
      );
    });
    return MapEntry(monthKey, parsedDayMap);
  });
}
