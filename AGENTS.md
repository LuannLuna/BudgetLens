# Agent instructions

Before changing Swift code or project structure, follow this file. The BudgetLens project brief defines product scope; these instructions define implementation requirements. Do not treat examples in either source as a reason to invent missing APIs or data.

Keep changes proportional to the BudgetLens project: a clear, working app is more valuable than an elaborate architecture or pixel-perfect styling. When a rule cannot apply, explain the exception in the README or near the code rather than silently ignoring it.

## Project boundaries

- Build a native iOS app. Use the bundled `BudgetLensSampleJSON.json` as the budget data source; do not fetch budget data over the network.
- Save the user's chosen LLM API key in Keychain, not `UserDefaults`, source code, or a checked-in configuration file. Support replacing or clearing it. Do not log the key, chat text, or raw financial snapshot.
- Send only the budget context needed to answer a chat question to the selected LLM. Treat the May 2025 snapshot as historical, not live financial data. Do not assume a currency that the payload does not identify or treat category balances as available cash.
- Make responses approachable and grounded in the supplied data. Acknowledge uncertainty; avoid invented transactions, alarming language, and prescriptive financial advice.
- Show actionable, user-facing errors for a missing/invalid key, network failure, and empty/malformed LLM replies. Console diagnostics are not a substitute.
- Preserve the README's required discussion of architecture, deliberate omissions, LLM context/privacy, and one open product question.

## UI and state

1. Use **SwiftUI** for new UI. Use UIKit through `UIViewRepresentable` or `UIViewControllerRepresentable` only where SwiftUI cannot provide the needed capability. Pure UIKit and new `UIViewController` subclasses require a specific justification. Integrate existing UIKit incrementally rather than rewriting unrelated code.
2. Use `@State` for local view state, `@Binding` for child edits, and `@Environment` for scoped dependencies. For shared observable state on iOS 17+, use `@Observable`; if the deployment target is older, use a compatible alternative and note why. Keep state holders small and responsibility-specific (aim for fewer than 150 lines); compute derived values rather than storing duplicate state.
3. Do not add global state singletons or broad `EnvironmentObject` dependencies. Keep navigation and routes in Features; App composes the entry point and dependencies.
4. Prefer adaptive SwiftUI layout, built-in controls, Dynamic Type, VoiceOver-friendly labels, and system appearance. Avoid fixed screen widths or heights.
5. Use existing design-system components and semantic color, typography, and spacing tokens. If none exist, start with system styles and a small set of semantic tokens for custom values; do not create a large design system for this exercise. Avoid hard-coded custom colors, fonts, and spacing throughout views.

## Concurrency and Swift APIs

- Prefer `async`/`await` and `async throws` to completion handlers or Combine for one-shot work. Use structured concurrency (`async let`, task groups) for related parallel operations and respect cancellation.
- Isolate UI-bound state with `@MainActor`; use an `actor` for shared mutable state. Avoid GCD and locks unless bridging a legacy/system API. Avoid `Task.detached` and `@unchecked Sendable` unless there is a documented reason and the safety invariant is explained.
- Prefer `struct` and `enum` to classes when identity or shared mutation is not needed. Prefer protocols for substitutable dependencies over class inheritance. Use Swift-native types, `Codable` for JSON, `throws`/`do`/`catch` for errors, and `some View` for view-returning APIs. Use `Result` only when required at a framework or legacy boundary.
- Unwrap optionals safely with `if let` or `guard let`. Never force-unwrap, force-cast (`as!`), or force-try (`try!`). Implicitly unwrapped optionals are only acceptable for unavoidable legacy `@IBOutlet` code.
- Use `guard` for early exits in imperative functions and closures. `if let` is valid in SwiftUI view builders for conditional views; a direct `guard` with an early return generally belongs in a helper function or computed property instead of `body`.
- Use property wrappers where they simplify a real cross-cutting concern, not just to hide state flow. Name extensions `Type+Capability.swift` when splitting them into files.

## Architecture and dependency direction

Organize code by responsibility, without creating separate packages merely to mirror folders:

| Layer | Owns | May depend on project layers |
| --- | --- | --- |
| Core | Small foundational utilities and extensions | None |
| Services | Keychain, LLM HTTP client, local file/JSON loading, system APIs | Core |
| Domains | Budget models, budget interpretation, safe chat context, interfaces/wrappers around services | Core, Services |
| Features | SwiftUI screens, user interactions, presentation state, navigation | Core, Domains |
| App | App lifecycle and dependency composition | All layers |

- Features must not import Services directly or know provider-specific types/errors. Expose the operation through a Domain API and map infrastructure errors to meaningful application errors.
- Keep responsibilities independently testable. Inject dependencies at boundaries; avoid turning a small project into a multi-package framework.
- Prefer Apple frameworks such as `URLSession` and Keychain APIs when sufficient. For any third-party dependency, put a thin adapter in Services or Domains. Features, widgets, and extensions must not import vendor modules or expose vendor types/errors.
- Widgets and extensions, if added, should be small, isolated, mindful of memory/execution limits, and share Domain code rather than import Features.

## Names and errors

- Name types for their specific job (for example, `BudgetSnapshot`, `ChatConversationState`, `LLMChatClient`, `APIKeyStore`). Avoid catch-all suffixes: `Manager`, `ViewModel`, `Coordinator`, `Helper`, `Util`, `Utilities`, `Common`, and `Base`.
- Name new shared repositories/packages `swift-<layer-or-domain>-<object>` where that pattern applies. Do not rename this project repository to satisfy the pattern.
- Give error cases enough context to distinguish invalid credentials, transport failures, decoding failures, and unusable LLM content. Never swallow a `catch` or report success after a failed operation.
- Use the repository's `errorReport()` facility if one exists. If it does not, introduce a small, explicit reporting abstraction before calling it; do not leave an undefined `errorReport()` in code. Reporting must redact secrets and sensitive content, and must accompany—not replace—user-facing recovery guidance.

## Localization and formatting

- Use contextual, stable localization keys where copy needs to survive wording changes or requires different translations in different contexts. Include translator comments on user-facing static strings; do not render enum `rawValue` directly.
- Prefer `Text("Key", comment: "Context for translators")` for a literal localization key. When passing a key as data, use `Text(titleKey, comment: "Context for translators")` if it is a `LocalizedStringKey`, or `Text(LocalizedStringKey(titleKey), comment: "Context for translators")` if a `String` intentionally contains a localization key.
- Treat dynamic chat responses and user-provided text as verbatim content, not localization keys. Format dates, percentages, and integer-cent amounts with locale-aware APIs. Confirm or explicitly label any currency assumption; the sample JSON does not name a currency.

## Shared APIs and verification

- For a shared package, bump **PATCH** for internal-only changes, **MINOR** for additive public APIs, and **MAJOR** for breaking public APIs (including new protocol requirements or exhaustive enum cases). This does not require versioning the project app itself.
- Before finishing a change, check decoding of the bundled payload, money/percentage presentation, Keychain save/read/reset, chat context, and all three required error paths. Add focused tests for logic that can be tested without a live LLM call. If a check cannot be run, state that explicitly.
