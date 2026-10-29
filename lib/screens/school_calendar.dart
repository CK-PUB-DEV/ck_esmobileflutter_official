import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/event.dart';
import 'package:pushtrial/models/enrolled_stud.dart';
import 'package:pushtrial/widgets/ui/ui.dart';

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

  List<TimeRegion> _getSpecialRegions(ShadColorScheme colors) {
    List<TimeRegion> specialRegions = [];

    for (Appointment appointment in _appointments) {
      specialRegions.add(
        TimeRegion(
          startTime: appointment.startTime,
          endTime: appointment.endTime,
          enablePointerInteraction: false,
          textStyle: TextStyle(color: colors.foreground),
          color: colors.primary.withValues(alpha: 0.10),
        ),
      );
    }

    return specialRegions;
  }

  Future<void> getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('studid');

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

  Widget _calendar(ShadThemeData theme) {
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    return SizedBox(
      height: 400,
      child: ClipRRect(
        borderRadius: theme.radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border),
            borderRadius: theme.radius,
          ),
          child: SfCalendar(
            view: CalendarView.month,
            initialSelectedDate: DateTime.now(),
            dataSource: _AppointmentDataSource(_appointments),
            appointmentBuilder: appointmentBuilder,
            onTap: onTapCalendarCell,
            specialRegions: _getSpecialRegions(colors),
            backgroundColor: colors.card,
            cellBorderColor: colors.border,
            todayHighlightColor: colors.primary,
            headerStyle: CalendarHeaderStyle(
              textStyle: text.large,
              backgroundColor: colors.card,
            ),
            viewHeaderStyle: ViewHeaderStyle(
              backgroundColor: colors.card,
              dayTextStyle: text.small.copyWith(color: colors.mutedForeground),
            ),
            selectionDecoration: BoxDecoration(
              border: Border.all(color: colors.primary, width: 1.5),
              borderRadius: BorderRadius.circular(Gap.xs),
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
      ),
    );
  }

  Widget _eventCard(Event event) {
    final text = ShadTheme.of(context).textTheme;
    return AppCard(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title, style: text.large),
          Gap.hSm,
          if (event.venue.isNotEmpty)
            InfoRow('Venue', event.venue, icon: LucideIcons.mapPin),
          InfoRow('Date', Fmt.date(event.startTime), icon: LucideIcons.calendar),
          if (event.time.isNotEmpty)
            InfoRow('Time', event.time, icon: LucideIcons.clock),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (loading) {
      return const AppPage(title: 'School calendar', body: LoadingSkeleton());
    }

    final sortedEvents = List<Event>.from(events)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return AppPage(
      title: 'School calendar',
      children: [
        ShadSelect<String>(
          initialValue: selectedYear.isNotEmpty ? selectedYear : null,
          placeholder: const Text('Choose a school year'),
          options: [
            for (final year in years) ShadOption(value: year, child: Text(year)),
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
        _calendar(theme),
        SectionHeader('Events'),
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
          for (final event in sortedEvents) _eventCard(event),
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(Gap.sm),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.primaryForeground,
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
