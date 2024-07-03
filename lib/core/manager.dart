import 'base_manager.dart';

class Manager<Item extends Manageable<Item>> extends ManagerBase<Item, Item> {
  @override
  Item convertType(Item item) => item;

  @override
  void updateItem(Item newItem) {
    itemCache[newItem.id]?.update(newItem);
  }
}