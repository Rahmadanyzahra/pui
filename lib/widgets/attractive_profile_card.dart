import 'package:flutter/material.dart';

/// Attractive Profile Card with gradient background and modern design
class AttractiveProfileCard extends StatelessWidget {
  final String displayName;
  final String email;
  final String role;
  final String dashboardCategory;
  final int? age;
  final bool backendConnected;
  final ImageProvider<Object>? profileImage;
  final VoidCallback? onEditPhoto;
  final bool isCompact;
  final Color accentColor;

  const AttractiveProfileCard({
    super.key,
    required this.displayName,
    required this.email,
    required this.role,
    required this.dashboardCategory,
    this.age,
    this.backendConnected = false,
    this.profileImage,
    this.onEditPhoto,
    this.isCompact = false,
    this.accentColor = const Color(0xFFF06292),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, accentColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles background
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Main content
          Padding(
            padding: EdgeInsets.all(isCompact ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with avatar and info
                Row(
                  children: [
                    // Avatar with camera badge
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: isCompact ? 32 : 40,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: isCompact ? 32 : 40,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: onEditPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: isCompact ? 14 : 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: isCompact ? 18 : 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isCompact ? 4 : 6),
                          // Email
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: isCompact ? 12 : 13,
                              color: Colors.white.withOpacity(0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isCompact ? 6 : 8),
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                fontSize: isCompact ? 10 : 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 16 : 20),
                // Status cards (horizontal scroll)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _StatusCard(
                        isCompact: isCompact,
                        icon: Icons.dashboard_customize,
                        label: 'Dashboard',
                        value: _beautifyCategory(dashboardCategory),
                      ),
                      SizedBox(width: isCompact ? 10 : 12),
                      if (age != null)
                        _StatusCard(
                          isCompact: isCompact,
                          icon: Icons.cake,
                          label: 'Umur',
                          value: '$age tahun',
                        ),
                      if (age != null) SizedBox(width: isCompact ? 10 : 12),
                      _StatusCard(
                        isCompact: isCompact,
                        icon: backendConnected
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        label: 'Backend',
                        value: backendConnected ? 'Aktif' : 'Offline',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _beautifyCategory(String category) {
    switch (category.toLowerCase()) {
      case 'baby':
        return 'Bayi';
      case 'toddler':
        return 'Toddler';
      case 'anak':
        return 'Anak';
      case 'remaja':
        return 'Remaja';
      default:
        return category;
    }
  }
}

/// Status card widget for profile info display
class _StatusCard extends StatelessWidget {
  final bool isCompact;
  final IconData icon;
  final String label;
  final String value;

  const _StatusCard({
    required this.isCompact,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 14,
        vertical: isCompact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: isCompact ? 14 : 16),
              SizedBox(width: isCompact ? 4 : 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: isCompact ? 11 : 12,
                  color: Colors.white.withOpacity(0.75),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 2 : 3),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 13 : 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
