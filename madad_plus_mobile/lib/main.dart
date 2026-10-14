import 'package:flutter/material.dart';
import 'package:madad_plus_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'emergency_flow.dart';
import 'services/emergency_request_state.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.requestState});

  final EmergencyRequestState? requestState;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Madad+',
      theme: AppTheme.light,
      home: const EmergencyFlow(),
    );
    if(requestState != null) {
      return ChangeNotifierProvider<EmergencyRequestState>.value(
        value: requestState!,
        child: app,
      );
    }

    return ChangeNotifierProvider(
      create: (_) => EmergencyRequestState(),
      child: app,
    );
  }
}
