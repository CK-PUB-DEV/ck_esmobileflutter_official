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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: ShadTheme.of(context).colorScheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildDirectory()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: keyboardOpen
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: theme.radius,
                                ),
                                child: Icon(
                                  LucideIcons.graduationCap,
                                  color: scheme.primaryForeground,
                                  size: IconSize.row,
                                ),
                              ),
                              Gap.wSm,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Essentiel', style: text.large),
                                    Text('Student portal', style: text.muted),
                                  ],
                                ),
                              ),
                              ListenableBuilder(
                                listenable: AppThemeController.instance,
                                builder: (context, child) => Semantics(
                                  button: true,
                                  label: AppThemeController.instance.isDark
                                      ? 'Switch to light mode'
                                      : 'Switch to dark mode',
                                  child: ShadIconButton.outline(
                                    onPressed: _toggleTheme,
                                    icon: Icon(
                                      AppThemeController.instance.isDark
                                          ? LucideIcons.sun
                                          : LucideIcons.moon,
                                      size: IconSize.row,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Gap.hXl,
                          Text('Find your school', style: text.h2),
                          Gap.hXs,
                          Text(
                            'Choose your school to continue to your student portal.',
                            style: text.muted,
                          ),
                          Gap.hLg,
                        ],
                      ),
              ),
              ShadInput(
                controller: searchController,
                textInputAction: TextInputAction.search,
                placeholder: const Text('Search schools'),
                leading: const Icon(LucideIcons.search, size: IconSize.row),
                trailing: searchController.text.isEmpty
                    ? null
                    : ShadButton.ghost(
                        onPressed: searchController.clear,
                        child: const Icon(
                          LucideIcons.x,
                          size: IconSize.inline,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectory() {
    final theme = ShadTheme.of(context);
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
            return RefreshIndicator(
              color: theme.colorScheme.primary,
              onRefresh: () => _initializeData(showLoading: false),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      Gap.md,
                      Gap.lg,
                      Gap.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Schools', style: text.large),
                          Text(
                            '${filteredSchoolNames.length} ${filteredSchoolNames.length == 1 ? 'school' : 'schools'}',
                            style: text.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      0,
                      Gap.lg,
                      Gap.xl,
                    ),
                    sliver: SliverGrid.builder(
                      itemCount: filteredSchoolNames.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: Gap.md,
                        mainAxisSpacing: Gap.md,
                        mainAxisExtent: 184 + (textScale - 1) * 80,
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
    return Semantics(
      button: true,
      label: 'Open ${school.schoolname}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selectingSchool ? null : () => _selectSchool(school),
        child: ShadCard(
          padding: Gap.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(Gap.xs),
                decoration: BoxDecoration(
                  color: scheme.muted,
                  borderRadius: theme.radius,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Gap.sm),
                  child: school.schoollogo.isEmpty
                      ? _fallbackLogo()
                      : CachedNetworkImage(
                          imageUrl: '$host${school.schoollogo}',
                          fit: BoxFit.contain,
                          placeholder: (context, url) => _fallbackLogo(),
                          errorWidget: (context, url, error) => _fallbackLogo(),
                        ),
                ),
              ),
              Gap.hMd,
              Text(
                school.schoolname,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.small.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ShadBadge.secondary(
                      child: Text(
                        school.schoolabrv.isEmpty ? 'School' : school.schoolabrv,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Gap.wSm,
                  Icon(
                    LucideIcons.chevronRight,
                    color: scheme.mutedForeground,
                    size: IconSize.row,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackLogo() =>
      Image.asset('assets/cklogo.png', fit: BoxFit.contain);
}
