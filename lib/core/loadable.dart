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
class Loadable<ValueType> implements ReactiveBase {

  //For easy error handling
  static void Function(Exception error) defaultErrorHandler = (error) {}; 

  Future<ValueType?> Function()? _currentFuture;

  final ReactiveStream<LoadableUpdate<ValueType>> _reactiveStream = ReactiveStream<LoadableUpdate<ValueType>>(LoadableUpdate(LoadableState.notStarted));
  ReactiveStream<LoadableUpdate<ValueType>> get reactive => _reactiveStream;

  ValueType? get value => _reactiveStream.read().data;

  @override
  ValueType? read() => value;

  void Function(Exception error)? _errorHandler;

  Loadable([ValueType? initialValue]) {
    if (initialValue != null) _reactiveStream.add(LoadableUpdate(LoadableState.data, data: initialValue));
  }

  set value(ValueType? newValue) {
    _reactiveStream.add(LoadableUpdate<ValueType>(LoadableState.data, data: newValue));
  }

  Future<void> reload() async {
    if (_currentFuture != null) await loadWithFuture(_currentFuture!);
  }

  Loadable<ValueType> withErrorHandler({void Function(Exception error)? handler}) {
    if (handler != null) _errorHandler = handler;
    else _errorHandler = Loadable.defaultErrorHandler;
    return this;
  }

  Future<ValueType?> loadWithFuture(Future<ValueType?> Function() future) async {

    _currentFuture = future;

    //Start loading
    _reactiveStream.add(LoadableUpdate<ValueType>(LoadableState.loading));

    //Load the data
    final newData = await future().catchError((error) {
      _reactiveStream.add(LoadableUpdate<ValueType>(LoadableState.error, error: error.toString()));

      if (_errorHandler != null) _errorHandler!(error);

      return null;
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
  
  @override
  void dispose() {
    _reactiveStream.dispose();
  }

  @override
  ReactiveSubscription watch(ReactiveListener<LoadableUpdate<ValueType>> listener) {
    return listenToStream(listener);
  }

  ReactiveSubscription listenToStream(ReactiveListener<LoadableUpdate<ValueType>> listener) {
    return _reactiveStream.watch(listener);
  }

}