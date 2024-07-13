import 'package:flutter/widgets.dart';
import 'package:rctv/providers/reactive_observer_provider.dart';
import '../core/reactive.dart';

/*
  Very basic widget that rebuilds on any update to a Reactive
*/

class ReactiveProvider<DataType> extends StatefulWidget {

  final Reactive<DataType> reactive;
  final Widget Function(BuildContext context, DataType value, Widget? child) builder;
  final Widget? child;

  const ReactiveProvider(this.reactive, {required this.builder, this.child, super.key});

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