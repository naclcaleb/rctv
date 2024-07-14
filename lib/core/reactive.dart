library rctv;

import 'dart:async';
import 'package:uuid/uuid.dart';
import 'base_manager.dart';

part 'reactive_observer.dart';
part 'async_reactive_manager.dart';
part 'reactive_manager.dart';

class ReactiveSubscription {
  final void Function() dispose;
  final String _uuid;

  String getUuid() => _uuid;

  ReactiveSubscription(this._uuid, this.dispose);
}

typedef WatchFilter<DataType> = bool Function(DataType newValue, DataType oldValue);

class _StreamEntry<StreamType> {
  final StreamSubscription<StreamType> subscription;
  final Stream<StreamType> stream;
  StreamType? latestValue;
  _StreamEntry({ required this.stream, required this.subscription, required this.latestValue });
}
class _ReactiveEntry<DataType> {
  final Reactive<DataType> reactive;
  final ReactiveSubscription subscription;

  _ReactiveEntry({ required this.reactive, required this.subscription });
}

class Watcher<DataType> {

  final void Function() _listener;
  final List<_ReactiveEntry> _reactiveSubscriptions = [];
  final List<_StreamEntry> _streamSubscriptions = [];

  int _reactiveCounter = 0;
  int _streamCounter = 0;

  Watcher(this._listener);

  bool isInitialized = false;

  void _beforeListener() {
    _reactiveCounter = 0;
    _streamCounter = 0;
  }

  void _listenerWrapper() {
    _beforeListener();
    _listener();
  }

  NewType call<NewType>(Reactive<NewType> reactive, { WatchFilter<NewType>? filter }) {
    if (_reactiveCounter >= _reactiveSubscriptions.length) {
      _reactiveSubscriptions.add(
        _ReactiveEntry(reactive: reactive, subscription: reactive.watch((newValue, oldValue) {
          if (filter != null && !filter(newValue, oldValue)) return;
          _listenerWrapper();
        }))
      ); 
    }
    _reactiveCounter++;
    return reactive.read();
  }

  Future<NewType> async<NewType>(AsyncReactive<NewType> reactive) async {
    if (_reactiveCounter >= _reactiveSubscriptions.length) {
      _reactiveSubscriptions.add(
        _ReactiveEntry(reactive: reactive, subscription: reactive.watch((newUpdate, oldUpdate) {
          if (newUpdate.status != ReactiveAsyncStatus.data && newUpdate.status != ReactiveAsyncStatus.done) return;
          _listenerWrapper();
        }))
      );
    }
    _reactiveCounter++;
    return reactive.readValue();
  }

  Future<StreamType> stream<StreamType>(Stream<StreamType> stream, { WatchFilter<StreamType>? filter }) async {
    if (_streamCounter >= _streamSubscriptions.length) {
      _streamSubscriptions.add(
        _StreamEntry<StreamType>(stream: stream, subscription: stream.listen((item) {
          final streamEntry = _streamSubscriptions[_streamCounter] as _StreamEntry<StreamType>;
          if (filter != null && streamEntry.latestValue != null && (streamEntry.latestValue == item || !filter(item, streamEntry.latestValue!))) return;
          streamEntry.latestValue = item;
          _listenerWrapper();
        }), latestValue: null)
      );
    }

    final streamEntry = _streamSubscriptions[_streamCounter] as _StreamEntry<StreamType>;
    _streamCounter++;
    try {
      return streamEntry.latestValue ?? await streamEntry.stream.last;
    }
    on Exception catch(er) {
      throw ReactiveException(er.toString());
    }
  }

  void dispose() {
    for (final reactiveEntry in _reactiveSubscriptions) {
      reactiveEntry.reactive.dispose();
      if (reactiveEntry.reactive.shouldAutoDispose) reactiveEntry.reactive.dispose();
    }
    _reactiveSubscriptions.clear();

    for (final streamEntry in _streamSubscriptions) {
      streamEntry.subscription.cancel();
    }
    _streamSubscriptions.clear();
  }

}

typedef ReactiveUpdateListener<DataType> = void Function(DataType newValue, DataType oldValue);
typedef ReactiveSource<DataType> = DataType Function(DataType? currentValue, Watcher<DataType> watch, OtherType Function<OtherType>(Reactive<OtherType> reactive) read);
typedef AsyncReactiveSource<DataType> = Future<DataType> Function(DataType? currentValue, Watcher<DataType> watch, OtherType Function<OtherType>(Reactive<OtherType> reactive) read);

class ReactiveException implements Exception {
  final String message;
  const ReactiveException(this.message);

