import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/settings/app_settings_controller.dart';
import '../../theme/design_tokens.dart';

/// Le animazioni sono accese?
///
/// Due modi di dire la stessa cosa: l'interruttore nelle preferenze e il
/// «riduci animazioni» di sistema. Vince il più sobrio — se il sistema chiede
/// meno movimento, non è l'app a dover insistere.
bool animationsOn(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return false;
  return context.select<AppSettingsController?, bool>(
    (settings) => settings?.animationsEnabled ?? true,
  );
}

bool animationsEnabledForRoute(BuildContext context) =>
    !MediaQuery.disableAnimationsOf(context) &&
    (context.read<AppSettingsController?>()?.animationsEnabled ?? true);

const _overlayMotion = AnimationStyle(
  duration: AppMotion.sheetEntrance,
  reverseDuration: AppMotion.sheetExit,
  curve: AppMotion.controlCurve,
  reverseCurve: Curves.easeInOutCubic,
);

const _menuMotion = AnimationStyle(
  duration: AppMotion.menuEntrance,
  reverseDuration: AppMotion.menuExit,
  curve: AppMotion.controlCurve,
);

AnimationStyle menuMotion(BuildContext context) =>
    animationsOn(context) ? _menuMotion : AnimationStyle.noAnimation;

Future<T?> showActaDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) =>
    showDialog<T>(
      context: context,
      builder: builder,
      animationStyle: animationsEnabledForRoute(context)
          ? _menuMotion
          : AnimationStyle.noAnimation,
    );

Future<T?> showActaSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  AnimationStyle? animationStyle,
}) =>
    showModalBottomSheet<T>(
      context: context,
      builder: builder,
      constraints: constraints,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      sheetAnimationStyle: animationsEnabledForRoute(context)
          ? animationStyle ?? _overlayMotion
          : AnimationStyle.noAnimation,
    );
