import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/work_service.dart';

final workServiceProvider = Provider<WorkService>((ref) => WorkService());

/// The signed-in official's own field workers.
final myWorkersProvider = FutureProvider.autoDispose<List<WorkerInfo>>(
  (ref) => ref.watch(workServiceProvider).myWorkers(),
);

/// A field worker's assigned tickets.
final workerTasksProvider = FutureProvider.autoDispose<List<WorkerTask>>(
  (ref) => ref.watch(workServiceProvider).myTasks(),
);
