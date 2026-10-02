# nts Privacy Policy

nts is a handwriting notes app for Mac and iPad. This policy explains what data nts uses and where it goes.

This policy may change. The latest version and its history are in the nts repository: https://github.com/mehmetbisen17/nts

## The short version

- Your notes stay on your device and in your own iCloud Drive.
- nts has no server and no nts account.
- nts has no analytics, crash reporting, ads or tracking.
- AI features send data only when you tap an AI action, and only to the AI provider you signed into.

## Your notes and settings

nts saves your notes in the folder you choose. If you pick a folder in iCloud Drive, Apple's iCloud Drive syncs it between your devices under [Apple's privacy policy](https://www.apple.com/legal/privacy/). If you don't pick one, your notes stay in nts's own folder on the device.

Your settings are stored on the device. Sign-in tokens for AI accounts are stored in the device's Keychain.

Handwriting to text runs on the device, with Apple's Vision framework. Nothing is sent anywhere to read your handwriting.

The app's logs stay on the device. They are never uploaded.

## AI features

AI features are optional and only work after you sign in to an AI account in Settings › AI accounts.

When you circle part of a note and tap an AI action, nts sends:

- a picture of the part you circled,
- any typed text (text boxes) inside the circle, and, if you corrected what the AI read, your correction, and
- the action you chose, such as "Explain in a paragraph".

This goes only to the provider you are signed into, and only for that request. nts sends nothing in the background.

| Provider | How nts connects | Whose policy applies |
| --- | --- | --- |
| **ChatGPT** | You sign in with your ChatGPT account. nts sends requests to OpenAI with your account's token. | [OpenAI](https://openai.com/policies/privacy-policy/) |
| **Claude** (Mac only) | nts asks the Claude Code program on your Mac, which you sign in to yourself. nts never sees or stores your Claude credentials. | [Anthropic](https://www.anthropic.com/legal/privacy) |
| **Google** | You sign in with your Google account through your own Google Cloud project. nts uses Gemini, and YouTube search for "Find a video". | [Google](https://policies.google.com/privacy) |

The provider handles your request under its own terms and privacy policy and the settings of your account with it. AI answers can be wrong.

When you open a video or web page that an AI action found, it opens in Safari, your browser or the YouTube app, outside nts.

## Deleting your data

- **Notes:** delete them in nts, or delete the folder you chose in iCloud Drive. Uninstalling nts on iPad removes the notes kept in nts's own folder. On a Mac, also delete the `nts` folder in `~/Library/Application Support/com.mehmetbisen.nts`.
- **AI accounts:** sign out in Settings › AI accounts. This removes the tokens from the Keychain. You can also remove nts's access in your Google, OpenAI or Claude account settings.
- **Data held by AI providers:** ask the provider. nts keeps no copy of your requests.

## Source code

nts is open source under the [GNU General Public License v3.0](LICENSE.md), so anyone can check exactly what it does with your data: https://github.com/mehmetbisen17/nts

## Contact

Questions about privacy? Open an issue in the nts repository: https://github.com/mehmetbisen17/nts/issues
