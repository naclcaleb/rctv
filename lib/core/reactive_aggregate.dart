import 'reactive.dart';

abstract class ReactiveAggregate {

  void disposeReactives(List<Reactive> reactives) {
    for (final reactive in reactives) {
      reactive.dispose();
    }
  }

  void dispose() {
    disposeReactives([]);
  }

}