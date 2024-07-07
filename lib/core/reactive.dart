import 'dart:async';

import 'package:flutter/foundation.dart';

abstract interface class ReactiveBase<DataType> {
  DataType read();
  ReactiveSubscription watch(ReactiveListener<DataType> listener);
  void dispose();
}

class ReactiveSubscription {
  final void Function() dispose;

  ReactiveSubscription(this.dispose);
}

typedef ReactiveListener<DataType> = void Function(DataType newValue, DataType prevValue);

class Reactive<DataType> with ChangeNotifier implements ReactiveBase<DataType> {

  DataType _value;
  DataType _prevValue;

  final List<StreamSubscription?> _streamSubscriptions = [];

  Reactive(DataType initialValue) : _value = initialValue, _prevValue = initialValue;

  void set(DataType newValue) {
    _prevValue = _value;
    _value = newValue;

    notifyListeners();
  }

  void addSourceStream<Type>(Stream<Type> sourceStream, DataType Function(Type data) valueFromData) {
    _streamSubscriptions.add(sourceStream.listen((data) {
      set(valueFromData(data));
    }));
  }

  @override
  DataType read() => _value;

  /*
  Unfortunately, Dart currently has no convenient way to handle immutability.
  Because of the language limitations, this package allows
  mutating data objects directly.
  However, it is designed to happen in a way that minimizes side effects by 
  happening only inside this update function.
  This is the ONLY way reactive values should be updated with this package.
  */
  void update(DataType Function(DataType workingCopy) updater) {
    //Ideally, we'd clone the object here before the user performs any transformations
    final workingCopy = _value;

    //Run the updates
    updater(workingCopy);

    //Set the value and notify listeners
    set(workingCopy);
  }

  @override
  ReactiveSubscription watch(ReactiveListener<DataType> listener) {
    listener0() {
      listener(_value, _prevValue);
    }
    addListener(listener0);

    return ReactiveSubscription(() {
      removeListener(listener0);
    });
  }

  @override
  void dispose() {
    for (final sub in _streamSubscriptions) {
      sub?.cancel();
    }
    super.dispose();
  }

}


