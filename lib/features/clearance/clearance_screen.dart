import 'package:flutter/material.dart';
import 'package:pushtrial/shared/widgets/service_status_screen.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';

class ClearanceScreen extends StatelessWidget {
  const ClearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ServiceStatusScreen(
      title: 'Clearance',
      serviceKey: 'clearance',
      featureName: 'clearance',
      icon: LucideIcons.fileCheck,
    );
  }
}
