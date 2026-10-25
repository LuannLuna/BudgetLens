# BudgetLens — iOS project

A small SwiftUI app for exploring a **historical, local budget snapshot** and asking supportive questions about it. It targets iOS 17+ and supports **multiple LLM providers** (OpenAI, Anthropic, Gemini, DeepSeek, plus custom OpenAI-compatible endpoints), each with its own Keychain-stored key. The app does not connect to a bank or fetch budget data.

## Run it

1. Open `BudgetLens.xcworkspace` in Xcode 27, select the **BudgetLens** scheme and an iOS simulator, then Run. There are no third-party packages or setup secrets.
2. On first launch, choose an **assistant** — including **Custom assistant…** for any OpenAI-compatible endpoint — and enter your own API key for it. Keys are saved to the device-only Keychain; a nonempty key for the active assistant unlocks the local dashboard, but validity is determined only when that provider answers the first request. Sending a question makes a paid API call using the active assistant's key.
3. Read the **Budget** tab first, then use **Ask** to discuss the sample. The Ask header switches the active assistant (the conversation is kept when the new assistant already has a key; choosing one without a key opens key entry and the chat starts fresh once it is connected). **Settings** manages each assistant's key (add/replace/clear) and custom assistants. On the welcome screen, picking an assistant that already has a saved key and leaving the field empty reuses that key. Clearing the active key falls back to another configured assistant, or back to key entry if none remain. Replacing a key keeps the in-memory chat; clearing the active key (or removing the active custom assistant) ends it. A question that fails for a reason you fix in Settings (key, or model and URL) goes back into the composer so you can send it again once fixed.

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

Custom assistants are stored as Codable preferences in `UserDefaults` (non-sensitive) and can be added or removed from Settings; removing one also deletes its key. A custom base URL must be HTTPS with a host and no embedded credentials, query or fragment; the app trims a trailing slash or a pasted `/chat/completions`, because it appends `/chat/completions` itself. All requests are HTTPS, non-streaming, and time-boxed to 30 seconds.

## Architecture decisions

The generated Xcode workspace contains a thin `BudgetLens` app target and one Swift package, `BudgetLensFeature`. The package uses **logical folders**, not separate framework targets:

- **Core**: formatting amounts, percentages and dates (the locale can be injected), safe rendering of reply Markdown, the `Provider` value type with its built-in catalog, and compact spacing tokens.
- **Services**: bundled-data reader, per-assistant Keychain store, four `URLSession` provider adapters (sharing one JSON POST helper) behind a client registry, custom-assistant and active-assistant preference stores, and a redacted error reporter.
- **Domains**: typed budget data, custom-provider validation, compact historical LLM context, the provider-independent conversation operation, and application error cases.
- **Features**: launch routing, key entry, Budget, Ask and Settings views, with small `@MainActor` observable state. Features report failures through the Domain operation, never through the Services reporter directly.
- **App**: `BudgetLensEntryView`, the package's only public view. It builds the production dependencies and runs launch preparation; the `BudgetLens` app target just hosts it.

The views depend on the domain operation, never on provider HTTP types or Keychain APIs. The active assistant is a non-sensitive preference; each assistant's key lives in a separate Keychain account (`llm-key.<provider-id>`). All adapters share one error mapping: 401/403 (and 400s that mention an API key) become "invalid key", 402/429 become "usage limit or no credit" (retry offered), other 400/404/422 become "request rejected" (usually a wrong model or URL, with a Settings action), any other non-2xx status becomes "unavailable", transport failures become "network", and empty/malformed bodies become "unusable reply". Keychain read or write failures surface as a "saved key" error instead of a raw system error. Failing to save a custom assistant has its own message, an unreadable custom-assistant list is reported and treated as empty, and a failed assistant switch is shown inline without replacing the screen. The UI shows an explanation plus replacement, retry, or settings actions; diagnostics report fixed context and error **types only**, never secrets or financial data. No external libraries or backend are required.

## Tests

Unit tests use Swift Testing with in-memory stores and stub responders, so they need no key, network or Keychain entitlement. They cover decoding the bundled payload, the safe context (amounts in major units) and the exact messages sent per question (context, last six messages, question), locale-injected money, percentage and period formatting, reply Markdown, per-provider reply parsing, the headers, paths and bodies each adapter sends and the HTTP-status and transport mapping (through a `URLProtocol` stub, never a live endpoint), the retry and "question returns to the composer" behavior, key lifecycle and assistant-switching state, and custom-assistant validation and storage failures. XCUITest exercises the real Keychain through first launch, replacing and clearing a key, choosing another or a custom assistant, reusing a saved key, and the Settings picker following a fallback assistant. A DEBUG-only launch argument (`--ui-testing-provider-failure=` with `invalid-key`, `quota`, `rejected`, `network`, `unusable` or `unavailable`) swaps the provider client for one that always fails, so a UI test can drive an error screen without a live provider; one such test covers the invalid-key flow. The test plan collects coverage for the `BudgetLensFeature` target. Not covered: real provider responses and rendered view output.

