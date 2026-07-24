import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tane06_app/models/ui/screens/login_page.dart';
import 'package:tane06_app/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TanE06App());
}

class TanE06App extends StatelessWidget {
  const TanE06App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TanE-06 Health',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.wellnessTheme,
      home: const LoginPage(),
    );
  }
}