  @override
  String toString() {
    return message;
  }
}

class ReactiveTransaction<DataType> {

  final String name;
  final FutureOr<DataType> Function(DataType currentValue) runner;

  ReactiveTransaction({ required this.name, required this.runner });

  FutureOr<DataType> execute(DataType currentValue) {
    return runner(currentValue);
  }
  
}

ReactiveTransaction<DataType> rctvTransaction<DataType>(FutureOr<DataType> Function(DataType currentValue) runner, { String name = 'Anonymous transaction' }) {
  return ReactiveTransaction(name: name, runner: runner);
}

class Reactive<DataType> {

  DataType? _value;
  DataType? _prevValue;

  bool shouldAutoDispose = true;
  String? _name;
  bool _isTransactional = false;
  ReactiveObserver? _observer;

  DataType get value {
    assert(_value != null, 'Attempted to access value from uninitialized Reactive');
    return _value!;
  }
  DataType get prevValue {
    assert(_prevValue != null, 'Attempted to access value from uninitialized Reactive');
    return _prevValue!;
  }

  static const _uuidGenerator = Uuid();

  late ReactiveSource? _source;
  late Watcher? _watcher;

  final Map<String, (ReactiveSubscription, ReactiveUpdateListener<DataType>)> _subscriptions = {};

  Reactive(DataType initialValue) : _value = initialValue, _prevValue = initialValue, _source = null;

  Reactive._sourced(ReactiveSource<DataType> source, { DataType? initialValue }) : _source = source as ReactiveSource {
    _watcher = Watcher<DataType>(() {
      assert(_source != null && _watcher != null);
      _internalSet( _source!(value, _watcher! as Watcher<DataType>, reader) );
    });
    initialValue ??= source(null, _watcher! as Watcher<DataType>, reader);

    _value = initialValue;
    _prevValue = initialValue;
  }

  Reactive<DataType> transactional() { _isTransactional = true; return this; }
  Reactive<DataType> autoDispose(bool setting) { shouldAutoDispose = setting; return this; }
  Reactive<DataType> observed({ String? name }) { _name = name; return this.transactional(); }

  bool isObserved() => _name != null && _isTransactional;

  void _setObserver(ReactiveObserver observer) {
    assert(isObserved(), 'Only observed reactives can have an observer. Try adding `.observed()` to your reactive.');
    _observer = observer;
  }

  DataType read() => value;

  static DataType reader<DataType>(Reactive<DataType> reactive) => reactive.read();

  void _notifyUpdates() {
    for (final subscription in _subscriptions.values) {
      subscription.$2(value, prevValue);
    }
  }

  void _internalSet(DataType value) {
    _prevValue = _value;
    _value = value;
    _notifyUpdates();
  }

  void set(DataType value) {
    //Still debating the use of this with sourced reactives
    //if (_source != null) throw const ReactiveException('`set` and `update` methods may not be used on a sourced reactive');
    if (_isTransactional) throw const ReactiveException('`set` and `update` methods may not be used on a transactional reactive');
    _internalSet(value);
  }

  /*
  Unfortunately, Dart currently has no convenient way to handle immutability.
  Because of the language limitations, this package allows
  mutating data objects directly.
  However, it is designed to happen in a way that minimizes side effects by 
  happening only inside this update function.
  This is the ONLY way reactive values should be updated with this package.
  (This is a similar pattern to Flutter's `setState`)
  */
  void _internalUpdate(DataType Function(DataType workingCopy) updater) {
    //Ideally, we'd clone the object here before the user performs any transformations
    final workingCopy = value;

    //Run the updates
    updater(workingCopy);

    //Set the value and notify listeners
    _internalSet(workingCopy);
  }

  void internalUpdate(DataType Function(DataType workingCopy) updater) {
    _internalUpdate(updater);
  }

  Future<void> perform(ReactiveTransaction<DataType> transaction) async {

      DataType result;

      //First, let's execute the transaction
      final potentialFuture = transaction.execute(read());
      if (potentialFuture is Future) {
        result = await potentialFuture;
      }
      else {
        result = potentialFuture;
      }

      //Notify the supervisor if available
      if (_observer != null) {
        _observer!.receiveTransaction(transaction, result, this);
      }
      
      //Next, notify the listeners
      _internalSet(result);

  }

  ReactiveSubscription watch(ReactiveUpdateListener<DataType> listener) {
    final key = _uuidGenerator.v4();
    final subscription = ReactiveSubscription(key, () {
      _subscriptions.remove(key);
    });
    _subscriptions[key] = (subscription, listener);
    return subscription;
  }

