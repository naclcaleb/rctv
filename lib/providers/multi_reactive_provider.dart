import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:rctv/core/supervised_reactive.dart';
import 'package:rctv/providers/reactive_supervisor_provider.dart';
import '../core/reactive.dart';

/*
  Very basic widget that rebuilds on any update to a Reactive
*/

class InheritedReactive<DataType> extends StatelessWidget {

  final ReactiveBase<DataType> reactive;
  late final Widget child;

  InheritedReactive(this.reactive, {super.key});

  static DataType of<DataType>(BuildContext context) {
    final inheritedReactive = _InheritedReactive.maybeOf<DataType>(context);
    assert(inheritedReactive != null, 'No InheritedReactive found in this context!');
    return inheritedReactive!.reactive.read();
  }

  void setChild(Widget child) {
    this.child = child;
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedReactive<DataType>(reactive, child: child);
  }
}
class _InheritedReactive<DataType> extends InheritedWidget {

  final ReactiveBase<DataType> reactive;

  const _InheritedReactive(this.reactive, { super.key, required super.child});
    
  static _InheritedReactive<DataType>? maybeOf<DataType>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_InheritedReactive<DataType>>();
  }

  static DataType of<DataType>(BuildContext context) {
    final inheritedReactive = maybeOf<DataType>(context);
    assert(inheritedReactive != null, 'No InheritedReactive found in this context!');
    return inheritedReactive!.reactive.read();
  }

  @override
  bool updateShouldNotify(_InheritedReactive oldWidget) => oldWidget.reactive != reactive;
  
}

class MultiReactiveProvider extends StatefulWidget {

  final List<InheritedReactive> reactives;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const MultiReactiveProvider(this.reactives, {required this.builder, this.child, super.key});

  @override
  State<MultiReactiveProvider> createState() => _MultiReactiveProviderState();
}

class _MultiReactiveProviderState extends State<MultiReactiveProvider> {
  
  final List<ReactiveSubscription> _reactiveSubscriptions = [];

  Widget _buildInheritedReactiveTree<T>(int index) {
    if (index >= widget.reactives.length) return widget.builder(context, widget.child);
    final inheritedReactive = widget.reactives[index] as InheritedReactive<T>;
    inheritedReactive.setChild(_buildInheritedReactiveTree(index + 1));
    return inheritedReactive;
  }

  @override
  void initState() {
    super.initState();

    for (final reactive in widget.reactives) {
      //For supervised reactives, register them if possible
      if (reactive.reactive is SupervisedReactive) {
        final supervisedReactive = reactive.reactive as SupervisedReactive;
        final supervisor = ReactiveSupervisorProvider.of(context);
        if (supervisor != null) {
          supervisedReactive.setSupervisor(supervisor);
        }
      }

      _reactiveSubscriptions.add(reactive.reactive.watch((newValue, prevValue) {
        setState(() {});
      }));
    }
  }

  @override
  void dispose() {
    for (final subscription in _reactiveSubscriptions) {
      subscription.dispose();
    }
    for (final reactive in widget.reactives) {
      if (reactive.reactive is SupervisedReactive) {
        final supervisedReactive = reactive.reactive as SupervisedReactive;
        supervisedReactive.removeSupervisor();
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildInheritedReactiveTree(0);
  }

}