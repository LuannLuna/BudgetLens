# BudgetLens

BudgetLens is a small SwiftUI app (iOS 17+) for inspecting a **synthetic, bundled budget snapshot** and discussing it with an LLM. It supports OpenAI, Anthropic, Gemini, DeepSeek, and other OpenAI-compatible endpoints. Each assistant has its own Keychain key. The app does not connect to a bank or fetch budget data over the network.

## Run it

1. Open `BudgetLens.xcworkspace` in Xcode 27, choose the **BudgetLens** scheme and a simulator, then run it. There are no packages or secrets to set up, and the repository contains no API keys.
2. On first launch, choose an assistant and paste **your own API key**. It is stored in the device-only Keychain. Every question is a paid call to the selected provider. Settings lets you replace or clear keys, add an OpenAI-compatible assistant, and switch the active assistant.
3. Run tests with **Product → Test**. They do not need a key or network access.

| Assistant | API | Default model |
| --- | --- | --- |
| OpenAI | Responses | `gpt-4.1-mini` |
| Anthropic | Messages | `claude-haiku-5-5` |
| Gemini | generateContent | `gemini-3.8-flash` |
| DeepSeek | OpenAI-compatible chat | `deepseek-flash` |
| Custom | OpenAI-compatible chat with your `https://` URL | your model |

Supporting several adapters lets a reviewer use a key they already have, at the cost of maintaining more than one provider integration.

## Architecture decisions

A thin `BudgetLens` target and one Swift package, `BudgetLensFeature`, have dependencies flowing in one direction:

| Layer | Responsibility | May depend on |
| --- | --- | --- |
| Core | Formatting, Markdown rendering, and `Provider` | Nothing |
| Services | Keychain, HTTP adapters, preferences, and error reporting | Core |
| Domains | Budget data, LLM context, conversation, and app errors | Core, Services |
| Features | SwiftUI screens and small `@MainActor @Observable` state | Core, Domains |
| App | `BudgetLensEntryView`, which composes dependencies | All layers |

Views only know about the conversation use case; HTTP, Keychain, and provider details stay behind it. This keeps error handling consistent, allows in-memory stores in tests, and lets me add a provider without changing a screen. Provider failures become user-facing states—invalid key, network issue, rejected request, unavailable provider, or unusable reply—with a recovery action.

Non-streaming requests have a 30-second limit and use system SwiftUI components. If the app grows, splitting the layers into package targets would let the compiler enforce import boundaries.

Unit tests use Swift Testing, in-memory stores, and a test `URLProtocol`; they need no network, key, or Keychain entitlement. XCUITests cover real Keychain flows, including a DEBUG-only forced provider failure for error screens.

## Deliberate scope choices

- No account sign-in, transactions, backend, streaming, or persisted chat history. Conversations live in memory only.
- Model and reasoning-effort selection are not implemented. A custom assistant is replaced by deleting and recreating it.
- Live-provider tests would require secrets and paid calls. Default model IDs are not verified with a real key; a retired model should surface “request rejected” with a Settings shortcut.
- Keychain coverage belongs to UI tests because the package test runner has no entitlement.
- Two known limitations: after replacing a key, the earlier error remains until the next question, and an unreadable custom-assistant list is reported but not displayed.

With more time, I would validate the default models with a real key, let people choose a model and reasoning effort per assistant, and move import boundaries into `Package.swift` so a view could not use a Services type by accident.

## LLM context and privacy

The model receives the July 2026 snapshot, not a current balance. The JSON does not name a currency, so the UI adds no symbol and the model is explicitly told it is unknown. The snapshot is fictional: category balances—especially Rainy-day reserve—are not available cash, and unallocated and unbudgeted amounts are reported separately rather than reconciled with the totals.

Each request includes only the period, totals, category values and statuses, the current question, and at most six recent messages. It excludes category IDs, icons, account and device data. The key is only a request credential. The composer names the provider, chat remains in memory, and diagnostics never contain the key, question, or raw snapshot. OpenAI requests use `store: false`, although that is not a zero-retention guarantee.

The assistant should be calm, clear, and honest about what the data can—and cannot—show. It should state uncertainty and avoid invented transactions, forecasts, and prescriptive advice. Before shipping, I would read each provider's replies to anxious-user prompts and check whether a question can be answered with fewer categories.

## Product trade-off to revisit

Using the customer's own key was the quickest way to build a useful demo, but it should not automatically be the product default. For real budget data, the app would own the provider relationship through a backend: a consistent consent flow, no customer-managed API keys, and prompt behaviour in one place.

That backend would also own another sensitive system and its operating cost. Its retention terms and the value of the non-AI budget view would need to be discussed before choosing that boundary.
