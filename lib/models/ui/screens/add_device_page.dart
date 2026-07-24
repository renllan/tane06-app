import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tane06_app/models/device.dart';
import 'package:tane06_app/models/api_response.dart';
import 'package:tane06_app/repositories/device_repository.dart';
import 'package:tane06_app/theme/app_theme.dart';

class AddDevicePage extends StatefulWidget {
  final int userId;

  const AddDevicePage({
    super.key,
    this.userId = 1,
  });

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage>
    with SingleTickerProviderStateMixin {
  final DeviceRepository _deviceRepository = DeviceRepository();

  int _selectedTab = 0; // 0 = QR Code Scan, 1 = Manual IMEI

  // Controllers
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _modelController =
      TextEditingController(text: 'TanE06');
  final TextEditingController _qrStringController = TextEditingController();

  // Scanner animation
  late AnimationController _scannerAnimController;
  late Animation<double> _scannerLineAnim;

  bool _isBinding = false;
  String? _errorMessage;

  // Parsed QR code cache
  String? _scannedImei;
  String? _scannedName;
  String? _scannedModel;

  @override
  void initState() {
    super.initState();
    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scannerLineAnim = CurvedAnimation(
      parent: _scannerAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scannerAnimController.dispose();
    _imeiController.dispose();
    _nameController.dispose();
    _modelController.dispose();
    _qrStringController.dispose();
    super.dispose();
  }

  /// Parses raw QR Code text (JSON or KV format)
  void _parseQrCodeString(String raw) {
    if (raw.trim().isEmpty) return;

    try {
      // Try JSON format
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        setState(() {
          _scannedImei = decoded['imei']?.toString() ??
              decoded['IMEI']?.toString() ??
              decoded['device_imei']?.toString();
          _scannedName = decoded['name']?.toString() ??
              decoded['NAME']?.toString() ??
              'Mason';
          _scannedModel = decoded['model']?.toString() ??
              decoded['MODEL']?.toString() ??
              'TanE06';
          _errorMessage = null;
        });
        if (_scannedImei != null) {
          _imeiController.text = _scannedImei!;
          _nameController.text = _scannedName ?? 'Mason';
          _modelController.text = _scannedModel ?? 'TanE06';
        }
        return;
      }
    } catch (_) {}

    // Fallback: If it's a plain IMEI string or key-value pairs
    final trimmed = raw.trim();
    if (RegExp(r'^\d{14,16}$').hasMatch(trimmed)) {
      setState(() {
        _scannedImei = trimmed;
        _scannedName = 'Mason';
        _scannedModel = 'TanE06';
        _errorMessage = null;
      });
      _imeiController.text = trimmed;
      _nameController.text = 'Mason';
      _modelController.text = 'TanE06';
    } else {
      // Try key-value format e.g. imei=868705080300689&name=Mason
      final pairs = trimmed.split(RegExp(r'[;,\n&]'));
      String? parsedImei, parsedName, parsedModel;
      for (final p in pairs) {
        final kv = p.split(RegExp(r'[:=]'));
        if (kv.length == 2) {
          final k = kv[0].trim().toLowerCase();
          final v = kv[1].trim();
          if (k == 'imei' || k == 'device_imei') parsedImei = v;
          if (k == 'name') parsedName = v;
          if (k == 'model') parsedModel = v;
        }
      }

      if (parsedImei != null) {
        setState(() {
          _scannedImei = parsedImei;
          _scannedName = parsedName ?? 'Mason';
          _scannedModel = parsedModel ?? 'TanE06';
          _errorMessage = null;
        });
        _imeiController.text = parsedImei;
        _nameController.text = parsedName ?? 'Mason';
        _modelController.text = parsedModel ?? 'TanE06';
      } else {
        setState(() {
          _errorMessage = '無法解析 QR Code 內容，請確認格式或使用手動輸入。';
        });
      }
    }
  }

  /// Triggers the device bind API request
  Future<void> _handleBindDevice() async {
    final imei = _imeiController.text.trim();
    final name = _nameController.text.trim();
    final model = _modelController.text.trim();

    if (imei.isEmpty) {
      setState(() => _errorMessage = '請輸入 15 位數的設備 IMEI');
      return;
    }

    setState(() {
      _isBinding = true;
      _errorMessage = null;
    });

    try {
      final boundDevice = await _deviceRepository.bindDevice(
        userId: widget.userId,
        imei: imei,
        name: name.isEmpty ? 'Mason' : name,
        model: model.isEmpty ? 'TanE06' : model,
      );

      if (mounted) {
        _showSuccessDialog(boundDevice);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiException) {
            _errorMessage = '綁定失敗：${e.error.message} (HTTP ${e.statusCode})';
          } else {
            _errorMessage = '綁定失敗：$e';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBinding = false);
      }
    }
  }

