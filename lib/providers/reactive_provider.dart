import 'package:flutter/widgets.dart';
import '../core/reactive.dart';

/*
  Very basic widget that rebuilds on any update to a Reactive
*/

class ReactiveProvider<DataType> extends StatefulWidget {

  final ReactiveBase<DataType> reactive;
  final Widget Function(BuildContext context, DataType? value, Widget? child) builder;
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

    _reactiveSubscription = widget.reactive.watch((newValue, prevValue) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _reactiveSubscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.reactive.read(), widget.child);
  }

}