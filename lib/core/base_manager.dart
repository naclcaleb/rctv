abstract class Manageable<T extends Manageable<T>> {
  String get id;
  void update(T newVersion);
}

abstract class SynchronousManagerBase<Item extends Manageable<Item>, OutputType> {
  final Map<String, OutputType> itemCache = {};

  OutputType convertType(Item item);
  void updateItem(Item newItem);

  OutputType get(String id, { bool? forceRefresh }) {
    if ((forceRefresh == null || forceRefresh == false) && itemCache.containsKey(id)) {
      return itemCache[id]!;
    } else {
      Item item = fetchItem(id);
      final outputItem = save(item);
      return outputItem;
    }
  }

  OutputType save(Item item) {
    if (itemCache.containsKey(item.id)){ updateItem(item); }
    else { itemCache[item.id] = convertType(item); }
    return itemCache[item.id]!;
  }

  List<OutputType> saveAll(List<Item> items) {
    List<OutputType> returnedItems = [];
    for (var item in items) {
      returnedItems.add( save(item) );
    }
    return returnedItems;
  }

  Item fetchItem(String id) { throw UnimplementedError(); }

  List<OutputType> getAll(List<String> itemIds) {
    final items = <OutputType>[];
    for (final itemId in itemIds) { items.add(get(itemId)); }
    return items;
  }
}

abstract class ManagerBase<Item extends Manageable<Item>, OutputType> {
  final Map<String, OutputType> itemCache = {};

  OutputType convertType(Item item);
  void updateItem(Item newItem);

  Future<OutputType> get(String id, { bool? forceRefresh }) async {
    if ((forceRefresh == null || forceRefresh == false) && itemCache.containsKey(id)) {
      return itemCache[id]!;
    } else {
      Item item = await fetchItem(id);
      final outputItem = save(item);
      return outputItem;
    }
  }

  OutputType save(Item item) {
    if (itemCache.containsKey(item.id)){ updateItem(item); }
    else { itemCache[item.id] = convertType(item); }
    return itemCache[item.id]!;
  }

  List<OutputType> saveAll(List<Item> items) {
    List<OutputType> returnedItems = [];
    for (var item in items) {
      returnedItems.add( save(item) );
    }
    return returnedItems;
  }

  Future<Item> fetchItem(String id) async { throw UnimplementedError(); }

  Future<List<OutputType>> getAll(List<Item> items) async {
    final itemFutures = <Future<OutputType>>[];
    for (final item in items) { itemFutures.add(get(item.id)); }
    return Future.wait(itemFutures);
  }
}