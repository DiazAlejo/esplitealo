#if DEBUG
import EsplitealoCapture
import EsplitealoCore
import Foundation
import Testing
@testable import Esplitealo

/// The launch arguments UI tests use to run the capture flow without a camera. Debug builds only.
@MainActor
struct ScanLaunchConfigurationTests {
    static var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Capture
            .deletingLastPathComponent() // EsplitealoTests
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // repository
            .appendingPathComponent("Tests/Fixtures/Receipts/pr-ivu-bistro.recognized.json")
    }

    @Test func withoutArgumentsThereIsNothingToInject() {
        #expect(ScanLaunchConfiguration(arguments: ["Esplitealo", "--uitesting"]) == nil)
    }

    @Test func theRecognizedTextArgumentLoadsTheFixtureReceipt() async throws {
        let configuration = try #require(ScanLaunchConfiguration(arguments: ["--uitesting-recognized-text", Self.fixtureURL.path]))
        let services = try configuration.services()
        let fixture = try #require(services.fixture)
        let draft = try await services.scan(fixture.image)
        #expect(draft.items.map(\.lineTotal.minorUnits) == [1450, 800])
        #expect(draft.total?.minorUnits == 2509)
    }

    @Test func theCameraArgumentOverridesThePermissionStatus() throws {
        let words: [(String, CameraPermissionStatus)] = [("authorized", .authorized), ("denied", .denied), ("restricted", .restricted), ("notDetermined", .notDetermined)]
        for (word, expected) in words {
            let configuration = try #require(ScanLaunchConfiguration(arguments: ["--uitesting-camera", word]))
            #expect(try configuration.services().cameraStatus() == expected, "\(word)")
        }
    }

    @Test func aCameraThatIsNotDeterminedIsGrantedWhenAsked() async throws {
        let configuration = try #require(ScanLaunchConfiguration(arguments: ["--uitesting-camera", "notDetermined"]))
        #expect(try await configuration.services().requestCameraAccess() == .authorized)
    }

    @Test func theUnsupportedWordMeansADeviceWithoutACamera() throws {
        let configuration = try #require(ScanLaunchConfiguration(arguments: ["--uitesting-camera", "unsupported"]))
        #expect(try configuration.services().isCameraSupported() == false)
    }

    @Test func theFailureArgumentFailsTheFirstAttempt() throws {
        let configuration = try #require(ScanLaunchConfiguration(arguments: ["--uitesting-recognized-text", Self.fixtureURL.path, "--uitesting-scan-failure", "tooManyPages"]))
        #expect(try configuration.services().fixture?.failsFirstWith == .tooManyPages)
    }

    @Test func theDelayArgumentSlowsTheScanDown() async throws {
        let configuration = try #require(ScanLaunchConfiguration(arguments: ["--uitesting-recognized-text", Self.fixtureURL.path, "--uitesting-scan-delay", "0.3"]))
        let services = try configuration.services()
        let start = ContinuousClock.now
        _ = try await services.scan(try #require(services.fixture).image)
        #expect(ContinuousClock.now - start >= .milliseconds(250))
    }

    @Test func aMissingFixtureFileIsAnError() {
        let configuration = ScanLaunchConfiguration(arguments: ["--uitesting-recognized-text", "/nonexistent/receipt.json"])
        #expect(throws: (any Error).self) { try configuration?.services() }
    }

    @Test func unknownWordsAreIgnored() {
        #expect(ScanLaunchConfiguration(arguments: ["--uitesting-camera", "banana"]) == nil)
        #expect(ScanLaunchConfiguration(arguments: ["--uitesting-scan-failure", "banana"]) == nil)
    }
}

#endif
