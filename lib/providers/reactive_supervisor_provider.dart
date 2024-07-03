import 'package:flutter/widgets.dart';
import 'package:rctv/core/reactive_supervisor.dart';

class ReactiveSupervisorProvider extends InheritedWidget {

  final ReactiveSupervisor supervisor;

  const ReactiveSupervisorProvider({
    super.key,
    required this.supervisor,
    required super.child
  });

  static ReactiveSupervisorProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ReactiveSupervisorProvider>();
  }

  static ReactiveSupervisor? of(BuildContext context) {
    final provider = maybeOf(context);
    return provider?.supervisor;
  }

  @override
  bool updateShouldNotify(ReactiveSupervisorProvider oldWidget) => oldWidget.supervisor != supervisor;

}