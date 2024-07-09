import 'package:flutter/widgets.dart';
import 'package:rctv/core/supervised_reactive.dart';
import 'package:rctv/providers/reactive_supervisor_provider.dart';
import '../core/reactive.dart';

/*
  Very basic widget that rebuilds on any update to a Reactive
*/

class InheritedReactive<DataType> extends InheritedWidget {

  final ReactiveBase<DataType> reactive;

  const InheritedReactive(this.reactive, { super.key, required super.child});
    
  static InheritedReactive<DataType>? maybeOf<DataType>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedReactive<DataType>>();
  }

  static DataType of<DataType>(BuildContext context) {
    final inheritedReactive = maybeOf<DataType>(context);
    assert(inheritedReactive != null, 'No InheritedReactive found in this context!');
    return inheritedReactive!.reactive.read();
  }

  @override
  bool updateShouldNotify(InheritedReactive oldWidget) => oldWidget.reactive != reactive;
  
}

class MultiReactiveProvider<DataType> extends StatefulWidget {

  final List<ReactiveBase<DataType>> reactives;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const MultiReactiveProvider(this.reactives, {required this.builder, this.child, super.key});

  @override
  State<MultiReactiveProvider<DataType>> createState() => _MultiReactiveProviderState<DataType>();
}

class _MultiReactiveProviderState<DataType> extends State<MultiReactiveProvider<DataType>> {
  
  final List<ReactiveSubscription> _reactiveSubscriptions = [];

  InheritedReactive<T> _createInheritedReactiveFromReactive<T>(ReactiveBase<T> reactive, child) {
    return InheritedReactive<T>(reactive, child: child);
  }

  Widget _buildInheritedReactiveTree(int index) {
    if (index >= widget.reactives.length) return widget.builder(context, widget.child);
    return _createInheritedReactiveFromReactive(widget.reactives[index], _buildInheritedReactiveTree(index + 1));
  }

  @override
  void initState() {
    super.initState();

    for (final reactive in widget.reactives) {
      //For supervised reactives, register them if possible
      if (reactive is SupervisedReactive) {
        final supervisedReactive = reactive as SupervisedReactive;
        final supervisor = ReactiveSupervisorProvider.of(context);
        if (supervisor != null) {
          supervisedReactive.setSupervisor(supervisor);
        }
      }

      _reactiveSubscriptions.add(reactive.watch((newValue, prevValue) {
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
      if (reactive is SupervisedReactive) {
        final supervisedReactive = reactive as SupervisedReactive;
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