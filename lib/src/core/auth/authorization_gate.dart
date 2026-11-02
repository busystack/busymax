import 'dart:async';
import 'dart:collection';

/// FIFO readers/writers. Adjacent readers overlap; a queued writer prevents
/// later readers from starving it. The native gate supplies engine isolation.
final class AuthorizationGate {
  final _queues = <String, _Queue>{};

  Future<T> run<T>(
    String id,
    Future<T> Function() work, {
    bool shared = false,
  }) async {
    final queue = _queues.putIfAbsent(id, _Queue.new);
    final entry = _Entry(shared);
    queue.waiting.add(entry);
    queue.pump();
    await entry.ready.future;
    try {
      return await work();
    } finally {
      queue.active--;
      if (!shared) queue.writer = false;
      queue.pump();
      if (queue.active == 0 && queue.waiting.isEmpty) _queues.remove(id);
    }
  }
}

final class _Entry {
  _Entry(this.shared);
  final bool shared;
  final ready = Completer<void>();
}

final class _Queue {
  final waiting = Queue<_Entry>();
  int active = 0;
  bool writer = false;
  void pump() {
    while (!writer && waiting.isNotEmpty) {
      final next = waiting.first;
      if (!next.shared && active != 0) return;
      waiting.removeFirst();
      active++;
      writer = !next.shared;
      next.ready.complete();
    }
  }
}
