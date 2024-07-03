import 'dart:async';

import 'reactive.dart';

class ReactiveStream<DataType> implements ReactiveBase<DataType> {

  DataType? _currentValue;
  DataType? _prevValue;

  final _streamController = StreamController<DataType?>.broadcast();

  ReactiveStream([DataType? initialValue]) {
    _currentValue = initialValue;
  }

  void add(DataType? value) {
    _prevValue = _currentValue;
    _streamController.add(value);
    _currentValue = value;
  }

  @override
  DataType? read() => _currentValue;

  @override
  ReactiveSubscription watch(ReactiveListener<DataType> listener) {

    final subscription = _streamController.stream.listen((newValue) {
      listener(newValue, _prevValue);
    });

    return ReactiveSubscription(() {
      subscription.cancel();
    });

  }

  @override
  void dispose() {
    _streamController.close();
  }

}