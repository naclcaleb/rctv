import 'package:flutter/widgets.dart';
import '../core/reactive.dart';

/*
  Very basic widget that rebuilds on any update to a Reactive
*/

class ReactiveListenerWidget<DataType> extends StatefulWidget {

  final ReactiveBase<DataType> reactive;
  final ReactiveListener<DataType> listener;
  final Widget child;

  const ReactiveListenerWidget(this.reactive, {required this.listener, required this.child, super.key});

  @override
  State<ReactiveListenerWidget<DataType>> createState() => _ReactiveListenerWidget<DataType>();
}

class _ReactiveListenerWidget<DataType> extends State<ReactiveListenerWidget<DataType>> {
  
  late ReactiveSubscription _reactiveSubscription;

  @override
  void initState() {
    super.initState();

    _reactiveSubscription = widget.reactive.watch(widget.listener);
  }

  @override
  void dispose() {
    _reactiveSubscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

}