  void dispose() {
    for (final subscriptionKey in _subscriptions.keys) {
      final subscription = _subscriptions[subscriptionKey]!;
      subscription.$1.dispose();
      _subscriptions.remove(subscriptionKey);
    }
    _watcher?.dispose();
    _watcher = null;

    if (_observer != null) {
      _observer?.unregister(this);
      _observer = null;
    }
  }

  //Now, we provide the static convenience constructors for sourced reactives
  static Reactive<DataType> source<DataType>(ReactiveSource<DataType> source, { DataType? initialValue }) {
    return Reactive._sourced(source, initialValue: initialValue);
  }

  static AsyncReactive<DataType> asyncSource<DataType>(AsyncReactiveSource<DataType> source, { DataType? initialValue, bool autoExecute = true, bool silentLoading = false }) {
    return AsyncReactive(source, initialValue: initialValue, autoExecute: autoExecute, silentLoading: silentLoading);
  }

}

class AsyncReactive<DataType> extends Reactive<ReactiveAsyncUpdate<DataType>> {

  final AsyncReactiveSource<DataType> _asyncSource;

  bool _autoExecute = true;
  bool _silentLoading = false;

  late void Function(bool silent) _loadFunc;

  Future<DataType> readValue() async {
    if (value.status == ReactiveAsyncStatus.data || value.status == ReactiveAsyncStatus.done) return value.data!;
    
    final completer = new Completer<DataType>();

    final tempSubscription = watch((newValue, _) {
      if (newValue.status == ReactiveAsyncStatus.data || newValue.status == ReactiveAsyncStatus.done) {
        completer.complete(newValue.data!);
      }
    });

    final result = await completer.future;
    tempSubscription.dispose();
    return result;
  }

  void Function({ bool? silent }) get load => ({ bool? silent }) => _loadFunc(silent ?? _silentLoading);

  @override
  AsyncReactive<DataType> transactional() { return super.transactional() as AsyncReactive<DataType>; }
  @override
  AsyncReactive<DataType> autoDispose(bool setting) { return super.autoDispose(setting) as AsyncReactive<DataType>; }
  @override
  AsyncReactive<DataType> observed({String? name}) { return super.observed(name: name) as AsyncReactive<DataType>; }
  
  AsyncReactive(AsyncReactiveSource<DataType> source, { DataType? initialValue, bool autoExecute = true, bool silentLoading = false }) : _asyncSource = source, _autoExecute = autoExecute, _silentLoading = silentLoading, super(initialValue != null ? ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.data, data: initialValue) : ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.notStarted)) {
    _source = (currentValue, watch, read) {
      _loadFunc = (silent) {

        //Start loading
        if (!silent) _internalSet(ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.loading));

        //Create the future
        _asyncSource(currentValue?.data, watch as Watcher<DataType>, read)
          .then((value) {
            //On completion, send a data update
            _internalSet(ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.data, data: value));
          })
          .catchError((error) {
            //On error, send an error update
            _internalSet(ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.error, error: error));
          });
      };

      //If it's set up to autoexecute, we should just call the load function right away
      if (_autoExecute) {
        _loadFunc(_silentLoading);
        return ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.loading);
      }

      //We're not doing any mutating here
      return currentValue!;
    };
    
    _watcher = Watcher<DataType>(() {
      assert(_source != null && _watcher != null);
      _source!(value, _watcher! as Watcher<DataType>, Reactive.reader);
    });

    _value = _source!(_value, _watcher! as Watcher<DataType>, Reactive.reader);
    _prevValue = _value;
  }
    
}

enum ReactiveAsyncStatus {
  notStarted,
  loading,
  data,
  done,
  error
}

class ReactiveAsyncUpdate<DataType> {
  final String? error;
  final DataType? data;
  final ReactiveAsyncStatus status;

  ReactiveAsyncUpdate({ required this.status, this.data, this.error });

  T when<T>({
    required T Function() loading,
    required T Function(String error) error,
    required T Function(DataType data) data,
    T Function()? notStarted
  }) {
    
    return switch (status) {
      ReactiveAsyncStatus.notStarted => notStarted != null ? notStarted() : loading(),
      ReactiveAsyncStatus.loading => loading(),
      ReactiveAsyncStatus.error => error(this.error!),
      ReactiveAsyncStatus.data when this.data != null => data(this.data!),
      ReactiveAsyncStatus.done when this.data != null => data(this.data!),
      _ => throw const ReactiveException('`data` or `done` status sent without data')
    };

  }
}