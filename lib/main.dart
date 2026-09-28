import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

// ==========================================
// 1. ТОЧКА ВХОДА (Main)
// ==========================================
void main() async {
  // Инициализация Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Hive
  await Hive.initFlutter();
  // Открываем "ящик" с задачами перед запуском приложения
  await Hive.openBox('todos');

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Планировщик дел',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TodoListScreen(),
    );
  }
}

// ==========================================
// 2. ИНТЕРФЕЙС (UI)
// ==========================================
class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Следим за состоянием списка задач
    final todos = ref.watch(todosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои дела'),
        centerTitle: true,
      ),
      body: todos.isEmpty
          ? const Center(
              child: Text(
                'Пока нет задач.\nНажмите + чтобы добавить!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Checkbox(
                      value: todo.isDone,
                      onChanged: (_) {
                        ref.read(todosProvider.notifier).toggle(todo.id);
                      },
                    ),
                    title: Text(
                      todo.title,
                      style: TextStyle(
                        decoration: todo.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: todo.isDone ? Colors.grey : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(todo.createdAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        ref.read(todosProvider.notifier).delete(todo.id);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Диалоговое окно для добавления задачи
  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая задача'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Что нужно сделать?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(todosProvider.notifier).add(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. МОДЕЛЬ ДАННЫХ (Todo)
// ==========================================
class Todo {
  final String id;
  final String title;
  final bool isDone;
  final DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    this.isDone = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'],
        title: j['title'],
        isDone: j['isDone'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt']),
      );
}

// ==========================================
// 4. СОСТОЯНИЕ (Riverpod + Hive)
// ==========================================
final _uuid = const Uuid();

final todosProvider =
    StateNotifierProvider<TodoNotifier, List<Todo>>((ref) => TodoNotifier());

class TodoNotifier extends StateNotifier<List<Todo>> {
  final _box = Hive.box('todos');

  // Конструктор: инициализируем пустой список, затем загружаем данные
  TodoNotifier() : super([]) {
    state = _load();
    _box.listenable().addListener(() => state = _load());
  }

  // Метод _load() больше не static, чтобы иметь доступ к _box
  List<Todo> _load() {
    return _box.keys
        .map((k) => Todo.fromJson(Map<String, dynamic>.from(_box.get(k))))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Новые задачи сверху
  }

  void add(String title) {
    final t = Todo(id: _uuid.v4(), title: title.trim());
    _box.put(t.id, t.toJson());
  }

  void toggle(String id) {
    final d = Map<String, dynamic>.from(_box.get(id));
    d['isDone'] = !d['isDone'];
    _box.put(id, d);
  }

  void delete(String id) {
    _box.delete(id);
  }
}