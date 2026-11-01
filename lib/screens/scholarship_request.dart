import 'package:flutter/material.dart';
import 'package:pushtrial/widgets/service_status_page.dart';
import 'package:pushtrial/widgets/ui/ui.dart';

class ScholarshipRequestScreen extends StatelessWidget {
  const ScholarshipRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ServiceStatusPage(
      title: 'Scholarship request',
      serviceKey: 'scholarship',
      featureName: 'scholarship requests',
      icon: LucideIcons.graduationCap,
    );
  }
}
