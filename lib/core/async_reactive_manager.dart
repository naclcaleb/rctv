part of rctv;

class AsyncReactiveManager<Item extends Manageable<Item>> extends SynchronousManagerBase<Item, AsyncReactive<Item>> {
  
  @override
  AsyncReactive<Item> convertType(Item item) {
    return AsyncReactive((currentValue, watch, _) async {
      return currentValue!;
    }, initialValue: item);
  }

  @override
  void updateItem(Item newItem) {
    itemCache[newItem.id]?._internalSet(ReactiveAsyncUpdate(status: ReactiveAsyncStatus.data, data: newItem));
  }

  void dispose() {

    for (final item in itemCache.keys) {
      itemCache[item]?.dispose();
      itemCache.remove(item);
    }

  }
}