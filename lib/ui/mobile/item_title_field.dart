import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// La tastiera apre dopo l'ingresso del foglio, evitando due animazioni e un
/// ridimensionamento del contenuto nello stesso momento.
class ItemTitleField extends StatefulWidget {
  const ItemTitleField({
    super.key,
    required this.controller,
    required this.autofocus,
  });

  final TextEditingController controller;
  final bool autofocus;

  @override
  State<ItemTitleField> createState() => _ItemTitleFieldState();
}

class _ItemTitleFieldState extends State<ItemTitleField> {
  final _focus = FocusNode(debugLabel: 'Titolo');
  ModalRoute<dynamic>? _route;
  Animation<double>? _opening;
  bool _handled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handled || !widget.autofocus) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _stopListening();
      _handled = true;
      return;
    }
    final animation = route?.animation;
    if (animation == null || animation.isCompleted) {
      _requestOnce();
    } else if (_opening != animation) {
      _stopListening();
      _route = route;
      _opening = animation..addStatusListener(_onStatus);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _requestOnce();
    if (status == AnimationStatus.reverse) {
      _handled = true;
      _stopListening();
    }
  }

  void _requestOnce() {
    final route = _route ?? ModalRoute.of(context);
    _handled = true;
    _stopListening();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.autofocus || route?.isCurrent == false) return;
      if (FocusScope.of(context).focusedChild == null) _focus.requestFocus();
    });
  }

  void _stopListening() {
    _opening?.removeStatusListener(_onStatus);
    _opening = null;
    _route = null;
  }

  @override
  void dispose() {
    _stopListening();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      textCapitalization: TextCapitalization.sentences,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
      decoration: const InputDecoration(
        hintText: 'Titolo',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.s),
      ),
    );
  }
}
