import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/taphistory.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/shared/utils/school_utils.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';

class TapHistoryScreen extends StatefulWidget {
  const TapHistoryScreen({super.key});

  @override
  _TapHistoryScreenState createState() => _TapHistoryScreenState();
}

class _TapHistoryScreenState extends State<TapHistoryScreen> {
  // Slow responses can finish after the screen was closed; skip the update then.
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  static const _months = [
    'ALL',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _states = ['ALL', 'IN', 'OUT'];

  int studid = 0;
  User user = UserData.myUser;
  List<TapHistory> tapHistory = [];
  List<TapHistory> filteredTapHistory = [];
  String selectedMonth = 'ALL';
  String selectedWeek = 'ALL';
  String selectedState = 'ALL';
  bool loading = true;

  /// The logged-in school's colour; the theme colour is used until it is known.
  Color? schoolColor = SchoolUtils.lastColor;

  @override
  void initState() {
    super.initState();
    getUser();
    if (schoolColor == null) {
      SchoolUtils.schoolColor().then(
        (color) => setState(() => schoolColor = color),
      );
    }
  }

  Future<void> getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('user');
    user = json == null ? UserData.myUser : User.fromJson(jsonDecode(json));
    studid = user.id;
    getTapHistory();
  }

  Future<void> getTapHistory() async {
    try {
      final response = await CallApi().getTapHistory(studid);
      final parsedResponse = json.decode(response.body);
      if (parsedResponse is List) {
        setState(() {
          tapHistory = parsedResponse
              .map((model) => TapHistory.fromJson(model))
              .toList()
              .cast<TapHistory>();
          filterTapHistory();
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void filterTapHistory() {
    setState(() {
      filteredTapHistory = tapHistory.where((history) {
        bool matchesMonth =
            selectedMonth == 'ALL' ||
            DateFormat(
                  'MMMM',
                ).format(DateFormat('yyyy-MM-dd').parse(history.tdate)) ==
                selectedMonth;

        bool matchesState =
            selectedState == 'ALL' || history.tapstate == selectedState;

        bool matchesWeek = true;
        if (selectedWeek != 'ALL') {
          final date = DateFormat('yyyy-MM-dd').parse(history.tdate);
          int weekOfMonth = ((date.day - 1) / 7).floor() + 1;
          matchesWeek = selectedWeek == 'Week $weekOfMonth';
        }

        return matchesMonth && matchesState && matchesWeek;
      }).toList();
    });
  }

  Widget _filters() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ShadSelect<String>(
            initialValue: selectedMonth,
            placeholder: const Text('Month'),
            options: [
              for (final month in _months)
                ShadOption(
                  value: month,
                  child: Text(month == 'ALL' ? 'All months' : month),
                ),
            ],
            selectedOptionBuilder: (context, value) =>
                Text(value == 'ALL' ? 'All months' : value),
            onChanged: (value) {
              if (value == null) return;
              selectedMonth = value;
              filterTapHistory();
            },
          ),
        ),
        Gap.wSm,
        Expanded(
          flex: 2,
          child: ShadSelect<String>(
            initialValue: selectedState,
            placeholder: const Text('Status'),
            options: [
              for (final state in _states)
                ShadOption(
                  value: state,
                  child: Text(state == 'ALL' ? 'All taps' : state),
                ),
            ],
            selectedOptionBuilder: (context, value) =>
                Text(value == 'ALL' ? 'All taps' : value),
            onChanged: (value) {
              if (value == null) return;
              selectedState = value;
              filterTapHistory();
            },
          ),
        ),
      ],
    );
  }

  /// Filled hero with the most recent tap, so the page opens on the one fact people look for.
  Widget _lastTapCard(SchoolTone tone) {
    final text = ShadTheme.of(context).textTheme;
    final onSolid = tone.onSolid;
    final last = tapHistory.reduce((a, b) {
      final c = a.tdate.compareTo(b.tdate);
      if (c != 0) return c > 0 ? a : b;
      final t = a.ttime.compareTo(b.ttime);
      return (t != 0 ? t > 0 : a.id > b.id) ? a : b;
    });
    final isIn = last.tapstate == 'IN';
    return SolidCard(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.badgeCheck, color: onSolid, size: IconSize.row),
              Gap.wSm,
              Expanded(
                child: Text(
                  'Last tap',
                  style: text.small.copyWith(
                    color: onSolid.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SchoolPill(isIn ? 'In' : 'Out', tone, onCard: true),
            ],
          ),
          Gap.hLg,
          Text(Fmt.time(last.ttime), style: text.h1.copyWith(color: onSolid)),
          Gap.hXs,
          Text(
            Fmt.date(last.tdate),
            style: text.p.copyWith(color: onSolid.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _tapRow(TapHistory history, SchoolTone tone) {
    final theme = ShadTheme.of(context);
    final isIn = history.tapstate == 'IN';
    return RoundedCard(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
      radius: 24,
      child: Row(
        children: [
          SchoolIcon(isIn ? LucideIcons.logIn : LucideIcons.logOut),
          Gap.wMd,
          Expanded(
            child: Text(
              Fmt.time(history.ttime),
              style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          StatusBadge(
            isIn ? 'In' : 'Out',
            status: isIn ? AppStatus.success : AppStatus.info,
          ),
        ],
      ),
    );
  }

  List<Widget> _grouped(SchoolTone tone) {
    final items = <Widget>[];
    String? currentDate;
    for (final history in filteredTapHistory) {
      if (history.tdate != currentDate) {
        currentDate = history.tdate;
        items.add(
          Padding(
            padding: EdgeInsets.only(
              top: items.isNotEmpty ? Gap.xl : 0,
              bottom: Gap.md,
            ),
            child: Row(
              children: [
                AccentBar(tone),
                Gap.wSm,
                Expanded(
                  child: Text(
                    Fmt.date(history.tdate),
                    style: ShadTheme.of(context).textTheme.large,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      items.add(_tapRow(history, tone));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    filteredTapHistory.sort((a, b) {
      final dateCompare = b.tdate.compareTo(a.tdate);
      if (dateCompare != 0) return dateCompare;
      final timeCompare = b.ttime.compareTo(a.ttime);
      if (timeCompare != 0) return timeCompare;
      return b.id.compareTo(a.id);
    });

    final tone = SchoolTone(
      context,
      schoolColor ?? ShadTheme.of(context).colorScheme.primary,
    );

    if (loading) {
      return const AppPage.root(title: 'Tap history', body: LoadingSkeleton());
    }

    if (tapHistory.isEmpty) {
      return AppPage.root(
        title: 'Tap history',
        backgroundColor: tone.background,
        onRefresh: getTapHistory,
        children: const [
          SizedBox(
            height: 360,
            child: EmptyState(
              title: 'No tap records yet',
              message: 'Your gate taps will show up here.',
              icon: LucideIcons.badgeCheck,
            ),
          ),
        ],
      );
    }

    return AppPage.root(
      title: 'Tap history',
      backgroundColor: tone.background,
      onRefresh: getTapHistory,
      children: [
        _lastTapCard(tone),
        Gap.hSm,
        _filters(),
        Gap.hLg,
        if (filteredTapHistory.isEmpty)
          const SizedBox(
            height: 280,
            child: EmptyState(
              title: 'No taps match these filters',
              message: 'Try a different month or status.',
              icon: LucideIcons.search,
            ),
          )
        else
          ..._grouped(tone),
      ],
    );
  }
}
