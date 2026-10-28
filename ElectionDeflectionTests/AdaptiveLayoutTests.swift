import SwiftUI
import XCTest
@testable import ElectionDeflection

final class AdaptiveLayoutTests: XCTestCase {

    // MARK: - iPhone Duo displays (points)

    func testDuoOuterPortraitIsSingleColumn() {
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: .compact, availableWidth: 466), .singleColumn)
    }

    func testDuoOuterLandscapeIsSingleColumn() {
        // Compact class even though it is wider than the two-column threshold.
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: .compact, availableWidth: 678), .singleColumn)
    }

    func testDuoInnerPortraitIsTwoColumn() {
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: .regular, availableWidth: 669), .twoColumn)
    }

    func testDuoInnerLandscapeIsTwoColumn() {
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: .regular, availableWidth: 951), .twoColumn)
    }

    // MARK: - Edges

    func testRegularJustBelowThresholdIsSingleColumn() {
        let width = AdaptiveLayout.twoColumnMinWidth - 1
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: .regular, availableWidth: width), .singleColumn)
    }

    func testRegularAtThresholdIsTwoColumn() {
        let width = AdaptiveLayout.twoColumnMinWidth
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: .regular, availableWidth: width), .twoColumn)
    }

    func testNilSizeClassIsTreatedAsCompact() {
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: nil, availableWidth: 1000), .singleColumn)
    }

    func testCompactWideWindowIsSingleColumn() {
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: .compact, availableWidth: 1000), .singleColumn)
    }

    func testRegularZeroWidthIsSingleColumn() {
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: .regular, availableWidth: 0), .singleColumn)
    }

    func testRegularVeryWideIsTwoColumn() {
        XCTAssertEqual(AdaptiveLayout.mode(horizontalSizeClass: .regular, availableWidth: 10_000), .twoColumn)
    }

    // MARK: - Column width

    func testSingleColumnIsUncapped() {
        XCTAssertEqual(AdaptiveLayout.columnMaxWidth(for: .singleColumn), .infinity)
    }

    func testTwoColumnIsCappedToReadableWidth() {
        XCTAssertEqual(AdaptiveLayout.columnMaxWidth(for: .twoColumn), AdaptiveLayout.readableMaxWidth)
    }

    // MARK: - Invariants

    func testModeIsDeterministic() {
        let classes: [UserInterfaceSizeClass?] = [nil, .compact, .regular]
        let widths: [CGFloat] = [0, 466, 669, 678, 951, AdaptiveLayout.twoColumnMinWidth]
        for sizeClass in classes {
            for width in widths {
                let first = AdaptiveLayout.mode(horizontalSizeClass: sizeClass, availableWidth: width)
                let second = AdaptiveLayout.mode(horizontalSizeClass: sizeClass, availableWidth: width)
                XCTAssertEqual(first, second, "class \(String(describing: sizeClass)), width \(width)")
            }
        }
    }

    func testReadableWidthIsAtLeastTwoColumnThreshold() {
        XCTAssertGreaterThanOrEqual(AdaptiveLayout.readableMaxWidth, AdaptiveLayout.twoColumnMinWidth)
    }
}
