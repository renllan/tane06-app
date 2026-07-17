import 'package:flutter/material.dart';
import 'package:tane06_app/theme/app_theme.dart';

class HRVScreen extends StatelessWidget {
  final double? hrvMs;
  final List<double>? history;

  const HRVScreen({super.key, this.hrvMs, this.history});

  @override
  Widget build(BuildContext context) {
    final sampleHistory = history ?? [48.0, 50.1, 49.4, 47.8, 51.2, 50.0, 49.0];
    final display = hrvMs ?? sampleHistory.last;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('HRV', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: AppColors.surfaceDark,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      const Text('Current HRV', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text(
                        '${display.toStringAsFixed(1)} ms',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.arrow_upward, size: 14, color: Colors.green),
                          SizedBox(width: 6),
                          Text('Stable', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text('Recent HRV', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              Expanded(
                child: Card(
                  color: AppColors.surfaceLight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListView.separated(
                      itemCount: sampleHistory.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (context, i) {
                        final v = sampleHistory[sampleHistory.length - 1 - i];
                        return ListTile(
                          leading: const Icon(Icons.show_chart, color: AppColors.textTertiary),
                          title: Text('${v.toStringAsFixed(1)} ms', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('a few minutes ago', style: TextStyle(color: AppColors.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
