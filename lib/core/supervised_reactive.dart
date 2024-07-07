import 'dart:async';
import 'package:rctv/core/reactive.dart';
import 'package:rctv/core/reactive_supervisor.dart';



class ReactiveTransaction<DataType> {

  final String name;
  final FutureOr<DataType> Function(DataType currentValue) runner;

  ReactiveTransaction({ required this.name, required this.runner });

  FutureOr<DataType> execute(DataType currentValue) {
    return runner(currentValue);
  }
  
}

abstract class SupervisedReactive<DataType> implements ReactiveBase<DataType> {

  final String name;
  final Reactive<DataType> _reactive;

  ReactiveSupervisor? _supervisor;

  SupervisedReactive(this.name, { required DataType initialValue }) :
    _reactive = Reactive(initialValue);
  
  @override
  DataType read() => _reactive.read();

  @override
  ReactiveSubscription watch(ReactiveListener<DataType> listener) {
    return _reactive.watch(listener);
  }

  void setSupervisor(ReactiveSupervisor supervisor) {
    _supervisor = supervisor;
    supervisor.register(this);
  }

  

  Future<void> perform(ReactiveTransaction transaction) async {

      DataType result;

      //First, let's execute the transaction
      final potentialFuture = transaction.execute(_reactive.read());
      if (potentialFuture is Future) {
        result = await potentialFuture;
      }
      else {
        result = potentialFuture as DataType;
      }

      //Notify the supervisor if available
      if (_supervisor != null) {
        _supervisor!.receiveTransaction(transaction, result);
      }
      
      //Next, notify the listeners
      _reactive.set(result);

  }

  void removeSupervisor() {
    _supervisor?.unregister(this);
    _supervisor = null;
  }

  @override
  void dispose() {
    _supervisor?.unregister(this);
    _reactive.dispose();
  }

}

//Utility method
ReactiveTransaction<DataType> rctvTransaction<DataType>(String transactionName, FutureOr<DataType> Function(DataType currentValue) runner) {
  return ReactiveTransaction(name: transactionName, runner: runner);
}