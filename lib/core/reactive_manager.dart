part of rctv;

class ReactiveManager<Item extends Manageable<Item>> extends ManagerBase<Item, Reactive<Item>> {
  @override
  Reactive<Item> convertType(Item item) => Reactive(item);

  @override
  void updateItem(Item newItem) {
    itemCache[newItem.id]?._internalSet(newItem);
  }

  void dispose() {

    for (final item in itemCache.keys) {
      itemCache[item]?.dispose();
      itemCache.remove(item);
    }

  }
}