// lib/widgets/telemetry_card.dart

import 'package:flutter/material.dart';

class TelemetryCard extends StatelessWidget {
  final int batteryLevel;
  final bool isLocked;
  final DateTime? lastUpdate;
  final bool isOnline;

  const TelemetryCard({
    super.key,
    required this.batteryLevel,
    required this.isLocked,
    this.lastUpdate,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Device Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildOnlineIndicator(),
              ],
            ),
            const SizedBox(height: 16),
            _buildBatteryIndicator(),
            const SizedBox(height: 12),
            _buildLockStatus(),
            if (lastUpdate != null) ...[
              const SizedBox(height: 12),
              _buildLastUpdate(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? Colors.green : Colors.grey,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: isOnline ? Colors.green.shade800 : Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIndicator() {
    Color batteryColor;
    if (batteryLevel > 60) {
      batteryColor = Colors.green;
    } else if (batteryLevel > 20) {
      batteryColor = Colors.orange;
    } else {
      batteryColor = Colors.red;
    }

    return Row(
      children: [
        Icon(Icons.battery_full, color: batteryColor, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Battery: $batteryLevel%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: batteryLevel / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockStatus() {
    return Row(
      children: [
        Icon(
          isLocked ? Icons.lock : Icons.lock_open,
          color: isLocked ? Colors.blue : Colors.orange,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          isLocked ? 'Device Locked' : 'Device Unlocked',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLastUpdate() {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate!);
    String timeAgo;

    if (difference.inSeconds < 60) {
      timeAgo = 'Just now';
    } else if (difference.inMinutes < 60) {
      timeAgo = '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      timeAgo = '${difference.inHours}h ago';
    } else {
      timeAgo = '${difference.inDays}d ago';
    }

    return Row(
      children: [
        Icon(Icons.update, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 8),
        Text(
          'Last update: $timeAgo',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
