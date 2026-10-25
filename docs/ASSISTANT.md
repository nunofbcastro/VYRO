# On-device assistant

The assistant answers nutrition and training questions with the **language model built into the operating system**. The app ships no model, uses no API key and does no cloud inference.

| Platform | Model | Requirements | Code |
| --- | --- | --- | --- |
| iOS | Apple Intelligence (Foundation Models framework) | iOS 26+, an iPhone that supports Apple Intelligence, with it turned on | `ios/Runner/AppDelegate.swift` (`OnDeviceLlm`) |
| Android | Gemini Nano via ML Kit GenAI Prompt API / AICore (`com.google.mlkit:genai-prompt`) | Android 8+ (minSdk 26), a device with AICore support, locked bootloader | `android/.../llm/OnDeviceLlmChannel.kt` |
| Web / desktop / other phones | none | n/a | Shows the "unavailable" card |

Dart talks to both platforms through one channel, `vyro/on_device_llm`, using three methods: `status`, `download` and `generate`. The wrapper is `lib/core/ai/on_device_llm.dart`.

## Behaviour
- **Status:** `available`, `downloadable` (Android can fetch Gemini Nano; the system manages the download), `downloading`, or `unavailable`.
- **Grounding:** each question is sent with a short context built from local data only: goal, daily targets, today's calories, protein and foods, the plan, the next workout and its exercises, and this week's progress. See `buildAssistantPrompt`.
- **Safety rules in the prompt:** brief answers in the app language; no diagnosis or medical advice (pain, injury, pregnancy, illness and medication are sent to a professional); no invented nutrient values; plan changes only as small suggestions on top of the rule-based plan.
- **Privacy:** the conversation is kept in memory only. It is not stored or sent anywhere. Leaving the screen clears it.
- The screen is labelled **Experimental**, and every answer shows a disclaimer.

## Entry points
- The ✨ button at the top of Início.
- Perfil → Assistente.

## Limits
- Answers come from a small on-device model and can be wrong; the UI says so.
- Only devices that support it get answers; everyone else sees what is needed and nothing else changes.
- Single-turn generation (no streaming yet). The last 6 turns are included as context.
