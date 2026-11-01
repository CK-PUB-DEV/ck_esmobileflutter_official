import 'package:flutter/material.dart';
import 'package:pushtrial/services/student_services.dart';
import 'package:pushtrial/widgets/ui/ui.dart';

/// Page for a student service the app can't show yet. Says which case it is, as the school's
/// server reports it: the school doesn't use it, or it uses it on the portal and it is coming
/// to the app.
class ServiceStatusPage extends StatelessWidget {
  const ServiceStatusPage({
    super.key,
    required this.title,
    required this.serviceKey,
    required this.featureName,
    required this.icon,
  });

  final String title;

  /// The key in the server's `services` answer (e.g. `clearance`).
  final String serviceKey;

  /// How the feature is named in a sentence (e.g. "clearance").
  final String featureName;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: title,
      body: FutureBuilder<StudentServices>(
        future: StudentServices.load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingSkeleton(cards: 1);
          switch (snapshot.data![serviceKey]) {
            case ServiceState.notUsed:
              return EmptyState(
                icon: icon,
                title: 'Not used at your school',
                message: 'Your school does not use $featureName.',
              );
            case ServiceState.comingSoon:
              return EmptyState(
                icon: icon,
                title: 'Coming soon to the app',
                message: 'Your school uses $featureName on the student portal. It will be added to the app soon.',
              );
            case ServiceState.available:
            case ServiceState.unknown:
              return EmptyState(
                icon: icon,
                title: 'Not available right now',
                message: 'We are working on making this feature available soon. Please check back later.',
              );
          }
        },
      ),
    );
  }
}
