import 'package:flutter/widgets.dart';

/// Rebuilds validation and route dismissal guards for every text edit, including
/// controller changes that do not invoke a text field's onChanged callback.
class EditorStateBuilder extends StatefulWidget {
  const EditorStateBuilder({
    super.key,
    required this.textControllers,
    required this.builder,
  });

  final List<TextEditingController> textControllers;
  final StatefulWidgetBuilder builder;

  @override
  State<EditorStateBuilder> createState() => _EditorStateBuilderState();
}

class _EditorStateBuilderState extends State<EditorStateBuilder> {
  @override
  void initState() {
    super.initState();
    for (final controller in widget.textControllers) {
      controller.addListener(_textChanged);
    }
  }

  @override
  void didUpdateWidget(EditorStateBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final controller in oldWidget.textControllers) {
      controller.removeListener(_textChanged);
    }
    for (final controller in widget.textControllers) {
      controller.addListener(_textChanged);
    }
  }

  void _textChanged() => setState(() {});

  @override
  void dispose() {
    for (final controller in widget.textControllers) {
      controller.removeListener(_textChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, setState);
}
