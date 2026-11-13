import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/models/event.dart';
import 'package:pushtrial/models/enrolled_student.dart';
import 'package:pushtrial/shared/utils/school_utils.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';

class SchoolCalendar extends StatefulWidget {
  const SchoolCalendar({super.key});

  @override
  State<SchoolCalendar> createState() => _SchoolCalendarState();
}

class _SchoolCalendarState extends State<SchoolCalendar> {
  // Slow responses can finish after the screen was closed; skip the update then.
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  var id = '0';
  var syid = 0;
  String selectedYear = '';
  List<String> years = [];
  List<Event> events = [];

  late List<Appointment> _appointments = [];
  bool loading = true;

  /// The logged-in school's colour; null until loaded, then the theme colour is used.
  Color? schoolColor = SchoolUtils.lastColor;
  List<EnrolledStud> enrolledstud = [];

  @override
  void initState() {
    getUser();
    super.initState();
  }

  // Colours are applied in appointmentBuilder / _getSpecialRegions from the theme, so the
  // calendar follows light and dark mode.
  List<Appointment> _getAppointments() {
    return events.map((event) {
      return Appointment(
        startTime: event.startTime,
        endTime: event.endTime,
        subject: event.title,
      );
    }).toList();
  }

  List<TimeRegion> _getSpecialRegions(ShadColorScheme colors, Color accent) {
    List<TimeRegion> specialRegions = [];

    for (Appointment appointment in _appointments) {
      specialRegions.add(
        TimeRegion(
          startTime: appointment.startTime,
          endTime: appointment.endTime,
          enablePointerInteraction: false,
          textStyle: TextStyle(color: colors.foreground),
          color: accent.withValues(alpha: 0.10),
        ),
      );
    }

    return specialRegions;
  }

  Future<void> getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('studid');

    final color = await SchoolUtils.schoolColor();
    if (color != null) setState(() => schoolColor = color);

