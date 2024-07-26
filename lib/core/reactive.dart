library rctv;

import 'dart:async';
import 'dart:developer';
import 'package:uuid/uuid.dart';
import 'base_manager.dart';

part 'reactive_observer.dart';
part 'async_reactive_manager.dart';
part 'reactive_manager.dart';

class ReactiveSubscription {
  final void Function() dispose; //For disposing the listener connection; provided by the reactive
  
  //For identifying these by ID
  final String _uuid; 
  String getUuid() => _uuid;

  ReactiveSubscription(this._uuid, this.dispose);
}

//Used to filter which updates from a reactive or stream dependency will trigger the original reactive to reload
typedef WatchFilter<DataType> = bool Function(DataType newValue, DataType oldValue);

//Holds the necessary data for a stream dependency, stored in a Watcher
class _StreamEntry<StreamType> {
  StreamSubscription<StreamType> subscription; 
  Stream<StreamType>? stream;
  StreamType? latestValue;
  _StreamEntry({ required this.stream, required this.subscription, required this.latestValue });
}

//Holds the data for a reactive dependency, stored in a watcher
class _ReactiveEntry<DataType> {
  final Reactive<DataType> reactive;
  DataType? latestValue;
  final ReactiveSubscription subscription;

  _ReactiveEntry({ required this.reactive, required this.subscription });
}

//Holds the data for a future dependency, stored in a watcher
class _FutureEntry<DataType> {
  DataType? latestValue;
  _FutureEntry({ this.latestValue });
}

//The _WatcherUpdateReferrer is used to identify which dependency triggered an update.
//Only dependencies defined *after* the referrer will be reevaluated (particularly, this applies to streams)
enum WatcherReferrerType {
  reactive,
  stream,
  future
}
typedef WatcherUpdateReferrer = ({WatcherReferrerType referrerType, int index});

class WatcherManager {

  //What the watcher calls to update the reactive; ultimately triggers an `_internalSet` call
  //`_listener` is not called directly, but instead through a call to `_listenerWrapper`
  final void Function(WatcherUpdateReferrer referrer) _listener;

  //Tracking reactive and stream dependencies
  final List<_ReactiveEntry> _reactiveSubscriptions = [];
  final List<_StreamEntry> _streamSubscriptions = [];
  final List<_FutureEntry> _futureDependencies = [];

  final String? reactiveDebugName;

  WatcherManager(this._listener, { this.reactiveDebugName });

  //Resets the counters and referrer
  Watcher createWatcher(WatcherUpdateReferrer? referrer) {
    return Watcher._initialize(_reactiveSubscriptions, _streamSubscriptions, _futureDependencies, notifyUpdates, referrer, debugName: reactiveDebugName);
  }

  void notifyUpdates(WatcherUpdateReferrer referrer) {
    _listener(referrer);
  }

  void dispose() {
    for (final reactiveEntry in _reactiveSubscriptions) {
      reactiveEntry.subscription.dispose();
      if (  reactiveEntry.reactive.shouldAutoDispose && 
            !reactiveEntry.reactive._hasListeners() ) reactiveEntry.reactive.dispose();
    }
    _reactiveSubscriptions.clear();

    for (final streamEntry in _streamSubscriptions) {
      streamEntry.subscription.cancel();
      streamEntry.stream = null;
    }
    _streamSubscriptions.clear();

    _futureDependencies.clear();
  }

}

//The Watcher is used to define the dependencies of a sourced Reactive.
//It's usage looks like:
//- `watch(reactiveObject)`
//- `watch.async(asyncReactiveObject)`
//- `watch.stream(streamReactiveObject)`
class Watcher {

  //These counters update sequentially through a Reactive source function call.
  //They represent the index of a given dependency's entry.
  //This is a similar pattern to that used by React Hooks, for example.
  int _reactiveCounter = 0;
  int _streamCounter = 0;
  int _futureCounter = 0;

  //Optionally, what object triggered the most recent update
  final WatcherUpdateReferrer? _referrer;

  final String? _reactiveDebugName;

  final void Function(WatcherUpdateReferrer referrer) _notify;

  //These parameters come from the WatcherManager
  final List<_ReactiveEntry> _reactiveDependencies;
  final List<_StreamEntry> _streamDependencies;
  final List<_FutureEntry> _futureDependencies;

