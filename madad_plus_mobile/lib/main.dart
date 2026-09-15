import 'package:flutter/material.dart';
import 'package:madad_plus_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'emergency_flow.dart';
import 'services/emergency_request_state.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmergencyRequestState(),
      child: MaterialApp(
        title: 'Madad+',
        theme: AppTheme.light,
        home: const EmergencyFlow(),
      ),
    );
  }
}
