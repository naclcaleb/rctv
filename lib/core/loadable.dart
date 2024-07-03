import 'dart:async';

import 'reactive.dart';
import 'reactive_stream.dart';

enum LoadableState {
  notStarted,
  loading,
  error,
  data,
  done //Optional, usually for marking the end of a paginated list of loads
}

class LoadableUpdate<ValueType> {
  final LoadableState state;
  final String? error;
  final ValueType? data;

  LoadableUpdate(this.state, {this.error, this.data});
}

//Designed to be created only in viewmodels
class Loadable<ValueType> {

  Future<ValueType?> Function()? _currentFuture;

  final _reactiveStream = ReactiveStream<LoadableUpdate<ValueType>>(null);
  ReactiveStream<LoadableUpdate<ValueType>> get reactive => _reactiveStream;

  ValueType? get value => _reactiveStream.read()?.data;

  set value(ValueType? newValue) {
    _reactiveStream.add(LoadableUpdate<ValueType>(LoadableState.data, data: newValue));
  }

  Future<void> reload() async {
    if (_currentFuture != null) await loadWithFuture(_currentFuture!);
  }

  Future<ValueType?> loadWithFuture(Future<ValueType?> Function() future) async {

    _currentFuture = future;

    //Start loading
    _reactiveStream.add(LoadableUpdate<ValueType>(LoadableState.loading));

    //Load the data
    final newData = await future().catchError((error) {
      _reactiveStream.add(LoadableUpdate<ValueType>(LoadableState.error, error: error.toString()));
      throw error;
    });

    //Update the stream
    if (newData != null) _reactiveStream.add(LoadableUpdate<ValueType>(LoadableState.data, data: newData));

    return newData;
  }

  Future<ValueType?> silentlyLoadWithFuture(Future<ValueType?> Function() future) async {
    _currentFuture = future;

    //Load the data
    final newData = await future().catchError((error) {
      _reactiveStream.add(LoadableUpdate<ValueType>(LoadableState.error, error: error.toString()));
      throw error;
    });

    //Update the stream
    if (newData != null) _reactiveStream.add(LoadableUpdate<ValueType>(LoadableState.data, data: newData));

    return newData;
  }
  
  void dispose() {
    _reactiveStream.dispose();
  }

  ReactiveSubscription listenToStream(void Function(LoadableUpdate<ValueType>? update, LoadableUpdate<ValueType>? prevUpdate) listener) {
    return _reactiveStream.watch(listener);
  }

}