  Watcher._initialize(List<_ReactiveEntry> reactiveDependencies, List<_StreamEntry> streamDependencies, List<_FutureEntry> futureDependencies, void Function(WatcherUpdateReferrer referrer) notify, WatcherUpdateReferrer? referrer, { String? debugName }) : _referrer = referrer, _reactiveDependencies = reactiveDependencies, _streamDependencies = streamDependencies, _futureDependencies = futureDependencies, _notify = notify, _reactiveDebugName = debugName;

  NewType call<NewType>(Reactive<NewType> reactive, { WatchFilter<NewType>? filter }) {

    //If a subscription has not been created...
    if (_reactiveCounter >= _reactiveDependencies.length) {

      //Make a copy of the counter value
      int counter = _reactiveCounter;

      //Add a new reactive dependency
      _reactiveDependencies.add(
        
        _ReactiveEntry<NewType>(
          reactive: reactive, //This reactive
          subscription: reactive.watch((newValue, oldValue) {
            //If it doesn't pass the filter, ignore
            if (filter != null && !filter(newValue, oldValue)) return; 
            
            //Otherwise, notify the reactive of the update
            _notify((
              referrerType: WatcherReferrerType.reactive, 
              index: counter //We are the referrer
            ));
          }
        ))

      ); 
    }

    //Get the current entry
    final reactiveEntry = _reactiveDependencies[_reactiveCounter] as _ReactiveEntry<NewType>;

    //Increment the counter
    _reactiveCounter++;

    //Get the value, cache it, and return it
    final value = reactive.read();
    reactiveEntry.latestValue = value;
    return value;
  }

  void withListener<NewType>(Reactive<NewType> reactive, { WatchFilter<NewType>? filter, required ReactiveUpdateListener<NewType> listener }) {

    //If a subscription has not been created...
    if (_reactiveCounter >= _reactiveDependencies.length) {

      //Add a new reactive dependency
      _reactiveDependencies.add(
        
        _ReactiveEntry<NewType>(
          reactive: reactive, //This reactive
          subscription: reactive.watch((newValue, oldValue) {
            //If it doesn't pass the filter, ignore
            if (filter != null && !filter(newValue, oldValue)) return; 
            
            //Otherwise, run the listener
            listener(newValue, oldValue);
          }
        ))

      ); 
    }

    //Increment the counter
    _reactiveCounter++;
  }

  Future<NewType> async<NewType>(AsyncReactive<NewType> reactive) async {

    //If a subscription has not been created...
    if (_reactiveCounter >= _reactiveDependencies.length) {

      //Make a copy of the counter value
      int counter = _reactiveCounter;

      //Add a new reactive dependency
      _reactiveDependencies.add(

        _ReactiveEntry(
          reactive: reactive, 
          subscription: reactive.watch((newUpdate, oldUpdate) {

            //Filter out any loading states
            if (newUpdate.status != ReactiveAsyncStatus.data && newUpdate.status != ReactiveAsyncStatus.done) return;
            
            //Notify of the new data
            _notify((
              referrerType: WatcherReferrerType.reactive,
              index: counter
            ));
          }
        ))

      );
    }

    //Increment the counter
    _reactiveCounter++;

    //Get the new value
    return reactive.readValue();
  }

  void _disposeStreamEntry(_StreamEntry entry) {
    entry.subscription.cancel();
    entry.stream = null;
  }

  bool _referrerIsDependency() {
    //Doesn't matter if there's no referrer
    if (_referrer == null) return false;

    //Return based on the proper counter index
    return _referrer.index < switch (_referrer.referrerType) {
      WatcherReferrerType.reactive => _reactiveCounter,
      WatcherReferrerType.stream => _streamCounter,
      WatcherReferrerType.future => _futureCounter
    };
  }

  void _debugLog(String message) {
    if (_reactiveDebugName != null) {
      log('(rctv) $_reactiveDebugName: $message');
    }
  }

