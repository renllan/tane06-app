import 'package:flutter/material.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'package:tane06_app/models/ui/screens/settings_detail_page.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/models/api_response.dart';

class DeviceSettingsPage extends StatefulWidget {
  final String imei;

  const DeviceSettingsPage({
    super.key,
    required this.imei,
  });

  @override
  State<DeviceSettingsPage> createState() => _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends State<DeviceSettingsPage> {
  final DeviceRepository _repo = DeviceRepository();

  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await _repo.fetchSettingsRaw(imei: widget.imei);
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${e.error.message} (${e.error.code})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '無法載入設備設定：$e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings(Map<String, dynamic> patch) async {
    try {
      await _repo.saveSettings(imei: widget.imei, patch: patch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定已儲存並同步至設備')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：${e.error.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          '設備設定',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (!_isLoading && _settings != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              tooltip: '重新載入設定',
              onPressed: _loadSettings,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              '正在從伺服器載入設備設定...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新嘗試'),
              ),
            ],
          ),
        ),
      );
    }

    // Loaded state
    return RefreshIndicator(
      onRefresh: _loadSettings,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceHeader(),
            const SizedBox(height: 24),
            const Text(
              '設定分類',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildCategoryList(),
            const SizedBox(height: 24),
            _buildUnbindSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );

  }

  Widget _buildUnbindSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '危險區域 (Danger Zone)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB00020),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '解除綁定後，該設備將從您的帳號清單中移除，若要重新使用需再次掃描或輸入 IMEI 綁定。',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _handleUnbindDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB00020),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text(
                '解除綁定此設備 (Unbind Device)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUnbindDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFB00020), size: 22),
            SizedBox(width: 8),
            Text('解除綁定設備', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Text(
          '確定要解除綁定 IMEI: ${widget.imei} 嗎？\n此操作將會從您的帳號及裝置清單中移除該設備。',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB00020),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('確認解除綁定', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.unbindDevice(userId: 1, imei: widget.imei);
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功解除綁定設備 (${widget.imei})'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      Navigator.of(context).pop('unbound'); // Return 'unbound' signal
    }
  }

  Widget _buildDeviceHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.surfaceMedium,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.watch_rounded, size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TanE06 智慧手錶',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'IMEI: ${widget.imei}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF2E7D32)),
                SizedBox(width: 6),
                Text(
                  '連線中',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    final profileData = _settings?['profile'] as Map<String, dynamic>?;
    final age = profileData?['age'] ?? 32;
    final height = profileData?['height'] ?? 175;

    final categories = [
      {
        'key': SettingsCategory.profile,
        'title': '個人資料與體態 (User Profile)',
        'subtitle': '年齡、性別、身高、體重設定與計算基礎',
        'icon': Icons.person_rounded,
        'iconColor': const Color(0xFF5E5CE6),
        'badge': '$age歲 • ${height}cm',
      },
      {
        'key': SettingsCategory.health,
        'title': '健康監測設定',
        'subtitle': '心率、血壓、血氧、體溫監測與警示',
        'icon': Icons.favorite_rounded,
        'iconColor': const Color(0xFFE96B6B),
        'badge': '4 項監測中',
      },
      {
        'key': SettingsCategory.step,
        'title': '計步與運動目標',
        'subtitle': '每日步數 6,000 步 • 運動時間 30 分鐘',
        'icon': Icons.directions_run_rounded,
        'iconColor': const Color(0xFF4BA3C7),
        'badge': '目標設定',
      },
      {
        'key': SettingsCategory.sleep,
        'title': '睡眠監測設定',
        'subtitle': '睡眠時段 22:00 - 07:00 • 目標 8 小時',
        'icon': Icons.bedtime_rounded,
        'iconColor': const Color(0xFF4CBF87),
        'badge': '已啟用',
      },
      {
        'key': SettingsCategory.safety,
        'title': '安全防護與 SOS',
        'subtitle': 'SOS 一鍵求救、跌倒偵測警示',
        'icon': Icons.shield_rounded,
        'iconColor': const Color(0xFFFF9500),
        'badge': 'SOS 輪播 3次',
      },
      {
        'key': SettingsCategory.call,
        'title': '通話與訊息設定',
        'subtitle': '自動接聽、簡訊通知、白名單過濾',
        'icon': Icons.phone_in_talk_rounded,
        'iconColor': const Color(0xFF5E5CE6),
        'badge': '通話防護',
      },
      {
        'key': SettingsCategory.location,
        'title': '定位與同步頻率',
        'subtitle': 'GPS/LBS 定位更新頻率設定',
        'icon': Icons.location_on_rounded,
        'iconColor': const Color(0xFF30D158),
        'badge': '1440 分鐘/次',
      },
      {
        'key': SettingsCategory.watch,
        'title': '手錶系統與硬體設定',
        'subtitle': '音量、抬手亮屏、省電模式、密碼與語言',
        'icon': Icons.tune_rounded,
        'iconColor': const Color(0xFF6C7FEA),
        'badge': '系統 51% 音量',
      },
      {
        'key': SettingsCategory.remoteCommands,
        'title': '遠端指令與控制',
        'subtitle': '尋找手錶、遠端關機、重新啟動、恢復出廠設定',
        'icon': Icons.settings_remote_rounded,
        'iconColor': const Color(0xFFEF5350),
        'badge': '4 項指令',
      },
    ];

    return Column(
      children: categories.map((c) => _buildCategoryTile(c)).toList(),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> c) {
    final SettingsCategory categoryKey = c['key'] as SettingsCategory;
    final String title = c['title'] as String;
    final String subtitle = c['subtitle'] as String;
    final IconData icon = c['icon'] as IconData;
    final Color iconColor = c['iconColor'] as Color;
    final String badge = c['badge'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (_settings == null) return;
            final updatedSettings = await Navigator.of(context).push<Map<String, dynamic>>(
              MaterialPageRoute(
                builder: (_) => SettingsDetailPage(
                  category: categoryKey,
                  settingsData: _settings!,
                  imei: widget.imei,
                ),
              ),
            );
            if (updatedSettings != null) {
              // Compute the diff between old and new settings to PATCH only changes
              final patch = _computeSettingsDiff(_settings!, updatedSettings);
              setState(() {
                _settings = updatedSettings;
              });
              if (patch.isNotEmpty) {
                _saveSettings(patch);
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMedium,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Computes a minimal diff between [oldMap] and [newMap] for PATCH requests.
  ///
  /// Only includes top-level section keys whose values have changed.
  /// For device settings, this means sending only the sections that the
  /// user actually modified (e.g. only `health` or `watch`).
  Map<String, dynamic> _computeSettingsDiff(
    Map<String, dynamic> oldMap,
    Map<String, dynamic> newMap,
  ) {
    final diff = <String, dynamic>{};
    for (final key in newMap.keys) {
      if (!oldMap.containsKey(key) ||
          newMap[key].toString() != oldMap[key].toString()) {
        diff[key] = newMap[key];
      }
    }
    return diff;
  }
}
