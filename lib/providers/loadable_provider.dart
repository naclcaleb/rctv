import 'package:flutter/widgets.dart';
import 'reactive_provider.dart';

import '../core/loadable.dart';

class LoadableProvider<DataType> extends StatelessWidget {
  final Loadable<DataType> loadable;
  final Widget Function()? notStarted;
  final Widget Function() loading;
  final Widget Function(String error) error;
  final Widget Function(DataType? data) data;

  const LoadableProvider(this.loadable, { this.notStarted, required this.loading, required this.error, required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    return ReactiveProvider(loadable.reactive, builder: (context, lastUpdate, _) {
      if (lastUpdate == null) throw Exception('Loadable sent null LoadableUpdate');

      final state = lastUpdate.state;

      switch (state) {
        case LoadableState.notStarted:
          if (notStarted != null) return notStarted!();
          return loading();
        case LoadableState.loading:
          return loading();
        case LoadableState.error:
          return error(lastUpdate.error ?? 'Unknown error');
        case LoadableState.data:
          return data(lastUpdate.data);
        case LoadableState.done:
          return data(lastUpdate.data);
      }
    });
  }
}