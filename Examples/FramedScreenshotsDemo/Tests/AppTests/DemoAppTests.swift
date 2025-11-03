import XCTest
@testable import DemoApp

final class DemoAppTests: XCTestCase {
    func testContentView() {
        // Smoke test to ensure preview content builds.
        let view = ContentView()
        XCTAssertNotNil(view.highlightedSample)
    }
}
