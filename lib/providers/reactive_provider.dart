import 'package:flutter/widgets.dart';
import 'package:rctv/core/supervised_reactive.dart';
import 'package:rctv/providers/reactive_supervisor_provider.dart';
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

    //For supervised reactives, register them if possible
    if (widget.reactive is SupervisedReactive) {
      final supervisedReactive = widget.reactive as SupervisedReactive;
      final supervisor = ReactiveSupervisorProvider.of(context);
      if (supervisor != null) {
        supervisedReactive.setSupervisor(supervisor);
      }
    }

    _reactiveSubscription = widget.reactive.watch((newValue, prevValue) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _reactiveSubscription.dispose();
    
    if (widget.reactive is SupervisedReactive) {
      final supervisedReactive = widget.reactive as SupervisedReactive;
      supervisedReactive.removeSupervisor();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.reactive.read(), widget.child);
  }

}