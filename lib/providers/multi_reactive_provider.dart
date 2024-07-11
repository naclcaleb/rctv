import 'package:flutter/widgets.dart';
import 'package:rctv/providers/reactive_provider.dart';
import '../core/reactive.dart';

/*
  Very basic widget that rebuilds on any update to a Reactive
*/

class InheritedReactive<DataType> extends StatelessWidget {

  final ReactiveBase<DataType> reactive;
  Widget Function(BuildContext context)? builder;

  InheritedReactive(this.reactive, {super.key});

  static DataType of<DataType>(BuildContext context) {
    return _InheritedReactive.of<DataType>(context);
  }

  void setBuilder(Widget Function(BuildContext context) builder) {
    this.builder = builder;
  }



  @override
  Widget build(BuildContext context) {
    assert(builder != null, 'InheritedReactive must be used within a MultiReactiveProvider');
    return _InheritedReactive<DataType>(reactive, child: ReactiveProvider(
      reactive,
      builder: (context, reactiveValue, _) => builder!(context)
    ));
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
  bool updateShouldNotify(_InheritedReactive oldWidget) => true;
  
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
  
  Widget _buildInheritedReactiveTree<T>(BuildContext context, int index) {
    if (index >= widget.reactives.length) return widget.builder(context, widget.child);
    final inheritedReactive = widget.reactives[index] as InheritedReactive<T>;
    inheritedReactive.setBuilder( (context) => _buildInheritedReactiveTree(context, index + 1));
    return inheritedReactive.build(context);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _buildInheritedReactiveTree(context, 0);
  }

}