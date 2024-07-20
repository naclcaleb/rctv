import 'package:flutter/widgets.dart';
import 'package:rctv/providers/reactive_observer_provider.dart';
import '../core/reactive.dart';

/*
  Very basic widget that rebuilds on any update to a Reactive
*/

class ReactiveProvider<DataType> extends StatefulWidget {

  final Reactive<DataType> reactive;
  final Widget Function(BuildContext context, DataType value, Widget? child) builder;
  final ReactiveUpdateListener<DataType>? listener;
  final Widget? child;

  const ReactiveProvider(this.reactive, {required this.builder, this.listener, this.child, super.key});

  @override
  State<ReactiveProvider<DataType>> createState() => _ReactiveProviderState<DataType>();
}

class _ReactiveProviderState<DataType> extends State<ReactiveProvider<DataType>> {
  
  late ReactiveSubscription _reactiveSubscription;

  @override
  void initState() {
    super.initState();
    
    //For observed reactives, register them if possible
    if (widget.reactive.isObserved()) {
      final observer = ReactiveObserverProvider.of(context);
      if (observer != null) {
        observer.register(widget.reactive);
      }
    }

    _reactiveSubscription = widget.reactive.watch((newValue, prevValue) {
      if (widget.listener != null) widget.listener!(newValue, prevValue);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _reactiveSubscription.dispose();

    if (widget.reactive.shouldAutoDispose) widget.reactive.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.reactive.read(), widget.child);
  }

}

typedef ReactiveWidgetBuilder = Widget Function(BuildContext context, Watcher watch, OtherType Function<OtherType>(Reactive<OtherType> reactive) read);

class ReactiveWidget extends StatefulWidget {
  final ReactiveWidgetBuilder? _builder;

  const ReactiveWidget({ ReactiveWidgetBuilder? builder, super.key }) : _builder = builder;

  @override
  State<ReactiveWidget> createState() => _ReactiveWidgetState();

  Widget build(BuildContext context, Watcher watch, OtherType Function<OtherType>(Reactive<OtherType> reactive) read) {
    return const Placeholder();
  }
}

class _ReactiveWidgetState extends State<ReactiveWidget> {

  Watcher? _watcher;

  late final WatcherManager _watcherManager = WatcherManager((WatcherUpdateReferrer? referrer) {
    setState(() {
      _watcher = _watcherManager.createWatcher(referrer);
    });
  });
  
  @override
  void initState() {
    super.initState();
    
    _watcher = _watcherManager.createWatcher(null);
  }

  @override
  void dispose() {
    _watcher = null;
    _watcherManager.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget._builder != null) return widget._builder!(context, _watcher!, Reactive.reader);
    return widget.build(context, _watcher!, Reactive.reader);
  }

}

