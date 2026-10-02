import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/is_this_a_test.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/i18n/strings.g.dart';

/// The editor's back button, which also shows the state of saving:
/// back when saved, save (tap to save now) when there are unsaved changes,
/// and a spinner while saving.
class SaveIndicator extends StatelessWidget {
  const new({super.key, required this.savingState, required this.triggerSave});

  final ValueNotifier<SavingState> savingState;
  final VoidCallback triggerSave;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return ValueListenableBuilder(
      valueListenable: savingState,
      builder: (context, state, _) {
        final Widget icon = switch (state) {
          .waitingToSave => Icon(
            Symbols.save,
            size: 17,
            weight: 300,
            color: c.text,
          ),
          .saving => SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: c.textSecondary,
            ),
          ),
          .saved => Icon(
            Symbols.arrow_back_ios_new,
            size: 16,
            weight: 300,
            color: c.text,
          ),
        };
        return Tooltip(
          message: switch (state) {
            .waitingToSave => MaterialLocalizations.of(context).saveButtonLabel,
            .saving => t.higan.saving,
            .saved => t.higan.back,
          },
          child: HiganTapTarget(
            onTap: () => _onPressed(context),
            child: HiganFocusRing(
              shape: const CircleBorder(),
              child: Material(
                type: .transparency,
                shape: const CircleBorder(),
                clipBehavior: .antiAlias,
                child: InkWell(
                  onTap: () => _onPressed(context),
                  child: SizedBox.square(
                    dimension: size,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: isThisATest
                            ? Duration.zero
                            : HiganMotion.fast,
                        child: KeyedSubtree(key: ValueKey(state), child: icon),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onPressed(BuildContext context) {
    switch (savingState.value) {
      case .waitingToSave:
        triggerSave();
      case .saving:
        break;
      case .saved:
        _back(context);
    }
  }

  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    final isWhiteboard = !navigator.canPop();
    if (isWhiteboard) {
      // if on whiteboard, go to "recents" tab of home screen
      context.go(HomeRoutes.routes[0].path);
    } else {
      navigator.pop();
    }
  }
}

enum SavingState { waitingToSave, saving, saved }