  Future<StreamType> stream<StreamType>({ required Stream<StreamType> Function() builder, WatchFilter<StreamType>? filter }) async {

    //Copy the counter
    int currentCounter = _streamCounter;

    //The listener for either one
    void streamListener(StreamType item) {

      //Get the current entry
      final streamEntry = _streamDependencies[currentCounter] as _StreamEntry<StreamType>;

      //Check filters
      if (filter != null && streamEntry.latestValue != null && (streamEntry.latestValue == item || !filter(item, streamEntry.latestValue as StreamType))) return;
      
      //Cache the item
      streamEntry.latestValue = item;

      //Notify of the update
      _notify((
        referrerType: WatcherReferrerType.stream,
        index: currentCounter
      ));
    }

    //If we haven't created a subscription yet, OR
    //If the update was triggered by a dependency defined prior to this one,
    //we want to rebuild the stream. This allows the stream to be dynamically generated
    //from past `watch` calls
    if (_streamCounter >= _streamDependencies.length || _referrerIsDependency()) {

      //Create a new StreamEntry to keep track of
      final stream = builder();

      //Check for a previous entry
      final prevEntry = _streamCounter >= _streamDependencies.length ? null : _streamDependencies[_streamCounter] as _StreamEntry<StreamType>;

      //Prepare a new entry
      final newEntry = _StreamEntry<StreamType>(
        stream: stream,
        subscription: stream.listen(streamListener),
        latestValue: null//prevEntry?.latestValue
      );

      //Dispose the previous entry if it exists
      if (prevEntry != null) _disposeStreamEntry(prevEntry);

      //Add the new subscription
      if (_streamCounter >= _streamDependencies.length) {
        _streamDependencies.add(newEntry);
      }
      else {
        _streamDependencies[_streamCounter] = newEntry;
      }
    }

    //Get our most current entry
    final streamEntry = _streamDependencies[_streamCounter] as _StreamEntry<StreamType>;

    //Increase the streamcounter
    _streamCounter++;

    try {
      //Return the latest value
      if (streamEntry.latestValue != null) { 
        return streamEntry.latestValue!; 
      }
      else { 
        return streamEntry.stream!.last; 
      }
    }
    on Exception catch(er) {
      log(er.toString());
      throw ReactiveException(er.toString());
    }
  }

  Future<NewType> future<NewType>({ required Future<NewType> Function() builder }) async {

    //If we haven't created an entry yet, OR the referrer was a dependency,
    //re-run the future.
    if (_futureCounter >= _futureDependencies.length || _referrerIsDependency()) {

      //Build the future
      final future = builder();

      if (_futureCounter >= _futureDependencies.length) {
        _futureDependencies.add(
          _FutureEntry<NewType>(latestValue: null)
        );
      } 

      //Get the entry
      final entry = _futureDependencies[_futureCounter] as _FutureEntry<NewType>;

      entry.latestValue = await future;

      return entry.latestValue as NewType;

    }

    //Get the entry
    final entry = _futureDependencies[_futureCounter] as _FutureEntry<NewType>;

    //Increase the future counter
    _futureCounter++;


    return entry.latestValue as NewType;

  }

}

typedef ReactiveUpdateListener<DataType> = void Function(DataType newValue, DataType oldValue);
typedef ReactiveSource<DataType> = DataType Function(DataType? currentValue, Watcher watch, OtherType Function<OtherType>(Reactive<OtherType> reactive) read);
typedef AsyncReactiveSource<DataType> = Future<DataType> Function(DataType? currentValue, Watcher watch, OtherType Function<OtherType>(Reactive<OtherType> reactive) read);
typedef _AsyncInternalReactiveSource<DataType> = ReactiveAsyncUpdate<DataType> Function(ReactiveAsyncUpdate<DataType>? currentValue, Watcher watch, OtherType Function<OtherType>(Reactive<OtherType> reactive) read);

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
  final FutureOr<DataType?> Function(DataType currentValue) runner;

  ReactiveTransaction({ required this.name, required this.runner });

  FutureOr<DataType?> execute(DataType currentValue) {
    return runner(currentValue);
  }
  
}

