import 'base_manager.dart';
import 'reactive.dart';

class ReactiveManager<Item extends Manageable<Item>> extends ManagerBase<Item, Reactive<Item>> {
  @override
  Reactive<Item> convertType(Item item) => Reactive(item);

  @override
  void updateItem(Item newItem) {
    itemCache[newItem.id]?.set(newItem);
  }
}