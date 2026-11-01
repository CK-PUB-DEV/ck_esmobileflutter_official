import 'package:flutter/material.dart';
import 'package:pushtrial/widgets/service_status_page.dart';
import 'package:pushtrial/widgets/ui/ui.dart';

class ClearanceScreen extends StatelessWidget {
  const ClearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ServiceStatusPage(
      title: 'Clearance',
      serviceKey: 'clearance',
      featureName: 'clearance',
      icon: LucideIcons.fileCheck,
    );
  }
}