  void _showSuccessDialog(Device device, {bool isFallback = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 48),
            ),
            const SizedBox(height: 12),
            Text(
              '綁定成功！',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('設備名稱', device.name),
            const SizedBox(height: 6),
            _infoRow('IMEI 碼', device.imei ?? device.id),
            const SizedBox(height: 6),
            _infoRow('型號', device.model ?? 'TanE06'),
            if (isFallback) ...[
              const SizedBox(height: 10),
              Text(
                '（以離線 / 本地模式新增成功）',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(device); // Pop AddDevicePage with device
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                '回到首頁查看設備',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '新增綁定設備',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Selector Tabs
            _buildTabSelector(),
            const SizedBox(height: 20),

            // Tab Content
            if (_selectedTab == 0) _buildQrScannerTab() else _buildManualFormTab(),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFB00020), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFFB00020),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            // Bind Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isBinding ? null : _handleBindDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isBinding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link_rounded, size: 22),
                label: Text(
                  _isBinding ? '正在綁定設備中...' : '確認綁定此設備',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              index: 0,
              icon: Icons.qr_code_scanner_rounded,
              label: '掃描 QR Code',
            ),
          ),
          Expanded(
            child: _tabButton(
              index: 1,
              icon: Icons.edit_note_rounded,
              label: '手動輸入 IMEI',
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: QR Code Scanner ────────────────────────────────────────────────

  Widget _buildQrScannerTab() {
    return Column(
      children: [
        // Simulated Camera Viewfinder (Tap to simulate scan if no camera attached)
        GestureDetector(
          onTap: () {
            const sample = '{"imei": "868705080300689", "name": "Mason", "model": "TanE06"}';
            _qrStringController.text = sample;
            _parseQrCodeString(sample);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已對焦並自動感應條碼內容！', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Grid lines effect
                Center(
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.6),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        // Animated scanning line
                        AnimatedBuilder(
                          animation: _scannerLineAnim,
                          builder: (_, __) {
                            return Positioned(
                              top: _scannerLineAnim.value * 150,
                              left: 8,
                              right: 8,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Corner overlay markers
                const Positioned(
                  top: 24,
                  left: 24,
                  child: Icon(Icons.crop_free_rounded,
                      color: Colors.white70, size: 28),
                ),
                // Flash / Camera status indicator
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_rounded,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '點擊畫面模擬掃描',
                          style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                // Center hint text
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Text(
                    '無鏡頭時請點擊畫面，或使用下方測試按鈕 / 貼上條碼內容',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Quick Scan Preset Buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.touch_app_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '點擊測試條碼或貼上 QR 內容：',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetQrChip(
                    label: 'Scan Mason (868705080300689)',
                    qrText:
                        '{"imei": "868705080300689", "name": "Mason", "model": "TanE06"}',
                  ),
                  _presetQrChip(
                    label: 'Scan TanE06 Demo (868705080300690)',
                    qrText:
                        '{"imei": "868705080300690", "name": "TanE06 Demo", "model": "TanE06"}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _qrStringController,
                decoration: InputDecoration(
                  labelText: '貼上 QR Code 解析內容 / 文字',
                  hintText: 'e.g. {"imei": "868705080300689", "name": "Mason"}',
                  prefixIcon: const Icon(Icons.paste_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_2_rounded,
                        color: AppColors.primary),
                    onPressed: () {
                      _parseQrCodeString(_qrStringController.text);
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) => _parseQrCodeString(val),
              ),
            ],
          ),
        ),

        if (_scannedImei != null) ...[
          const SizedBox(height: 16),
          // Preview parsed result card
          _buildParsedPreviewCard(),
        ],
      ],
    );
  }

  Widget _presetQrChip({required String label, required String qrText}) {
    return GestureDetector(
      onTap: () {
        _qrStringController.text = qrText;
        _parseQrCodeString(qrText);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2_rounded,
                color: AppColors.primary, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF6F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '已成功擷取 QR Code 資訊：',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _previewItem('IMEI 碼', _scannedImei!),
          _previewItem('設備名稱', _scannedName ?? 'Mason'),
          _previewItem('型號', _scannedModel ?? 'TanE06'),
        ],
      ),
    );
  }

  Widget _previewItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            val,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Manual Form ───────────────────────────────────────────────────

  Widget _buildManualFormTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '請輸入手錶的 IMEI 碼與名稱',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'IMEI 通常印於手錶背面貼紙或外盒條碼下方。',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // IMEI Input
          TextField(
            controller: _imeiController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '設備 IMEI 碼 *',
              hintText: '15 位數字 (例如 868705080300689)',
              prefixIcon: const Icon(Icons.fingerprint_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                onPressed: () {
                  _imeiController.text = '868705080300689';
                  if (_nameController.text.isEmpty) {
                    _nameController.text = 'Mason';
                  }
                },
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Name Input
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '設備名稱 / 佩戴者',
              hintText: '例如 Mason、父親的手錶',
              prefixIcon: const Icon(Icons.badge_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Model Input
          TextField(
            controller: _modelController,
            decoration: InputDecoration(
              labelText: '設備型號',
              hintText: 'TanE06',
              prefixIcon: const Icon(Icons.watch_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
