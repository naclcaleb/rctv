import 'package:flutter/widgets.dart';
import 'package:rctv/rctv.dart';

class CompoundLoadableProvider extends StatefulWidget {

  final List<Loadable> loadables;
  final Widget Function()? notStarted;
  final Widget Function() loading;
  final Widget Function(String error) error;
  final Widget Function() data;

  const CompoundLoadableProvider(this.loadables, { this.notStarted, required this.loading, required this.error, required this.data, super.key});
  
  @override
  State<CompoundLoadableProvider> createState() => _CompoundLoadableProviderState();
}

class _CompoundLoadableProviderState extends State<CompoundLoadableProvider> {
  final List<ReactiveSubscription> _subscriptions = [];

  LoadableState _currentState = LoadableState.notStarted;
  String? _mostRecentError;

  int _stateRank(LoadableState state) {
    return switch(state) {
      LoadableState.data => 0,
      LoadableState.notStarted => 1,
      LoadableState.loading => 2, 
      LoadableState.error => 3,
      LoadableState.done => 0
    };
  }

  LoadableState _getUpdatedState() {
    LoadableState currentState = LoadableState.data;

    //Priorities: error > loading > notStarted > data
    for (final loadable in widget.loadables) {
      final state = loadable.reactive.read().state;
      if (_stateRank(state) > _stateRank(currentState)) {
        currentState = state;
      }
    }

    return currentState;
  }

  void _updateIfNeeded() {
    final oldState = _currentState;
    _currentState = _getUpdatedState();
    
    if (oldState != _currentState) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    for (final loadable in widget.loadables) {
      _subscriptions.add( loadable.watch((newVal, prevVal) {
        if (newVal.state == LoadableState.error) _mostRecentError = newVal.error;
        _updateIfNeeded();
      }) );
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentState) {
        case LoadableState.notStarted:
          if (widget.notStarted != null) return widget.notStarted!();
          return widget.loading();
        case LoadableState.loading:
          return widget.loading();
        case LoadableState.error:
          return widget.error(_mostRecentError ?? 'Unknown error');
        case LoadableState.data:
          return widget.data();
        case LoadableState.done:
          return widget.data();
      }
  }
}