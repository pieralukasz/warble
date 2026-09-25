import FluidAudio
import XCTest
@testable import WarbleKit

final class ModelStatusTests: XCTestCase {
    func testListingHasNoFractionYet() {
        let status = ModelStatus.loading(from: DownloadProgress(fractionCompleted: 0.1, phase: .listing))

        XCTAssertEqual(status, .loading(fraction: nil, detail: "Checking model files"))
    }

    func testDownloadingReportsFilesAndFraction() {
        let progress = DownloadProgress(fractionCompleted: 0.4, phase: .downloading(completedFiles: 2, totalFiles: 5))

        let status = ModelStatus.loading(from: progress)

        XCTAssertEqual(status, .loading(fraction: 0.4, detail: "Downloading Parakeet v3 · 2 of 5 files"))
    }

    func testFractionIsClampedToUnitRange() {
        let progress = DownloadProgress(fractionCompleted: 1.7, phase: .compiling(modelName: "Encoder"))

        let status = ModelStatus.loading(from: progress)

        XCTAssertEqual(status, .loading(fraction: 1, detail: "Optimizing the model for this Mac"))
    }
}
