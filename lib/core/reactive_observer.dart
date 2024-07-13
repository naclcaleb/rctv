part of rctv;

class ReactiveObserver {

  final String? name;
  final Map<Reactive, String?> _reactives = {};
  final void Function<ResultType>(ReactiveTransaction<ResultType> transaction, ResultType? result, String? reactiveName) onTransaction;

  ReactiveObserver({ required this.onTransaction, this.name });

  void register(Reactive reactive) {
    assert(reactive.isObserved());

    //Get the name
    final rName = reactive._name;

    if (_reactives.containsKey(reactive)) {
      throw ReactiveException('ReactiveObserver${name != null ? " ($name)":""}: Reactive ${rName != null ? '"$rName"':''} has already been registered.\n\nYou may have already used this name in another reactive, or forgotten to dispose the reactive appropriately.');
    }

    _reactives[reactive] = rName;
    reactive._setObserver(this);
  }

  void unregister(Reactive reactive) {
    _reactives.remove(reactive);
  }

  void receiveTransaction<ResultType>(ReactiveTransaction<ResultType> transaction, ResultType? result, Reactive reactive) {
    //Just a wrapper in case we want to edit the logic later
    onTransaction(transaction, result, _reactives[reactive]);
  }

}