    if (json != null) {
      setState(() {
        id = json;
        loading = true;
      });
      await getEnrolledStud();
      await getEvents();
    }
    setState(() {
      loading = false;
    });
  }

  getEnrolledStud() async {
    await CallApi().getEnrolledStud(id).then((response) {
      setState(() {
        var decodedJson = json.decode(response.body);

        if (decodedJson is Map<String, dynamic>) {
          Iterable list = decodedJson['enrolledstud_info'];
          enrolledstud = list
              .map((model) => EnrolledStud.fromJson(model))
              .toList();

          for (var element in enrolledstud) {
            years.add(element.sydesc);
          }
          Set<String> uniqueSet = years.toSet();
          years = uniqueSet.toList();
          selectedYear = enrolledstud[enrolledstud.length - 1].sydesc;
          for (var yr in enrolledstud) {
            if (yr.sydesc == selectedYear) {
              syid = yr.syid;
              getEvents();
            }
          }
        }
      });
    });
  }

  getEvents() async {
    await CallApi().getEvents(syid).then((response) {
      setState(() {
        Iterable ll = jsonDecode(response.body);
        events = (ll as List<dynamic>).map((e) {
          return Event(
            id: e['id'] ?? 0,
            title: e['title'] ?? '',
            venue: e['venue'] ?? '',
            startTime:
                (e['startTime'] != null &&
                    e['startTime'].isNotEmpty &&
                    e['startTime'] != '0')
                ? DateTime.parse(e['startTime'])
                : DateTime(0),
            endTime:
                (e['endTime'] != null &&
                    e['endTime'].isNotEmpty &&
                    e['endTime'] != '0')
                ? DateTime.parse(e['endTime'])
                : DateTime(0),
            time: e['time'] ?? '',
          );
        }).toList();
        _appointments = _getAppointments();
      });
    });
  }

  Widget _calendar(ShadThemeData theme, SchoolTone tone) {
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final accent = schoolColor ?? colors.primary;
    return RoundedCard(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.md, Gap.sm, Gap.sm),
      child: SizedBox(
        height: 400,
        child: SfCalendar(
          view: CalendarView.month,
          initialSelectedDate: DateTime.now(),
          dataSource: _AppointmentDataSource(_appointments),
          appointmentBuilder: appointmentBuilder,
          onTap: onTapCalendarCell,
          specialRegions: _getSpecialRegions(colors, accent),
          backgroundColor: Colors.transparent,
          cellBorderColor: Colors.transparent,
          todayHighlightColor: accent,
          todayTextStyle: text.small.copyWith(
            color: tone.onSolid,
            fontWeight: FontWeight.w700,
          ),
          headerStyle: CalendarHeaderStyle(
            textStyle: text.large,
            backgroundColor: Colors.transparent,
          ),
          viewHeaderStyle: ViewHeaderStyle(
            backgroundColor: Colors.transparent,
            dayTextStyle: text.small.copyWith(color: colors.mutedForeground),
          ),
          selectionDecoration: BoxDecoration(
            border: Border.all(color: accent, width: 1.5),
            borderRadius: BorderRadius.circular(Gap.md),
          ),
          monthViewSettings: MonthViewSettings(
            monthCellStyle: MonthCellStyle(
              textStyle: text.small.copyWith(color: colors.foreground),
              trailingDatesTextStyle: text.small.copyWith(
                color: colors.mutedForeground,
              ),
              leadingDatesTextStyle: text.small.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Filled hero like the other tabs: the next event, or a calm "nothing scheduled" line.
  Widget _heroCard(SchoolTone tone, List<Event> all) {
    final text = ShadTheme.of(context).textTheme;
    final onSolid = tone.onSolid;
    final now = DateTime.now();
    final upcoming = all
        .where((e) => e.startTime.year > 1 && !e.endTime.isBefore(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final next = upcoming.isEmpty ? null : upcoming.first;
    final count = all.length;
    return SolidCard(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendarDays, color: onSolid, size: IconSize.row),
              Gap.wSm,
              Expanded(
                child: Text(
                  next == null ? 'School calendar' : 'Next event',
                  style: text.small.copyWith(
                    color: onSolid.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selectedYear.isNotEmpty)
                SchoolPill('SY $selectedYear', tone, onCard: true),
            ],
          ),
          Gap.hLg,
          Text(
            next?.title ?? 'Nothing scheduled',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.h2.copyWith(color: onSolid),
          ),
          Gap.hXs,
          Text(
            next == null
                ? 'No upcoming events this school year.'
                : [
                    Fmt.date(next.startTime),
                    if (next.time.isNotEmpty) next.time,
                  ].join(' · '),
            style: text.p.copyWith(color: onSolid.withValues(alpha: 0.85)),
          ),
          Gap.hMd,
          Text(
            count == 1 ? '1 event this school year' : '$count events this school year',
            style: text.small.copyWith(
              color: onSolid.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Event event, SchoolTone tone) {
    final text = ShadTheme.of(context).textTheme;
    final scheme = ShadTheme.of(context).colorScheme;
    final start = event.startTime;
    final hasDate = start.year > 1;
    Widget detail(IconData icon, String value) => Row(
      children: [
        Icon(icon, size: IconSize.inline, color: scheme.mutedForeground),
        Gap.wXs,
        Expanded(child: Text(value, style: text.muted)),
      ],
    );
    return RoundedCard(
      padding: const EdgeInsets.all(Gap.lg),
      radius: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filled date block: the colour sits on the background, the text on it is white.
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            decoration: BoxDecoration(
              color: tone.solid,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  hasDate ? '${start.day}' : '-',
                  style: text.h3.copyWith(color: tone.onSolid, height: 1.1),
                ),
                Text(
                  hasDate ? DateFormat('MMM').format(start).toUpperCase() : '',
                  style: text.small.copyWith(
                    color: tone.onSolid.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Gap.wMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: text.large),
                Gap.hXs,
                if (event.venue.isNotEmpty)
                  detail(LucideIcons.mapPin, event.venue),
                if (event.time.isNotEmpty)
                  detail(LucideIcons.clock, event.time),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tone = SchoolTone(context, schoolColor ?? theme.colorScheme.primary);

    if (loading) {
      return const AppPage.root(
        title: 'School calendar',
        body: LoadingSkeleton(),
      );
    }

    final sortedEvents = List<Event>.from(events)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return AppPage.root(
      title: 'School calendar',
      backgroundColor: tone.background,
      children: [
        _heroCard(tone, events),
        Gap.hSm,
        ShadSelect<String>(
          initialValue: selectedYear.isNotEmpty ? selectedYear : null,
          placeholder: const Text('Choose a school year'),
          options: [
            for (final year in years)
              ShadOption(value: year, child: Text(year)),
          ],
          selectedOptionBuilder: (context, value) => Text(value),
          onChanged: (String? newValue) {
            if (newValue == null) return;
            setState(() {
              selectedYear = newValue;
              for (var yr in enrolledstud) {
                if (yr.sydesc == selectedYear) {
                  syid = yr.syid;
                  getEvents();
                }
              }
            });
          },
        ),
        Gap.hLg,
        _calendar(theme, tone),
        Padding(
          padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.md),
          child: Row(
            children: [
              AccentBar(tone),
              Gap.wSm,
              Text('Events', style: theme.textTheme.large),
            ],
          ),
        ),
        if (sortedEvents.isEmpty)
          const SizedBox(
            height: 200,
            child: EmptyState(
              icon: LucideIcons.calendarDays,
              title: 'No events',
              message: 'There are no events for this school year.',
            ),
          )
        else
          for (final event in sortedEvents) _eventCard(event, tone),
      ],
    );
  }

  void onTapCalendarCell(CalendarTapDetails details) {
    if (details.appointments != null && details.appointments!.isNotEmpty) {
      List<Event> events2 = details.appointments!.map((appointment) {
        return events.firstWhere(
          (event) =>
              event.title == appointment.subject &&
              event.startTime == appointment.startTime &&
              event.endTime == appointment.endTime,
        );
      }).toList();

      showShadDialog(
        context: context,
        builder: (BuildContext context) {
          final text = ShadTheme.of(context).textTheme;
          return ShadDialog(
            title: const Text('Event details'),
            actions: [
              ShadButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final event in events2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: text.p.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (event.venue.isNotEmpty)
                            Text(event.venue, style: text.muted),
                          if (event.time.isNotEmpty)
                            Text(event.time, style: text.muted),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget appointmentBuilder(
    BuildContext context,
    CalendarAppointmentDetails details,
  ) {
    final theme = ShadTheme.of(context);
    final label = details.appointments.length == 1
        ? details.appointments.first.subject
        : '+${details.appointments.length}';
    if (details.appointments.isEmpty) return const SizedBox.shrink();
    final tone = SchoolTone(context, schoolColor ?? theme.colorScheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      decoration: BoxDecoration(
        color: tone.solid,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.small.copyWith(
            color: tone.onSolid,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AppointmentDataSource extends CalendarDataSource {
  _AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}
