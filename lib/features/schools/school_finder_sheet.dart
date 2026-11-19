import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pushtrial/core/config/app_config.dart';
import 'package:pushtrial/features/schools/api/school_api.dart';
import 'package:pushtrial/features/schools/models/schools.dart';
import 'package:pushtrial/features/schools/school_matcher.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Opens the school finder over the sign-in screen and returns the school the person picked, or
/// null when they close it. The sheet only searches: saving the choice is the caller's job.
Future<School?> showSchoolFinder(BuildContext context) {
  return showModalBottomSheet<School>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: ShadTheme.of(context).colorScheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => const _SchoolFinderSheet(),
  );
}

class _SchoolFinderSheet extends StatefulWidget {
  const _SchoolFinderSheet();

  @override
  State<_SchoolFinderSheet> createState() => _SchoolFinderSheetState();
}

class _SchoolFinderSheetState extends State<_SchoolFinderSheet> {
  /// Kept for the run, so reopening the sheet is instant. Only used to match what is typed; it is
  /// never drawn as a list.
  static List<School>? _cache;

  final _search = TextEditingController();
  final String _host = SchoolApi().getImage();
  List<School> _schools = [];
  SchoolMatches _matches = const SchoolMatches(SchoolMatchKind.idle);
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final cached = _cache;
    if (cached != null && !force) {
      _schools = cached;
      _loading = false;
      return;
    }
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final Iterable list;
      if (AppConfig.useTestSchools) {
        list = json.decode(AppConfig.testSchoolsJson) as List;
      } else {
        final response = await SchoolApi().getSchoolList();
        if (response.statusCode != 200) throw Exception('Unable to load schools');
        list = json.decode(response.body.toString()) as List;
      }
      final schools = list.map((item) => School.fromJson(item)).toList()
        ..sort((a, b) => a.schoolname.compareTo(b.schoolname));
      _cache = schools;
      if (!mounted) return;
      setState(() {
        _schools = schools;
        _matches = SchoolMatcher.find(schools, _search.text);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onChanged() =>
      setState(() => _matches = SchoolMatcher.find(_schools, _search.text));

  /// The keyboard's search key opens the school when only one fits.
  void _submit() {
    if (_matches.schools.length == 1) _pick(_matches.schools.first);
  }

  void _pick(School school) {
    if (school.eslink.isEmpty) return;
    Navigator.of(context).pop(school);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final text = ShadTheme.of(context).textTheme;
    final scheme = ShadTheme.of(context).colorScheme;
    final keyboard = media.viewInsets.bottom;
    // Tall enough for five results, short enough that the keyboard never covers the field.
    final height = (media.size.height * 0.78).clamp(0.0, media.size.height - keyboard - 72);
    final radius = BorderRadius.circular(AppRadius.pill);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find your school', style: text.h4.copyWith(fontWeight: FontWeight.w800)),
                      Gap.hXs,
                      Text('Enter your school code or name.', style: text.muted),
                      Gap.hLg,
                      ShadInput(
                        controller: _search,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _submit(),
                        // Codes and names are not words to correct or suggest.
                        autocorrect: false,
                        enableSuggestions: false,
                        placeholder: const Text('School code or name'),
                        leading: Icon(
                          LucideIcons.search,
                          size: IconSize.row,
                          color: scheme.mutedForeground,
                        ),
                        trailing: _search.text.isEmpty
                            ? null
                            : ShadButton.ghost(
                                onPressed: _search.clear,
                                child: Icon(
                                  LucideIcons.x,
                                  size: IconSize.inline,
                                  color: scheme.mutedForeground,
                                ),
                              ),
                        decoration: ShadDecoration(
                          color: scheme.muted.withValues(alpha: 0.6),
                          border: ShadBorder.fromBorderSide(
                            const ShadBorderSide(color: Colors.transparent, width: 1.5),
                            radius: radius,
                          ),
                          focusedBorder: ShadBorder.fromBorderSide(
                            ShadBorderSide(color: scheme.primary, width: 1.5),
                            radius: radius,
                          ),
                          secondaryFocusedBorder: ShadBorder.fromBorderSide(
                            ShadBorderSide(
                              color: scheme.primary.withValues(alpha: 0.25),
                              width: 4,
                            ),
                            radius: radius,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.of(context, const Duration(milliseconds: 220)),
                    switchInCurve: Curves.easeOutCubic,
                    child: _body(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loadFailed) {
      return ErrorState(
        key: const ValueKey('error'),
        title: 'Could not load schools',
        onRetry: () => _load(force: true),
      );
    }
    if (_loading && _search.text.trim().isNotEmpty) {
      return const Center(
        key: ValueKey('loading'),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    switch (_matches.kind) {
      case SchoolMatchKind.idle:
        return const EmptyState(
          key: ValueKey('idle'),
          icon: LucideIcons.school,
          title: 'Enter your school code',
          message: 'No code? Type the name of your school instead.',
        );
      case SchoolMatchKind.none:
        return Column(
          key: const ValueKey('none'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyState(
              icon: LucideIcons.searchX,
              title: 'No school matches that',
              message: 'Check the spelling, or ask your school for its code.',
            ),
            ShadButton.outline(onPressed: _search.clear, child: const Text('Clear')),
          ],
        );
      case SchoolMatchKind.exactCode:
      case SchoolMatchKind.results:
        return _results();
    }
  }

  Widget _results() {
    final text = ShadTheme.of(context).textTheme;
    final schools = _matches.schools;
    final exact = _matches.kind == SchoolMatchKind.exactCode;
    final heading = exact ? 'School found' : 'Schools matching your search';
    return ListView(
      key: const ValueKey('matches'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        Gap.xl,
        Gap.lg,
        Gap.xl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Semantics(
          liveRegion: true,
          label: exact
              ? heading
              : '${schools.length} ${schools.length == 1 ? 'school' : 'schools'} found',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
              child: Text(heading, style: text.large.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        Gap.hMd,
        for (final school in schools) _row(school),
      ],
    );
  }

  Widget _row(School school) {
    final scheme = ShadTheme.of(context).colorScheme;
    final tone = SchoolTone.current(context);
    final unavailable = school.eslink.isEmpty;
    return ListRow(
      title: school.schoolname,
      subtitle: unavailable
          ? 'Currently unavailable'
          : (school.schoolabrv.isEmpty ? null : school.schoolabrv),
      semanticLabel: unavailable
          ? '${school.schoolname}, currently unavailable'
          : 'Choose ${school.schoolname}',
      leading: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(Gap.xs + 2),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.border),
        ),
        child: ClipOval(
          child: school.schoollogo.isEmpty
              ? _fallbackLogo()
              : CachedNetworkImage(
                  imageUrl: '$_host${school.schoollogo}',
                  fit: BoxFit.contain,
                  placeholder: (context, url) => _fallbackLogo(),
                  errorWidget: (context, url, error) => _fallbackLogo(),
                ),
        ),
      ),
      trailing: unavailable
          ? null
          : Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: tone.solid, shape: BoxShape.circle),
              child: Icon(LucideIcons.arrowRight, color: tone.onSolid, size: IconSize.inline),
            ),
      onTap: unavailable ? null : () => _pick(school),
    );
  }

  // A school without a logo of its own shows the Essentiel logo.
  Widget _fallbackLogo() =>
      const Padding(padding: EdgeInsets.all(Gap.xs), child: EssentielEmblem());
}
