# BudgetLens — iOS project

A small SwiftUI app (iOS 17+) for looking at a **historical, local** budget snapshot and talking about it with an LLM. It supports OpenAI, Anthropic, Gemini, DeepSeek, and other OpenAI-compatible endpoints. Each assistant has its own Keychain key. The app does not connect to a bank or fetch budget data over the network.

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

The brief asks for one provider. I included several so a reviewer can use a key they already have. The trade-off is maintaining four adapters instead of one.

## 1. Architecture decisions

I kept a thin `BudgetLens` target and one Swift package, `BudgetLensFeature`. Dependencies flow in one direction only:

| Layer | Responsibility | May depend on |
| --- | --- | --- |
| Core | formatting, Markdown rendering, and `Provider` | nothing |
| Services | Keychain, HTTP adapters, preferences, and error reporting | Core |
| Domains | budget data, LLM context, conversation, and app errors | Core, Services |
| Features | SwiftUI screens and small `@MainActor @Observable` state | Core, Domains |
| App | `BudgetLensEntryView`, which composes the dependencies | all layers |

Views only know about the conversation use case; HTTP, Keychain, and provider details stay behind it. That keeps error handling consistent, lets tests use in-memory stores, and means I can add a provider without changing a screen. Provider failures become a small set of user-facing states—invalid key, network issue, rejected request, unavailable provider, or unusable reply—with a clear recovery action.

I used non-streaming requests with a 30-second limit and system SwiftUI components because that is enough for this brief. If the app grew, I would split the layers into package targets so the compiler could enforce the import boundaries.

Unit tests use Swift Testing, in-memory stores, and a test `URLProtocol`; they need no network, key, or Keychain entitlement. XCUITests cover real Keychain flows, including a DEBUG-only forced provider failure for the error screens.

## 2. What I left out

These are deliberate scope choices for a 48-hour window:

- Plaid, account sign-in, transactions, and a backend.
- Streaming and persisted chat history. The conversation only lives in memory.
- Selecting a model per provider and editing a custom assistant; to edit one today, a person removes it and creates it again.
- Tests against live providers. They would need secrets and paid calls. The default model IDs are therefore still unverified with a real key; if one has been retired, the person sees “request rejected” with a Settings shortcut.
- Keychain coverage in unit tests, because the package test runner has no entitlement. That flow is covered by UI tests.
- Two known limits: after replacing a key, the earlier error stays on screen until the next question; and an unreadable custom-assistant list is reported but not displayed.

With more time, I would do two things first:

- Validate the default models with a real key and let people choose a model and reasoning effort per assistant.
- Turn the layers into package targets. The allowed imports would then live in `Package.swift`, and a view could not use a Services type by accident. The trade-off is making every cross-layer type `public`.

AI coding assistants helped build this project. The rules they followed are in [`AGENTS.md`](AGENTS.md); `CLAUDE.md`, `.cursor/rules`, and `.github/copilot-instructions.md` point to it.

## 3. How I handled LLM context

The model gets a May 2025 snapshot, not a current balance. The JSON does not name a currency, so the UI adds no symbol and the model is told it is unknown. I also make two ambiguities explicit: category balances—especially Savings—are not available cash, and the totals do not reconcile (`unallocatedBudgetCents` is 412.00 and `unbudgetedSpentCents` is 185.00).

Each request includes only the period, totals, category values and statuses, the current question, and at most six recent messages. It excludes category IDs, icons, account and device data; the key is only a request credential. The composer names the provider, chat remains in memory, and diagnostics never contain the key, question, or raw financial snapshot. OpenAI requests use `store: false`, although that is not a zero-retention guarantee.

The assistant should be calm, clear, and honest about what the data can—and cannot—show. It should state uncertainty and avoid invented transactions, forecasts, and prescriptive advice. Before shipping, I would read each provider's replies to anxious-user prompts and check whether a question can be answered with fewer categories.

## 4. A conversation I would like to have

Using the customer's own key was the quickest way to meet the brief, but I would not assume it is right for the product. For real budget data, I would expect BudgetLens to own the provider relationship through a backend: it could offer a consistent consent flow, avoid asking customers to manage API keys, and keep the prompt behaviour in one place.

The trade-off is that BudgetLens then owns another sensitive system and its operating cost. I would want to discuss that boundary, the provider's retention terms, and how the budget view stays useful when someone does not use AI.
