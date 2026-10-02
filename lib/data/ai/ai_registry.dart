import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/providers/chatgpt_provider.dart';
import 'package:nts/data/ai/providers/claude_code_provider.dart';
import 'package:nts/data/ai/providers/google_provider.dart';
import 'package:nts/data/prefs.dart';

/// The AI accounts. Each checks its sign-in status when first used.
abstract final class AiRegistry {
  static final chatgpt = ChatGptProvider(stows.aiChatgptTokens)
    ..refreshStatus();
  static final claude = ClaudeCodeProvider()..refreshStatus();
  static final google = GoogleProvider(
    stows.aiGoogleTokens,
    clientId: stows.aiGoogleClientId,
    projectId: stows.aiGoogleProjectId,
  )..refreshStatus();

  static final List<AiProvider> all = [chatgpt, claude, google];

  /// Creates the accounts, which starts checking their sign-in, e.g.
  /// running `claude auth status` (~0.2 s): call at app start.
  static void checkEarly() => all;

  static AiProvider byId(AiProviderId id) => switch (id) {
    .chatgpt => chatgpt,
    .claude => claude,
    .google => google,
  };
}
