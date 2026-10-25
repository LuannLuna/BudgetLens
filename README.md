# BudgetLens — iOS project

A small SwiftUI app for exploring a **historical, local budget snapshot** and asking supportive questions about it. It targets iOS 17+ and supports **multiple LLM providers** (OpenAI, Anthropic, Gemini, DeepSeek, plus custom OpenAI-compatible endpoints), each with its own Keychain-stored key. The app does not connect to a bank or fetch budget data.

## Run it

1. Open `BudgetLens.xcworkspace` in Xcode 27, select the **BudgetLens** scheme and an iOS simulator, then Run. There are no third-party packages or setup secrets.
2. On first launch, choose an **assistant** — including **Custom assistant…** for any OpenAI-compatible endpoint — and enter your own API key for it. Keys are saved to the device-only Keychain; a nonempty key for the active assistant unlocks the local dashboard, but validity is determined only when that provider answers the first request. Sending a question makes a paid API call using the active assistant's key.
3. Read the **Budget** tab first, then use **Ask** to discuss the sample. The Ask header switches the active assistant (the conversation is kept when the new assistant already has a key; choosing one without a key opens key entry and the chat starts fresh once it is connected). **Settings** manages each assistant's key (add/replace/clear) and custom assistants. Clearing the active key falls back to another configured assistant, or back to key entry if none remain; key changes end the in-memory chat.

The supplied `BudgetLensSampleJSON.json` lives at `BudgetLensPackage/Sources/BudgetLensFeature/Resources/BudgetLensSampleJSON.json`, where the bundled loader reads it. There is **no budget-data network request**.

To run tests, choose **Product → Test** with the BudgetLens scheme, or use `xcodebuildmcp simulator test --workspace-path BudgetLens.xcworkspace --scheme BudgetLens --simulator-name "iPhone 17 Pro"`. No live API key is needed for tests.

## Providers

| Assistant | Kind | Endpoint | Default model | Auth |
| --- | --- | --- | --- | --- |
| OpenAI | Responses API | `https://api.openai.com/v1/responses` | `gpt-4.1-mini` | `Authorization: Bearer` |
| Anthropic | Messages API | `https://api.anthropic.com/v1/messages` | `claude-haiku-5-5` | `x-api-key` + `anthropic-version: 2023-06-01` |
| Gemini | generateContent | `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` | `gemini-3.8-flash` | `x-goog-api-key` |
| DeepSeek | OpenAI-compatible chat completions | `https://api.deepseek.com/chat/completions` | `deepseek-flash` | `Authorization: Bearer` |
| Custom | OpenAI-compatible chat completions | user-supplied `https://` base URL | user-supplied | `Authorization: Bearer` |

Custom assistants are stored as Codable preferences in `UserDefaults` (non-sensitive) and can be added or removed from Settings; removing one also deletes its key. All requests are HTTPS, non-streaming, and time-boxed to 30 seconds.

## Architecture decisions

The generated Xcode workspace contains a thin `BudgetLens` app target and one Swift package, `BudgetLensFeature`. The package uses **logical folders**, not separate framework targets:

- **Core**: formatting amounts and dates, plus compact spacing tokens.
- **Services**: bundled-data reader, per-assistant Keychain store (with a one-time migration of the original OpenAI key), four `URLSession` provider adapters behind a client registry, custom-assistant and active-assistant preference stores, and a redacted error reporter.
- **Domains**: typed budget data, the `Provider` catalog and custom-provider validation, compact historical LLM context, the provider-independent conversation operation, and application error cases.
- **Features**: launch routing, key entry, Budget, Ask and Settings views, with small `@MainActor` observable state. Features report failures through the Domain operation, never through the Services reporter directly.
- **App**: `BudgetLensEntryView`, the package's only public view. It builds the production dependencies and runs launch preparation; the `BudgetLens` app target just hosts it.

The views depend on the domain operation, never on provider HTTP types or Keychain APIs. The active assistant is a non-sensitive preference; each assistant's key lives in a separate Keychain account (`llm-key.<provider-id>`). All adapters share one error mapping: 401/403 (and 400s that mention an API key) become "invalid key", transport failures become "network", and empty/malformed bodies become "unusable reply". The UI shows an explanation plus replacement, retry, or settings actions; diagnostics report fixed context and error **types only**, never secrets or financial data. No external libraries or backend are required.

## Budget context, safety and privacy

The snapshot is **May 2025 sample data**, not a current balance. The JSON does not specify a currency: the UI divides integer cents into major units and labels them as having an unspecified currency, without adding a symbol. It shows the provided 88.2% spent and the two over-budget categories factually. `unallocatedBudgetCents` and `unbudgetedSpentCents` are displayed separately, without trying to reconcile them with other totals. Unspent categories, particularly Savings, are **not** presented as available cash.

The Ask composer names the active assistant and discloses that sending a question shares budget context and recent chat with **that provider**. For each request the app sends the historical period, aggregate and category amounts/statuses, the current question, and at most six recent messages; it excludes category IDs, icons, the API key from the *model context*, account/device information, and any invented currency. The API key is used only as the request credential. Instructions ask for a warm, nonjudgmental tone, clear uncertainty, and no invented transactions or prescriptive advice. Model text is rendered verbatim, with the assistant name shown on each reply. Chat stays in memory and is not saved locally; OpenAI requests use `store: false`, which disables the retrievable Responses API object but **is not a promise of zero provider retention**.

## Deliberate omissions

This exercise skips Plaid, account sign-in, transaction-level data, a backend, streaming, durable conversation history, per-provider model pickers for built-ins, editing existing custom assistants (remove and re-add instead), and a full design system. The model can still misunderstand the data or ignore tone instructions; we do not treat its output as verified financial advice. There is no live-provider automated test because that would require secrets and paid network access. A direct user-key-to-provider request is a project simplification, **not** a production architecture or privacy review. Test-only data is used to verify entry, replacement, switching and clearing through the running app; package unit tests use an in-memory key store because an unhosted Swift package test runner lacks Keychain entitlements.

## One product question

Before sending real customer finances to a third-party model, **what explicit consent, data-minimization, provider-retention and deletion guarantees should be required?** Multi-provider support makes this sharper: each assistant is a different data processor with different retention terms. In a real fintech product I would want legal/security review, a controlled server boundary, per-provider disclosure, clarity about customer expectations, and a way to use the budget view without AI at all.
