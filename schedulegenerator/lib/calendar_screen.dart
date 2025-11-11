import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreen();
}

class _CalendarScreen extends State<CalendarScreen> {
  bool _isMonthView = true;
  late EventController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EventController();

    // Example event
    _controller.add(
      CalendarEventData(
        title: "Team Meeting",
        description: "Discuss project updates",
        date: DateTime.now(),
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
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
              color: Colors.blue.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${events.first.title}\n"
              "${_formatTime(events.first.startTime)} - ${_formatTime(events.first.endTime)}",
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
                  "${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _controller.remove(event);
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

  void _showAddEventDialog(DateTime date) {
    final titleController = TextEditingController();
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
                  date: date,
                  startTime: startDateTime,
                  endTime: endDateTime,
                );

                _controller.add(event);
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

  String _formatTime(DateTime? time) {
    if (time == null) return "";
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final m = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? "PM" : "AM";
    return "$h:$m $suffix";
  }
}
