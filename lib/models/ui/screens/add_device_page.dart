import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

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
  State<AddDevicePage> createState() =>
      _AddDevicePageState();
}



class _AddDevicePageState extends State<AddDevicePage> {


  final DeviceRepository _deviceRepository =
      DeviceRepository();


  final MobileScannerController _cameraController =
      MobileScannerController();


  int _selectedTab = 0;

  bool _hasScanned = false;
  bool _isBinding = false;


  String? _errorMessage;


  final TextEditingController _imeiController =
      TextEditingController();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _modelController =
      TextEditingController(
        text: "TanE06",
      );


  String? _scannedImei;
  String? _scannedName;
  String? _scannedModel;



  @override
  void dispose() {

    _cameraController.dispose();

    _imeiController.dispose();
    _nameController.dispose();
    _modelController.dispose();

    super.dispose();
  }



  void _parseQrCode(String raw) {

    try {

      final data = jsonDecode(raw);


      if (data is Map) {

        final imei =
            data["imei"]?.toString()
            ??
            data["IMEI"]?.toString();


        if (imei != null) {

          setState(() {

            _scannedImei = imei;

            _scannedName =
                data["name"]?.toString()
                ??
                "Mason";

            _scannedModel =
                data["model"]?.toString()
                ??
                "TanE06";

            _imeiController.text = imei;

            _nameController.text =
                _scannedName!;

            _modelController.text =
                _scannedModel!;

            _errorMessage = null;

          });

          return;
        }

      }

    } catch (_) {}



    if (RegExp(r'^\d{14,16}$')
        .hasMatch(raw.trim())) {


      setState(() {

        _scannedImei = raw.trim();

        _scannedName = "Mason";

        _scannedModel = "TanE06";


        _imeiController.text =
            raw.trim();

        _nameController.text =
            "Mason";

        _modelController.text =
            "TanE06";

      });


    } else {

      setState(() {

        _errorMessage =
            "無法解析 QR Code";

      });

    }

  }



  Future<void> _bindDevice() async {


    final imei =
        _imeiController.text.trim();


    if (imei.isEmpty) {

      setState(() {

        _errorMessage =
            "請輸入 IMEI";

      });

      return;
    }


    setState(() {

      _isBinding = true;

      _errorMessage = null;

    });



    try {


      final Device device =
          await _deviceRepository.bindDevice(

            userId: widget.userId,

            imei: imei,

            name:
                _nameController.text.isEmpty
                ? "Mason"
                : _nameController.text,

            model:
                _modelController.text.isEmpty
                ? "TanE06"
                : _modelController.text,

          );



      if (mounted) {

        _showSuccess(device);

      }


    } catch(e) {


      setState(() {

        _errorMessage =
            e.toString();

      });


    } finally {


      setState(() {

        _isBinding = false;

      });

    }

  }





  void _showSuccess(Device device) {


    showDialog(

      context: context,

      builder: (_) {

        return AlertDialog(

          title:
              const Text(
                "綁定成功",
              ),


          content:
              Text(
                "${device.name}\n${device.imei}",
              ),


          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context);

                Navigator.pop(
                  context,
                  device,
                );

              },


              child:
                  const Text(
                    "完成",
                  ),

            ),

          ],

        );

      },

    );

  }







  @override
  Widget build(BuildContext context) {


    return Scaffold(

      backgroundColor:
          const Color(0xffF4F6FA),


      appBar:
          AppBar(

            title:
                const Text(
                  "新增綁定設備",
                ),

          ),



      body:
          SingleChildScrollView(

            padding:
                const EdgeInsets.all(20),


            child:
                Column(

                  children: [


                    _buildTabs(),


                    const SizedBox(height:20),



                    if (_selectedTab == 0)

                      _buildScanner()

                    else

                      _buildManual(),




                    if (_errorMessage != null)

                      Padding(

                        padding:
                            const EdgeInsets.only(top:16),

                        child:
                            Text(

                              _errorMessage!,

                              style:
                                  const TextStyle(
                                    color:Colors.red,
                                  ),

                            ),

                      ),



                    const SizedBox(height:20),



                    SizedBox(

                      width:
                          double.infinity,


                      child:
                          ElevatedButton(

                            onPressed:
                                _isBinding
                                ? null
                                : _bindDevice,


                            child:
                                Text(

                                  _isBinding
                                  ?
                                  "綁定中..."
                                  :
                                  "確認綁定",

                                ),

                          ),

                    )


                  ],

                ),

          ),

    );

  }








  Widget _buildTabs() {


    return Row(

      children: [

        Expanded(

          child:
              ElevatedButton(

                onPressed:(){

                  setState((){

                    _selectedTab=0;

                  });

                },


                child:
                    const Text(
                      "QR Scan",
                    ),

              ),

        ),



        const SizedBox(width:10),



        Expanded(

          child:
              ElevatedButton(

                onPressed:(){

                  setState((){

                    _selectedTab=1;

                  });

                },


                child:
                    const Text(
                      "IMEI",
                    ),

              ),

        )

      ],

    );

  }








  Future<void> _pickAndScanFromPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final BarcodeCapture? capture = await _cameraController.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? rawValue = capture.barcodes.first.rawValue;
        if (rawValue != null && rawValue.isNotEmpty) {
          _parseQrCode(rawValue);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已成功從相片讀取 QR Code！'),
                backgroundColor: Color(0xFF2E7D32),
              ),
            );
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _errorMessage = '相片中未發現有效的 QR Code，請重新選擇圖片';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '讀取相片失敗：$e';
        });
      }
    }
  }

  Widget _buildScanner() {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                MobileScanner(
                  controller: _cameraController,
                  onDetect: (BarcodeCapture capture) {
                    if (_hasScanned) return;
                    if (capture.barcodes.isEmpty) return;

                    final value = capture.barcodes.first.rawValue;
                    if (value != null) {
                      _hasScanned = true;
                      _parseQrCode(value);
                      Future.delayed(
                        const Duration(seconds: 2),
                        () {
                          _hasScanned = false;
                        },
                      );
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _pickAndScanFromPhoto,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
          label: const Text(
            '從相片/檔案讀取 QR Code',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        if (_scannedImei != null)
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text(
              "已掃描 $_scannedImei",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          )
      ],
    );
  }








  Widget _buildManual(){


    return Column(

      children:[


        TextField(

          controller:
              _imeiController,


          decoration:
              const InputDecoration(

                labelText:
                    "IMEI",

              ),

        ),


        TextField(

          controller:
              _nameController,


          decoration:
              const InputDecoration(

                labelText:
                    "名稱",

              ),

        ),


        TextField(

          controller:
              _modelController,


          decoration:
              const InputDecoration(

                labelText:
                    "型號",

              ),

        )


      ],

    );

  }


}