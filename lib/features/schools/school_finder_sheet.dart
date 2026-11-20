import 'dart:async';
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
  /// The whole directory, held only when it has to be: a test build, or a directory server that
  /// has no search yet (it answers 404). Null means every lookup asks the server, which sends back
  /// at most five schools, so the phone never holds the full list.
  static List<School>? _localList;

  final _search = TextEditingController();
  final String _host = SchoolApi().getImage();
  SchoolMatches _matches = const SchoolMatches(SchoolMatchKind.idle);
  bool _loading = false;
  bool _loadFailed = false;
  Timer? _debounce;

  /// Only the newest lookup may change the screen, so a slow answer never replaces a newer one.
  int _lookupId = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final enough =
        SchoolMatcher.normalize(_search.text).length >=
        SchoolMatcher.minCodeLength;
    if (!enough) {
      _lookupId++;
      setState(() {
        _matches = const SchoolMatches(SchoolMatchKind.idle);
        _loading = false;
        _loadFailed = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 300), _lookup);
  }

  Future<void> _lookup() async {
    final text = _search.text;
    final id = ++_lookupId;
    try {
      final matches = await _find(text);
      if (!mounted || id != _lookupId) return;
      setState(() {
        _matches = matches;
        _loadFailed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _lookupId) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  Future<SchoolMatches> _find(String text) async {
    if (AppConfig.useTestSchools) {
      return SchoolMatcher.find(_testSchools(), text);
    }
    if (_localList == null) {
      final response = await SchoolApi().searchSchools(text);
      var noSearchYet =
          response.statusCode == 404 || response.statusCode == 405;
      if (response.statusCode == 200) {
        try {
          return SchoolMatcher.fromServer(_parse(response.body), text);
        } catch (_) {
          // A 200 that is not a school list (a catch-all page, for example) means the
          // directory has no real search yet.
          noSearchYet = true;
        }
      }
      // 404 / 405 / unreadable 200: the directory has no search yet, so use the old list.
      if (!noSearchYet) throw Exception('Unable to search schools');
      final all = await SchoolApi().getSchoolList();
      if (all.statusCode != 200) throw Exception('Unable to load schools');
      _localList = _parse(all.body.toString())
        ..sort((a, b) => a.schoolname.compareTo(b.schoolname));
    }
    return SchoolMatcher.find(_localList!, text);
  }

  static List<School>? _testList;
  List<School> _testSchools() =>
      _testList ??= _parse(AppConfig.testSchoolsJson);

  /// A plain list, or `{"data": [...]}`.
  static List<School> _parse(String body) {
    final decoded = json.decode(body);
    final list = decoded is Map ? decoded['data'] : decoded;
    if (list is! List)
      throw const FormatException('Unexpected school response');
    return list
        .map((item) => School.fromJson(item as Map<String, dynamic>))
        .toList();
  }

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
    final height = (media.size.height * 0.78).clamp(
      0.0,
      media.size.height - keyboard - 72,
    );
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
                      Text('Find your school', style: text.h4),
                      Gap.hXs,
                      Text(
                        'Enter your school code or name.',
                        style: text.muted,
                      ),
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
                            const ShadBorderSide(
                              color: Colors.transparent,
                              width: 1.5,
                            ),
                            radius: radius,
                          ),
                          focusedBorder: ShadBorder.fromBorderSide(
                            ShadBorderSide(
                              color: scheme.mutedForeground.withValues(
                                alpha: 0.45,
                              ),
                              width: 1.5,
                            ),
                            radius: radius,
                          ),
                          disableSecondaryBorder: true,
                          shadows: const [],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.of(
                      context,
                      const Duration(milliseconds: 220),
                    ),
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
        onRetry: _lookup,
      );
    }
    // The spinner shows only while there is nothing to show yet, so results don't flicker as the
    // person keeps typing.
    if (_loading && _matches.schools.isEmpty) {
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
            ShadButton.outline(
              onPressed: _search.clear,
              decoration: appPillDecoration(),
              child: const Text('Clear'),
            ),
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
              child: Text(heading, style: text.strong),
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
        width: 44,
        height: 44,
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
          : Icon(
              LucideIcons.chevronRight,
              size: IconSize.inline,
              color: scheme.mutedForeground,
            ),
      onTap: unavailable ? null : () => _pick(school),
    );
  }

  // A school without a logo of its own shows the Essentiel logo.
  Widget _fallbackLogo() =>
      const Padding(padding: EdgeInsets.all(Gap.xs), child: EssentielEmblem());
}