ReactiveTransaction<DataType> rctvTransaction<DataType>(FutureOr<DataType?> Function(DataType currentValue) runner, { String name = 'Anonymous transaction' }) {
  return ReactiveTransaction<DataType>(name: name, runner: runner);
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

  final ReactiveSource<DataType>? _source;
  WatcherManager? _watcherManager;

  final Map<String, (ReactiveSubscription, ReactiveUpdateListener<DataType>)> _subscriptions = {};

  //Make it easy to track lifecycle changes in Reactives for debugging purposes
  void _debugLog(String message) {
    if (_name != null) {
      log('(rctv) $_name: $message');
    }
  }

  Reactive(DataType initialValue, { String? debugName }) : _value = initialValue, _prevValue = initialValue, _source = null, _name = debugName;

  Reactive._sourced(ReactiveSource<DataType> source, { DataType? initialValue, String? debugName }) : _source = source, _name = debugName {
    _watcherManager = WatcherManager((referrer) {
      final watcher = _watcherManager!.createWatcher(referrer);
      assert(_source != null);
      _internalSet( _source!(value, watcher, reader) );
    }, reactiveDebugName: debugName);

    
    initialValue ??= source(null, _watcherManager!.createWatcher(null), reader);
    _debugLog('Initital value is $initialValue');

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
    _debugLog('Value updated, old=$_prevValue, new=$_value');
    _notifyUpdates();
  }

  void set(DataType value) {
    //Still debating the use of this with sourced reactives
    //if (_source != null) throw const ReactiveException('`set` and `update` methods may not be used on a sourced reactive');
    if (_isTransactional) throw const ReactiveException('`set` and `update` methods may not be used on a transactional reactive');
    _internalSet(value);
  }

  void refresh() {
    if (_source != null) {
      final watcher = _watcherManager!.createWatcher((index: -1, referrerType: WatcherReferrerType.reactive));
      _internalSet( _source(value, watcher, reader) );
    }
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

  bool _hasListeners() {
    return _subscriptions.isNotEmpty;
  }

  Future<void> perform<TransactionDataType>(ReactiveTransaction<TransactionDataType> transaction, { bool silent = true }) async {
      assert(TransactionDataType == DataType, 'Reactive<$DataType> can only perform transactions of type ReactiveTransaction<$DataType>');

      _debugLog('Performing Transaction ${transaction.name}');

      DataType? result;

      //First, let's execute the transaction
      final potentialFuture = transaction.execute(read() as TransactionDataType);
      if (potentialFuture is Future) {
        result = await potentialFuture as DataType?;
      }
      else {
        result = potentialFuture as DataType?;
      }

      //Notify the supervisor if available
      if (_observer != null) {
        _observer!.receiveTransaction(transaction, result, this);
      }
      
      //Next, notify the listeners if a result was returned
      if (result != null) _internalSet(result);

  }

  ReactiveSubscription watch(ReactiveUpdateListener<DataType> listener) {
    final key = _uuidGenerator.v4();
    final subscription = ReactiveSubscription(key, () {
      _subscriptions.remove(key);
    });
    _subscriptions[key] = (subscription, listener);
    _debugLog('New subscription, total ${_subscriptions.length}');
    return subscription;
  }

  void dispose() {
    _debugLog('Disposing');
    _subscriptions.clear();
    _watcherManager?.dispose();
    _watcherManager = null;

    if (_observer != null) {
      _observer?.unregister(this);
      _observer = null;
    }
  }

  //Now, we provide the static convenience constructors for sourced reactives
  static Reactive<DataType> source<DataType>(ReactiveSource<DataType> source, { DataType? initialValue, String? debugName }) {
    return Reactive<DataType>._sourced(source, initialValue: initialValue, debugName: debugName);
  }

  static AsyncReactive<DataType> asyncSource<DataType>(AsyncReactiveSource<DataType> source, { DataType? initialValue, bool autoExecute = true, bool silentLoading = false, String? debugName }) {
    return AsyncReactive<DataType>(source, initialValue: initialValue, autoExecute: autoExecute, silentLoading: silentLoading, debugName: debugName);
  }

  static AsyncReactive<List<Object?>> asyncCollection(List<AsyncReactive<Object?>> reactives, { String? debugName }) {
    return AsyncReactive<List<Object?>>((currentValue, watch, _) async {
      final futures = reactives.map((reactive) => watch.async(reactive));
      return Future.wait(futures);
    });
  }

}

class AsyncReactive<DataType> extends Reactive<ReactiveAsyncUpdate<DataType>> {

  final AsyncReactiveSource<DataType> _asyncSource;

  _AsyncInternalReactiveSource<DataType>? _internalSource;

  final bool _autoExecute;
  final bool _silentLoading;

  late void Function(bool silent) _loadFunc;

  Future<DataType> readValue() async {
    if (value.status == ReactiveAsyncStatus.data || value.status == ReactiveAsyncStatus.done) return value.data!;
    
    // ignore: unnecessary_new
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
  
  AsyncReactive(AsyncReactiveSource<DataType> source, { DataType? initialValue, bool autoExecute = true, bool silentLoading = false, String? debugName }) : _asyncSource = source, _autoExecute = autoExecute, _silentLoading = silentLoading, super(initialValue != null ? ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.data, data: initialValue) : ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.notStarted), debugName: debugName) {
    _internalSource = (currentValue, watch, read) {
      _loadFunc = (silent) {

        //Start loading
        if (!silent) _internalSet(ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.loading));

        //Create the future
        _asyncSource(currentValue?.data, watch, read)
          .then((value) {
            //On completion, send a data update
            _internalSet(ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.data, data: value));
          })
          .catchError((error, stacktrace) {
            //On error, send an error update
            _internalSet(ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.error, error: error.toString()));
          });
      };

      //If it's set up to autoexecute, we should just call the load function right away
      if (_autoExecute) {
        _debugLog('Autoexecuting');
        _loadFunc(_silentLoading);
        return ReactiveAsyncUpdate<DataType>(status: ReactiveAsyncStatus.loading);
      }

      //We're not doing any mutating here
      return currentValue!;
    };
    
    _watcherManager = WatcherManager((referrer) {
      assert(_internalSource != null);
      final watcher = _watcherManager!.createWatcher(referrer);
      _internalSource!(value, watcher, Reactive.reader);
    }, reactiveDebugName: debugName);

    _value = _internalSource!(_value, _watcherManager!.createWatcher(null), Reactive.reader);
    _prevValue = _value;
  }

  @override
  void refresh() {
    if (_internalSource != null) {
      final watcher = _watcherManager!.createWatcher((index: -1, referrerType: WatcherReferrerType.reactive));
      _internalSource!(value, watcher, Reactive.reader);
    }
  }

  @override
  Future<void> perform<TransactionDataType>(ReactiveTransaction<TransactionDataType> transaction, { bool silent = true }) async {
    assert(TransactionDataType == DataType, 'Reactive<$DataType> can only perform transactions of type ReactiveTransaction<$DataType>');

    _debugLog('Performing transaction ${transaction.name}');

    DataType? result;

    try {

      //First, let's execute the transaction
      final currentValue = await readValue();
      final potentialFuture = transaction.execute(currentValue as TransactionDataType);
      if (potentialFuture is Future) {
        //Mark the reactive as loading
        if (!silent) _internalSet(ReactiveAsyncUpdate(status: ReactiveAsyncStatus.loading));
        
        result = await potentialFuture as DataType?;
      }
      else {
        result = potentialFuture as DataType?;
      }

      //Notify the supervisor if available
      if (_observer != null) {
        _observer!.receiveTransaction(transaction, result, this);
      }
      
      //Next, notify the listeners
      if (result != null) {
        _internalSet( ReactiveAsyncUpdate( 
          status: ReactiveAsyncStatus.data, data: result
        ) );
      } else if (!silent) {
        _internalSet( ReactiveAsyncUpdate(
          status: ReactiveAsyncStatus.data,
          data: currentValue
        ) );
      }

    } on Exception catch(error) {
      _internalSet(ReactiveAsyncUpdate(status: ReactiveAsyncStatus.error, error: error.toString()));
    }
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
      ReactiveAsyncStatus.data when this.data != null => data(this.data as DataType),
      ReactiveAsyncStatus.done when this.data != null => data(this.data as DataType),
      _ => throw const ReactiveException('`data` or `done` status sent without data')
    };

  }

  @override
  String toString() {
    if (error != null) return '$runtimeType -> Error: $error';
    if (status == ReactiveAsyncStatus.loading) return '$runtimeType (loading)';
    return '$runtimeType -> $data ';
  }
}