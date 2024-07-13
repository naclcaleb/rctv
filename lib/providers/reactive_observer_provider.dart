import 'package:flutter/widgets.dart';

import '../core/reactive.dart';

class ReactiveObserverProvider extends InheritedWidget {

  final ReactiveObserver observer;

  const ReactiveObserverProvider({
    super.key,
    required this.observer,
    required super.child
  });

  static ReactiveObserverProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ReactiveObserverProvider>();
  }

  static ReactiveObserver? of(BuildContext context) {
    final provider = maybeOf(context);
    return provider?.observer;
  }

  @override
  bool updateShouldNotify(ReactiveObserverProvider oldWidget) => oldWidget.observer != observer;

}