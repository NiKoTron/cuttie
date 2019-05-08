abstract class Repository<T> {
  Future<T> getByName(String name);

  Future<Iterable<T>> getAll({bool forceUpdate});

  void add(T item);
  void delete(T item);
}
