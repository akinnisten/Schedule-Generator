import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreen();
}

class _CalendarScreen extends State<CalendarScreen> {
  bool _isMonthView = true;
  late EventController _controller;
  final CollectionReference _eventsCollection = FirebaseFirestore.instance
      .collection('events');
  final CollectionReference _interestsCollection = FirebaseFirestore.instance
      .collection('interests');
  final List<String> _allInterests = ['Sports', 'Music', 'Technology'];
  List<String> _selectedInterests = [];

  final Map<String, Duration> insertDurations = {
    'Sports': Duration(hours: 1),
    'Music': Duration(hours: 2),
    'Technology': Duration(hours: 3),
  };

  @override
  void initState() {
    super.initState();
    _controller = EventController();

    _loadInterestsFromFirebase();
    _loadEventsFromFirebase();
  }

  Future<void> _loadInterestsFromFirebase() async {
    final doc = await _interestsCollection.doc('test').get();
    if (doc.exists) {
      _selectedInterests = List<String>.from(doc['interests'] ?? []);
      setState(() {});
    }
  }

  Future<void> _saveInterestsToFirebase() async {
    await _interestsCollection.doc('test').set({
      'interests': _selectedInterests,
    });
  }

  Future<void> _loadEventsFromFirebase() async {
    final snapshot = await _eventsCollection.get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final event = CalendarEventData(
        title: data['title'],
        description: data['description'] ?? '',
        date: DateTime.parse(data['date']),
        startTime: DateTime.parse(data['startTime']),
        endTime: DateTime.parse(data['endTime']),
      );
      _controller.add(event);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Calendar"),
        actions: [
          IconButton(
            icon: Icon(_isMonthView ? Icons.view_day : Icons.calendar_month),
            tooltip: _isMonthView
                ? "Switch to Day View"
                : "Switch to Month View",
            onPressed: () => setState(() => _isMonthView = !_isMonthView),
          ),
          IconButton(
            icon: const Icon(Icons.star_outline),
            tooltip: "Select Interests",
            onPressed: _showInterestsDialog,
          ),
        ],
      ),
      body: _isMonthView ? _buildMonthView() : _buildDayView(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddEventDialog(DateTime.now()),
      ),
    );
  }

  Widget _buildMonthView() {
    return MonthView(
      controller: _controller,
      onCellTap: (events, date) {
        if (events.isEmpty) {
          _showAddEventDialog(date);
        } else {
          _showEventListDialog(
            events,
          ); // ✅ Added: shows dialog to manage events
        }
      },
    );
  }

  Widget _buildDayView() {
    return DayView(
      controller: _controller,
      onDateLongPress: (date) => _showAddEventDialog(date),
      eventTileBuilder: (date, events, boundary, start, end) {
        // Custom event tile design
        return GestureDetector(
          onTap: () => _showEditOrDeleteDialog(events.first),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: events.first.color ?? Colors.blue.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${events.first.title}\n"
              "${_formatTime(events.first.startTime)} - ${_formatTime(events.first.endTime)}\n"
              "${events.first.description ?? ""}", // ✅ add description here
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  void _showEventListDialog(List<CalendarEventData> events) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Events"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return ListTile(
                title: Text(event.title),
                subtitle: Text(
                  "${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}\n${event.description ?? ""}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _controller.remove(event);
                    _deleteEventFromFirebase(event);
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
                onTap: () => _showEditOrDeleteDialog(event),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEventFromFirebase(CalendarEventData event) async {
    final snapshot = await _eventsCollection
        .where('title', isEqualTo: event.title)
        .where('startTime', isEqualTo: event.startTime!.toIso8601String())
        .get();

    for (var doc in snapshot.docs) {
      await _eventsCollection.doc(doc.id).delete();
    }
  }

  void _showAddEventDialog(DateTime date) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("New Event"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: "Event title"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  hintText: "Event description",
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) setState(() => startTime = picked);
                      },
                      child: Text(
                        startTime == null
                            ? "Start Time"
                            : "Start: ${startTime!.format(context)}",
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) setState(() => endTime = picked);
                      },
                      child: Text(
                        endTime == null
                            ? "End Time"
                            : "End: ${endTime!.format(context)}",
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    startTime == null ||
                    endTime == null)
                  return;

                final startDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  startTime!.hour,
                  startTime!.minute,
                );
                final endDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  endTime!.hour,
                  endTime!.minute,
                );

                final event = CalendarEventData(
                  title: titleController.text,
                  description: descController.text,
                  date: date,
                  startTime: startDateTime,
                  endTime: endDateTime,
                );

                _controller.add(event);
                _eventsCollection.add({
                  'title': titleController.text,
                  'description': descController.text,
                  'date': date.toIso8601String(),
                  'startTime': startDateTime.toIso8601String(),
                  'endTime': endDateTime.toIso8601String(),
                });
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditOrDeleteDialog(CalendarEventData event) {
    final titleController = TextEditingController(text: event.title);
    final descController = TextEditingController(text: event.description ?? "");
    final start = event.startTime ?? event.date;
    final end = event.endTime ?? event.date.add(const Duration(hours: 1));

    TimeOfDay startTime = TimeOfDay(hour: start.hour, minute: start.minute);
    TimeOfDay endTime = TimeOfDay(hour: end.hour, minute: end.minute);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit Event"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (picked != null) setState(() => startTime = picked);
                      },
                      child: Text("Start: ${startTime.format(context)}"),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (picked != null) setState(() => endTime = picked);
                      },
                      child: Text("End: ${endTime.format(context)}"),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _controller.remove(event);
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                _controller.remove(event);
                _controller.add(
                  event.copyWith(
                    title: titleController.text,
                    description: descController.text,
                    startTime: DateTime(
                      event.date.year,
                      event.date.month,
                      event.date.day,
                      startTime.hour,
                      startTime.minute,
                    ),
                    endTime: DateTime(
                      event.date.year,
                      event.date.month,
                      event.date.day,
                      endTime.hour,
                      endTime.minute,
                    ),
                  ),
                );
                _updateEventInFirebase(
                  event,
                  titleController.text,
                  descController.text,
                  startTime,
                  endTime,
                );
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateEventInFirebase(
    CalendarEventData event,
    String newDescription,
    String newTitle,
    TimeOfDay startTime,
    TimeOfDay endTime,
  ) async {
    final snapshot = await _eventsCollection
        .where('title', isEqualTo: event.title)
        .where('startTime', isEqualTo: event.startTime!.toIso8601String())
        .get();

    for (var doc in snapshot.docs) {
      await _eventsCollection.doc(doc.id).update({
        'title': newTitle,
        'description': newDescription,
        'startTime': DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
          startTime.hour,
          startTime.minute,
        ).toIso8601String(),
        'endTime': DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
          endTime.hour,
          endTime.minute,
        ).toIso8601String(),
      });
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return "";
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final m = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? "PM" : "AM";
    return "$h:$m $suffix";
  }

  void _showInterestsDialog() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Select Your Interests"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _allInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                  ), // adds spacing between checkboxes
                  child: CheckboxListTile(
                    title: Text(interest),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedInterests.add(interest);
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _askCustomTimeAndGenerate();
              },
              child: const Text("Generate"),
            ),
            TextButton(
              onPressed: () {
                _saveInterestsToFirebase();
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  void _generateSchedule({int startHour = 6, int endHour = 22}) async {
    final now = DateTime.now();

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = now.add(Duration(days: dayOffset));

      // Get all events for that day
      final dayEvents = _controller.events
          .where(
            (e) =>
                e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day,
          )
          .toList();

      // Sort events by startTime
      dayEvents.sort((a, b) => a.startTime!.compareTo(b.startTime!));

      for (var interest in _selectedInterests) {
        final duration = insertDurations[interest] ?? Duration(hours: 1);

        DateTime slotStart = DateTime(day.year, day.month, day.day, startHour);
        bool scheduled = false;

        for (var event in dayEvents) {
          if (slotStart.add(duration).isBefore(event.startTime!)) {
            // Found a slot before the next event
            final newEvent = CalendarEventData(
              title: "Generated Activity",
              description: interest,
              date: day,
              startTime: slotStart,
              endTime: slotStart.add(duration),
              color: Colors.grey,
            );

            _controller.add(newEvent);
            await _eventsCollection.add({
              'title': newEvent.title,
              'description': newEvent.description,
              'date': newEvent.date.toIso8601String(),
              'startTime': newEvent.startTime!.toIso8601String(),
              'endTime': newEvent.endTime!.toIso8601String(),
            });

            dayEvents.add(newEvent);
            dayEvents.sort((a, b) => a.startTime!.compareTo(b.startTime!));

            scheduled = true;
            break;
          } else {
            // Move slotStart to after this event
            slotStart = event.endTime!;
          }
        }

        // If no events block this interest, schedule at the end of the day
        if (!scheduled &&
            slotStart
                .add(duration)
                .isBefore(DateTime(day.year, day.month, day.day, endHour, 0))) {
          final newEvent = CalendarEventData(
            title: "Generated Activity",
            description: interest,
            date: day,
            startTime: slotStart,
            endTime: slotStart.add(duration),
            color: Colors.grey,
          );

          dayEvents.add(newEvent);
          dayEvents.sort((a, b) => a.startTime!.compareTo(b.startTime!));

          _controller.add(newEvent);
          await _eventsCollection.add({
            'title': newEvent.title,
            'description': newEvent.description,
            'date': newEvent.date.toIso8601String(),
            'startTime': newEvent.startTime!.toIso8601String(),
            'endTime': newEvent.endTime!.toIso8601String(),
          });
        }
      }
    }

    setState(() {}); // Refresh the calendar view
  }

  void _askCustomTimeAndGenerate() async {
    int startHour = 6;
    int endHour = 22;

    // Ask user if they want custom times
    final custom = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Custom Time Interval"),
        content: const Text("Would you like to create your own times?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (custom == true) {
      TimeOfDay? customStart;
      TimeOfDay? customEnd;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text("Select Your Interval"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: startHour, minute: 0),
                    );
                    if (picked != null) setState(() => customStart = picked);
                  },
                  child: Text(
                    customStart == null
                        ? "Select Start Time"
                        : "Start: ${customStart!.format(context)}",
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: endHour, minute: 0),
                    );
                    if (picked != null) setState(() => customEnd = picked);
                  },
                  child: Text(
                    customEnd == null
                        ? "Select End Time"
                        : "End: ${customEnd!.format(context)}",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        ),
      );

      if (customStart != null) startHour = customStart!.hour;
      if (customEnd != null) endHour = customEnd!.hour;
    }

    // Call your existing schedule generator with the selected interval
    _generateSchedule(startHour: startHour, endHour: endHour);
  }
}
