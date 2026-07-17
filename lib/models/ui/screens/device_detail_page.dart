import 'package:flutter/material.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/health_metric.dart';
import 'package:tane06_app/models/ui/widgets/metric_card.dart';
import 'package:tane06_app/models/ui/widgets/sleep_overview_card.dart';
import 'package:tane06_app/models/ui/screens/hrv_screen.dart';

class DeviceDetailPage extends StatelessWidget {
  final Device device;

  const DeviceDetailPage({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    // Health metrics configuration
    final metrics = [
      HealthMetric(
        type: MetricType.heartRate,
        label: 'Heart Rate',
        value: '${device.heartRate}',
        unit: 'bpm',
        icon: Icons.favorite_rounded,
        color: AppColors.heartRate,
        glowColor: AppColors.heartRateGlow,
        gradient: AppColors.heartRateGradient,
        status: MetricStatus.normal,
        trendPercentage: -1.2,
        trendLabel: 'vs last hour',
        sparklineData: [78.0, 80.0, 76.0, device.heartRate.toDouble(), 74.0, 72.0, 70.0],
      ),
      const HealthMetric(
        type: MetricType.bloodPressure,
        label: 'Blood Pressure',
        value: '120/78',
        unit: 'mmHg',
        icon: Icons.speed_rounded,
        color: AppColors.bloodPressure,
        glowColor: AppColors.bloodPressureGlow,
        gradient: AppColors.bloodPressureGradient,
        status: MetricStatus.normal,
        trendPercentage: 0.0,
        trendLabel: 'recent',
        sparklineData: [120.0, 118.0, 119.0, 121.0, 120.0],
      ),
      const HealthMetric(
        type: MetricType.steps,
        label: 'Steps',
        value: '6,543',
        unit: 'steps',
        icon: Icons.directions_walk_rounded,
        color: AppColors.steps,
        glowColor: AppColors.stepsGlow,
        gradient: AppColors.stepsGradient,
        status: MetricStatus.normal,
        trendPercentage: 8.4,
        trendLabel: 'today',
        sparklineData: [4200.0, 5400.0, 6000.0, 6543.0],
      ),
      HealthMetric(
        type: MetricType.bloodPressure,
        label: 'SpO₂',
        value: '${device.spo2}',
        unit: '%',
        icon: Icons.water_drop_rounded,
        color: AppColors.bloodPressure,
        glowColor: AppColors.bloodPressureGlow,
        gradient: AppColors.bloodPressureGradient,
        status: MetricStatus.normal,
        trendPercentage: 0.4,
        trendLabel: 'vs last hour',
        sparklineData: [96.0, 97.0, device.spo2.toDouble(), 95.0, 97.0, 98.0],
      ),
      const HealthMetric(
        type: MetricType.heartRate,
        label: 'HRV',
        value: '49.4',
        unit: 'ms',
        icon: Icons.analytics_rounded,
        color: AppColors.heartRate,
        glowColor: AppColors.heartRateGlow,
        gradient: AppColors.heartRateGradient,
        status: MetricStatus.normal,
        trendPercentage: 2.1,
        trendLabel: 'vs yesterday',
        sparklineData: [45.0, 48.0, 47.5, 49.4, 50.1],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(device.name, style: const TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Device Info Header Card
            _buildHeaderCard(context),
            const SizedBox(height: 24),

            // 2. Section Title
            const Text(
              '即時健康數據',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildActivitySummary(),
            const SizedBox(height: 16),
            // 3. Main/Large Metric Card (Heart Rate)
            SizedBox(
              height: 200,
              width: double.infinity,
              child: MetricCard(metric: metrics[0], isLarge: true),
            ),
            const SizedBox(height: 12),

            // 4. Activity Summary Card (MOVED UP HERE)
           

            // 5. Secondary Metrics Grid (Blood Pressure, Steps, SpO2, HRV)
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: List.generate(
                metrics.length - 1,
                (i) => GestureDetector(
                  onTap: metrics[1 + i].label == 'HRV'
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HRVScreen()),
                          )
                      : null,
                  child: MetricCard(metric: metrics[1 + i]),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 6. Sleep Overview Card
            SleepOverviewCard(totalMinutes: 462),
            const SizedBox(height: 16),

            // 7. Core Quick Actions Bar
            _buildActionButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.surfaceMedium,
                child: Icon(Icons.watch_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${device.owner} • ${device.statusLabel}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('最後更新：2 分鐘前', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceMedium,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Sync', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _smallStat(Icons.battery_charging_full_rounded, '${device.batteryPercent}%', 'Battery'),
              const SizedBox(width: 12),
              _smallStat(Icons.favorite_rounded, '${device.heartRate} bpm', 'Heart'),
              const SizedBox(width: 12),
              _smallStat(Icons.water_drop_rounded, '${device.spo2}%', 'SpO₂'),
              const Spacer(),
              if (device.statusLabel.contains('偏高') || device.statusLabel.contains('異常'))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFCDD2), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFB00020)), 
                      SizedBox(width: 6), 
                      Text('需要關注', style: TextStyle(color: Color(0xFFB00020), fontSize: 12, fontWeight: FontWeight.bold))
                    ]
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _quickAction(Icons.history_rounded, 'History', () {}),
              const SizedBox(width: 12),
              _quickAction(Icons.settings_rounded, 'Settings', () {}),
              const SizedBox(width: 12),
              _quickAction(Icons.analytics_rounded, 'HRV Summary', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HRVScreen()));
              }),
              const SizedBox(width: 12),
              _quickAction(Icons.notifications_rounded, 'Alerts', () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日活動', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('368 kcal', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(width: 12),
                  Text('4.2 km'),
                  SizedBox(width: 12),
                  Text('58 分鐘'),
                ],
              ),
            ],
          ),
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: 0.7,
              color: const Color(0xFF5E5CE6),
              backgroundColor: AppColors.surfaceMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _actionButton(Icons.health_and_safety_rounded, '請求即時量測', () {})), 
        const SizedBox(width: 12), 
        Expanded(child: _actionButton(Icons.history_rounded, '查看歷史紀錄', () {})), 
        const SizedBox(width: 12), 
        Expanded(child: _actionButton(Icons.settings_rounded, '設備設定', () {})),
      ],
    );
  }

  Widget _smallStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceMedium,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label, 
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}