import 'package:rctv/core/supervised_reactive.dart';

abstract class ReactiveSupervisor {

  final String? name;
  final Map<String, SupervisedReactive> _reactives = {};

  ReactiveSupervisor([this.name]);

  void register(SupervisedReactive reactive) {
    //Get the name
    final rName = reactive.name;

    if (_reactives.containsKey(rName)) {
      throw Exception('ReactiveSupervisor${name != null ? " ($name)":""}: SupervisedReactive "$rName" has already been registered.\n\nYou may have already used this name in another reactive, or forgotten to dispose the reactive appropriately.');
    }

    _reactives[rName] = reactive;
  }

  void unregister(SupervisedReactive reactive) {
    _reactives.remove(reactive.name);
  }

  void onTransaction<ResultType>(ReactiveTransaction<ResultType> transaction, ResultType? result);

  void receiveTransaction<ResultType>(ReactiveTransaction<ResultType> transaction, ResultType? result) {
    //Just a wrapper in case we want to edit the logic later
    onTransaction(transaction, result);
  }

}