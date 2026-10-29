import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/taphistory.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/widgets/ui/ui.dart';

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

  @override
  void initState() {
    super.initState();
    getUser();
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

  Widget _tapRow(TapHistory history) {
    final theme = ShadTheme.of(context);
    final isIn = history.tapstate == 'IN';
    return AppCard(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Icon(
            isIn ? LucideIcons.logIn : LucideIcons.logOut,
            size: IconSize.row,
            color: theme.colorScheme.mutedForeground,
          ),
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

  List<Widget> _grouped() {
    final items = <Widget>[];
    String? currentDate;
    for (final history in filteredTapHistory) {
      if (history.tdate != currentDate) {
        currentDate = history.tdate;
        items.add(
          SectionHeader(
            Fmt.date(history.tdate),
            topGap: items.isNotEmpty,
          ),
        );
      }
      items.add(_tapRow(history));
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

    if (loading) {
      return const AppPage(title: 'Tap history', body: LoadingSkeleton());
    }

    if (tapHistory.isEmpty) {
      return AppPage(
        title: 'Tap history',
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

    return AppPage(
      title: 'Tap history',
      onRefresh: getTapHistory,
      children: [
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
          ..._grouped(),
      ],
    );
  }
}
