import 'package:flutter_riverpod/flutter_riverpod.dart';

final allTasksModeProvider = StateProvider<bool>((ref) => true);
final selectedTaskListIdProvider = StateProvider<String?>((ref) => null);
final selectedTaskIdProvider = StateProvider<String?>((ref) => null);
