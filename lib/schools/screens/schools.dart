import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pushtrial/auth/login.dart';
import 'package:pushtrial/config/app_config.dart';
import 'package:pushtrial/config/theme_controller.dart';
import 'package:pushtrial/schools/api/school_api.dart';
import 'package:pushtrial/schools/models/schools.dart';
import 'package:pushtrial/widgets/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SchoolScreen extends StatefulWidget {
  const SchoolScreen({super.key});

  @override
  State<SchoolScreen> createState() => _SchoolScreenState();
}

class _SchoolScreenState extends State<SchoolScreen> {
  // Essentiel's own colour, the same one the login screen falls back to.
  static const _brandRed = Color(0xFFD71920);

  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String host = SchoolApi().getImage();
  List<School> schoolNames = [];
  List<School> filteredSchoolNames = [];
  bool loading = true;
  bool hasLoadError = false;
  bool selectingSchool = false;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterSchools);
    _initializeData();
  }

  Future<void> _initializeData({bool showLoading = true}) async {
    setState(() {
      if (showLoading) loading = true;
      hasLoadError = false;
    });
    try {
      final list = await _loadSchoolList();
      final schools = list.map((item) => School.fromJson(item)).toList()
        ..sort((a, b) => a.schoolname.compareTo(b.schoolname));
      if (!mounted) return;
      setState(() {
        schoolNames = schools;
        filteredSchoolNames = _matchesQuery(schools);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => hasLoadError = true);
    } finally {
      if (mounted && showLoading) setState(() => loading = false);
    }
  }

  // The test list (passed in at build time, never bundled) is used only in test mode.
  Future<Iterable> _loadSchoolList() async {
    if (AppConfig.useTestSchools) {
      return json.decode(AppConfig.testSchoolsJson) as List;
    }
    final response = await SchoolApi().getSchoolList();
    if (response.statusCode != 200) {
      throw Exception('Unable to load schools');
    }
    return json.decode(response.body.toString()) as List;
  }

  List<School> _matchesQuery(List<School> schools) {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return schools;
    return schools.where((school) {
      return school.schoolname.toLowerCase().contains(query) ||
          school.schoolabrv.toLowerCase().contains(query);
    }).toList();
  }

  void _filterSchools() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => filteredSchoolNames = _matchesQuery(schoolNames));
  }

  void _toast(String message) {
    if (!mounted) return;
    ShadToaster.of(context).show(ShadToast.destructive(description: Text(message)));
  }

  Future<void> _toggleTheme() async {
    final controller = AppThemeController.instance;
    final saved = await controller.setDark(!controller.isDark);
    if (!saved) _toast('Could not save your appearance setting.');
  }

  Future<void> _selectSchool(School school) async {
    if (selectingSchool) return;
    if (school.eslink.isEmpty) {
      _toast('This school is currently unavailable.');
      return;
    }
    setState(() => selectingSchool = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedSchool', AppConfig.secureUrl(school.eslink));
      await prefs.setString('schoolVersion', school.schoolVersion);
      await prefs.setInt('selectedSchoolId', school.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (_) {
      _toast('Could not open this school. Please try again.');
    } finally {
      if (mounted) setState(() => selectingSchool = false);
    }
  }

  @override
  void dispose() {
    searchController.removeListener(_filterSchools);
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _shade(Color color, double lightnessDelta) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final headerStart = _shade(_brandRed, -0.02);
    final headerEnd = _shade(_brandRed, -0.16);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The header is always dark red, so the status bar icons are always light.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // Shows behind the rounded top corners of the list, so it matches the header's end.
        backgroundColor: headerEnd,
        body: Column(
          children: [
            _buildHeader(headerStart, headerEnd),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: ColoredBox(
                  color: scheme.background,
                  child: _buildDirectory(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color start, Color end) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    const onHeader = Colors.white;
    const searchRadius = BorderRadius.all(Radius.circular(16));
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [start, end],
        ),
      ),
      child: CustomPaint(
        painter: const _HeaderDecorPainter(Color(0x1AFFFFFF)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Gap.lg,
            MediaQuery.paddingOf(context).top + Gap.sm,
            Gap.lg,
            Gap.lg + Gap.xs,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const EssentielMark(size: 52),
                      const Spacer(),
                      ListenableBuilder(
                        listenable: AppThemeController.instance,
                        builder: (context, child) => Semantics(
                          button: true,
                          label: AppThemeController.instance.isDark
                              ? 'Switch to light mode'
                              : 'Switch to dark mode',
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _toggleTheme,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  AppThemeController.instance.isDark
                                      ? LucideIcons.sun
                                      : LucideIcons.moon,
                                  color: onHeader,
                                  size: IconSize.row,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: keyboardOpen
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Gap.hXl,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Gap.md,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.users,
                                      size: 14,
                                      color: onHeader,
                                    ),
                                    Gap.wSm,
                                    Text(
                                      'Student & Parent Portal',
                                      style: text.small.copyWith(
                                        color: onHeader,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Gap.hMd,
                              Text(
                                'Find your school',
                                style: text.h2.copyWith(
                                  color: onHeader,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Gap.hXs,
                              Text(
                                'Choose your school to sign in and follow grades, attendance and billing.',
                                style: text.muted.copyWith(
                                  color: onHeader.withValues(alpha: 0.85),
                                ),
                              ),
                              Gap.hLg,
                            ],
                          ),
                  ),
                  if (keyboardOpen) Gap.hMd,
                  ShadInput(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    placeholder: const Text('Search by school name or code'),
                    leading: Icon(
                      LucideIcons.search,
                      size: IconSize.row,
                      color: scheme.mutedForeground,
                    ),
                    trailing: searchController.text.isEmpty
                        ? null
                        : ShadButton.ghost(
                            onPressed: searchController.clear,
                            child: Icon(
                              LucideIcons.x,
                              size: IconSize.inline,
                              color: scheme.mutedForeground,
                            ),
                          ),
                    decoration: ShadDecoration(
                      color: scheme.card,
                      border: const ShadBorder.fromBorderSide(
                        ShadBorderSide(color: Colors.transparent, width: 1.5),
                        radius: searchRadius,
                      ),
                      focusedBorder: ShadBorder.fromBorderSide(
                        ShadBorderSide(color: scheme.primary, width: 1.5),
                        radius: searchRadius,
                      ),
                      // The soft ring around the focused field, white so it shows on the red.
                      secondaryFocusedBorder: ShadBorder.fromBorderSide(
                        ShadBorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 4,
                        ),
                        radius: const BorderRadius.all(Radius.circular(20)),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectory() {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    if (loading) return const LoadingSkeleton();
    if (hasLoadError) {
      return ErrorState(
        title: 'Could not load schools',
        onRetry: _initializeData,
      );
    }
    if (filteredSchoolNames.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyState(
            icon: LucideIcons.searchX,
            title: schoolNames.isEmpty
                ? 'No schools available'
                : 'No schools found',
            message: schoolNames.isEmpty
                ? 'Please check back later.'
                : 'Try a different name or abbreviation.',
          ),
          if (searchController.text.isNotEmpty)
            ShadButton.outline(
              onPressed: searchController.clear,
              child: const Text('Clear search'),
            ),
        ],
      );
    }
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 900
                ? 4
                : width >= 600
                ? 3
                : 2;
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final count = filteredSchoolNames.length;
            return RefreshIndicator(
              color: scheme.primary,
              onRefresh: () => _initializeData(showLoading: false),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      Gap.xl,
                      Gap.lg,
                      Gap.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              searchController.text.trim().isEmpty
                                  ? 'All schools'
                                  : 'Results',
                              style: text.large.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count ${count == 1 ? 'school' : 'schools'}',
                              style: text.small.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      Gap.lg,
                      0,
                      Gap.lg,
                      Gap.xl + bottomInset,
                    ),
                    sliver: SliverGrid.builder(
                      itemCount: count,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: Gap.md,
                        mainAxisSpacing: Gap.md,
                        mainAxisExtent: 200 + (textScale - 1) * 80,
                      ),
                      itemBuilder: (context, index) =>
                          _buildSchoolCard(filteredSchoolNames[index]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSchoolCard(School school) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      label: 'Open ${school.schoolname}',
      child: Container(
        decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: radius,
          border: Border.all(color: scheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: selectingSchool ? null : () => _selectSchool(school),
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.all(Gap.sm),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.border),
                    ),
                    child: ClipOval(
                      child: school.schoollogo.isEmpty
                          ? _fallbackLogo()
                          : CachedNetworkImage(
                              imageUrl: '$host${school.schoollogo}',
                              fit: BoxFit.contain,
                              placeholder: (context, url) => _fallbackLogo(),
                              errorWidget: (context, url, error) =>
                                  _fallbackLogo(),
                            ),
                    ),
                  ),
                  Gap.hMd,
                  Text(
                    school.schoolname,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.small.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            school.schoolabrv.isEmpty ? 'School' : school.schoolabrv,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.small.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ),
                      ),
                      Gap.wSm,
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.arrowRight,
                          color: scheme.primaryForeground,
                          size: IconSize.inline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // A school without a logo of its own shows the Essentiel logo.
  Widget _fallbackLogo() =>
      const Padding(padding: EdgeInsets.all(Gap.xs), child: EssentielEmblem());
}

/// Soft translucent circles on the header, the same decoration the login screen uses.
class _HeaderDecorPainter extends CustomPainter {
  const _HeaderDecorPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(size.width * 0.94, size.height * 0.12), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.04, size.height * 0.46), 54, paint);
    canvas.drawCircle(Offset(size.width * 0.76, size.height * 0.34), 34, paint);
  }

  @override
  bool shouldRepaint(_HeaderDecorPainter oldDelegate) => oldDelegate.color != color;
}
