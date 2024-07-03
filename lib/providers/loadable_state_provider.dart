import 'package:flutter/widgets.dart';
import 'reactive_provider.dart';

import '../core/loadable.dart';

class LoadableStateProvider<DataType> extends StatelessWidget {

  final Loadable<DataType> loadable;
  final Widget Function(LoadableState state, String? error) builder;

  const LoadableStateProvider(this.loadable, {required this.builder, super.key});

  @override
  Widget build(BuildContext context) {
    return ReactiveProvider(loadable.reactive, builder: (context, lastUpdate, _) {
      if (lastUpdate == null) throw Exception('Loadable sent null LoadableUpdate');

      return builder(lastUpdate.state, lastUpdate.error);
    });
  }
}