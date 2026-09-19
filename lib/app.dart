import 'package:flutter/material.dart';

import 'screens/role_selection_screen.dart';

class PranaSarathiApp extends StatelessWidget {
  const PranaSarathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PrāṇaSārathi',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.red,
      ),
      home: const RoleSelectionScreen(),
    );
  }
}
