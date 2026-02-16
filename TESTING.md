## Astryx testing (Unit + UI)

This repo uses:
- **Unit tests**: Apple’s `Testing` framework in the `AstryxTests` target.
- **UI tests**: `XCTest` in the `AstryxUITests` target.

### Run tests in Xcode
- Select the **`Astryx` scheme**
- Run all tests: **Product → Test** (Cmd+U)
- Run a single test: open the test file and click the gutter run icon

### Code coverage (enabled in the shared scheme)
Coverage is enabled in the shared scheme (`Astryx.xcodeproj/xcshareddata/xcschemes/Astryx.xcscheme`) and scoped to the `Astryx` app target.

To view coverage in Xcode:
- Run tests (Cmd+U)
- Open **Report navigator** (Cmd+9) → select the latest Test run → **Coverage**

### Run tests from Terminal (optional, reproducible)
You can run tests without opening Xcode:

```bash
xcodebuild test \
  -project Astryx.xcodeproj \
  -scheme Astryx \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES
```

If you don’t have an `iPhone 16` simulator, replace the destination with one you do have.

### Unit test rules (App Store–friendly)
- **No network / no real AI calls** in unit tests. Use fakes for `AIInsightService` / `FocusSummaryServiceProtocol`.
- **No time/randomness/locale dependencies**. If needed, pass a fixed `Date` or fixed strings.
- Prefer testing **ViewModels + Services** (business logic) over SwiftUI views.

