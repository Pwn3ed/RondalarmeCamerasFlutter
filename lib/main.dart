import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/camera_provider.dart';
import 'theme/app_theme.dart';
import 'screens/cameras_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CameraProvider()),
      ],
      child: MaterialApp(
        title: 'Rondalarme Câmeras',
        theme: AppTheme.lightTheme,
        home: const CamerasListScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