## Budget context, safety and privacy

The snapshot is **May 2025 sample data**, not a current balance. The JSON does not specify a currency: the UI divides integer cents into major units and labels them as having an unspecified currency, without adding a symbol. It shows the provided 88.2% spent and the two over-budget categories factually. `unallocatedBudgetCents` and `unbudgetedSpentCents` are displayed separately, without trying to reconcile them with other totals. Unspent categories, particularly Savings, are **not** presented as available cash.

The Ask composer names the active assistant and discloses that sending a question shares budget context and recent chat with **that provider**. For each request the app sends the historical period, aggregate and category amounts (in major units with a period decimal, labelled as an unspecified currency) and statuses, the current question, and at most six recent messages; it excludes category IDs, icons, the API key from the *model context*, account/device information, and any invented currency. The API key is used only as the request credential. Instructions ask for a warm, nonjudgmental tone, clear uncertainty, and no invented transactions or prescriptive advice. Model text is shown as received, except that inline Markdown emphasis is styled and links are removed so a reply cannot add a tappable URL; the assistant name is shown on each reply. Chat stays in memory and is not saved locally; OpenAI requests use `store: false`, which disables the retrievable Responses API object but **is not a promise of zero provider retention**.

### What I would revisit with more time

- **Tone is instructed, not verified.** Warmth, stated uncertainty and "no prescriptive advice" depend on the system instructions alone; nothing checks them. I would keep a small set of anxious-user prompts ("Am I doing badly?", "Can I afford a trip?") and review each provider's replies before shipping.
- **Per-question minimization.** Every request carries the whole snapshot plus up to six recent messages. A real product should send only the categories a question needs, and justify the history window with evidence rather than a round number.
- **Richer, structured context.** Per-category percentages are omitted, so the model derives them; a fixed schema, with prompt fixtures under test, would make the context easier to audit.
- **Prompt injection beyond one sentence.** The snapshot is trusted local data and the instructions tell the model not to follow text inside it, but that is defense in depth, not a guarantee. Transaction descriptions or merchant names from Plaid would need real handling.
- **Block-level Markdown.** Inline emphasis and code are styled and links are removed, but lists, headings and tables still appear as plain text; I would render a safe subset of blocks too.
- **Default model IDs against live endpoints.** I would confirm each default in the Providers table (`gpt-4.1-mini`, `claude-haiku-5-5`, `gemini-3.8-flash`, `deepseek-flash`) with a real key and one request per provider, and fix any ID a provider rejects. No automated test reaches a live endpoint, so a retired or mistyped ID would only surface at runtime, as a "request rejected" message with a Settings action.

## Deliberate omissions

This exercise skips Plaid, account sign-in, transaction-level data, a backend, streaming, durable conversation history, per-provider model pickers for built-ins, editing existing custom assistants (remove and re-add instead), and a full design system. The model can still misunderstand the data or ignore tone instructions; we do not treat its output as verified financial advice. There is no live-provider automated test because that would require secrets and paid network access. A direct user-key-to-provider request is a project simplification, **not** a production architecture or privacy review. Test-only data is used to verify entry, replacement, switching and clearing through the running app; package unit tests use an in-memory key store because an unhosted Swift package test runner lacks Keychain entitlements. Default model IDs are not covered by any automated test; if a provider retires one, the app reports a rejected request and offers Settings, where another assistant can be chosen. After a key is replaced, the earlier error notice stays on screen until the next send, although the question is already back in the composer. The bundle identifier is `com.budgetlens.BudgetLens`, set in `Config/Shared.xcconfig`; the Keychain service and the log subsystem follow it, so changing it later makes keys saved under the old one unreadable.

## One product question

Before sending real customer finances to a third-party model, **what explicit consent, data-minimization, provider-retention and deletion guarantees should be required?** Multi-provider support makes this sharper: each assistant is a different data processor with different retention terms. In a real fintech product I would want legal/security review, a controlled server boundary, per-provider disclosure, clarity about customer expectations, and a way to use the budget view without AI at all.
