import XCTest
@testable import cocotrack

/// Regression cover for the credential-loss bug found in the audit:
/// the Keychain write failed with `errSecMissingEntitlement` on every ad-hoc or
/// non-entitled build, the failure was discarded, and the legacy plaintext copy
/// in `UserDefaults` was deleted anyway — so the user was signed out on every
/// relaunch with nothing left to recover from.
final class APIKeyMigrationTests: XCTestCase {

    // MARK: - The bug: never drop the fallback on an unconfirmed write

    func testLegacyKeyIsKeptWhenKeychainWriteFails() {
        let result = APIKeyMigration.resolve(
            keychainKey: nil,
            legacyKey: "legacy-key",
            saveToKeychain: { _ in false }
        )

        XCTAssertEqual(result.apiKey, "legacy-key")
        XCTAssertFalse(result.removeLegacyKey, "A failed Keychain write must never destroy the only remaining copy.")
        XCTAssertTrue(result.keychainWriteFailed)
    }

    func testLegacyKeyIsRemovedOnlyAfterConfirmedWrite() {
        var saved: String?
        let result = APIKeyMigration.resolve(
            keychainKey: nil,
            legacyKey: "legacy-key",
            saveToKeychain: { saved = $0; return true }
        )

        XCTAssertEqual(saved, "legacy-key")
        XCTAssertEqual(result.apiKey, "legacy-key")
        XCTAssertTrue(result.removeLegacyKey)
        XCTAssertFalse(result.keychainWriteFailed)
    }

    // MARK: - Ordinary resolution paths

    func testKeychainKeyWinsOverLegacyKey() {
        var didSave = false
        let result = APIKeyMigration.resolve(
            keychainKey: "keychain-key",
            legacyKey: "legacy-key",
            saveToKeychain: { _ in didSave = true; return true }
        )

        XCTAssertEqual(result.apiKey, "keychain-key")
        XCTAssertTrue(result.removeLegacyKey, "The redundant plaintext copy should be cleaned up.")
        XCTAssertFalse(result.keychainWriteFailed)
        XCTAssertFalse(didSave, "No migration write is needed when the Keychain already holds the key.")
    }

    func testNoKeyAnywhereYieldsEmptyStateWithoutTouchingLegacyStorage() {
        let result = APIKeyMigration.resolve(
            keychainKey: nil,
            legacyKey: nil,
            saveToKeychain: { _ in XCTFail("Nothing to migrate"); return false }
        )

        XCTAssertEqual(result.apiKey, "")
        XCTAssertFalse(result.removeLegacyKey)
        XCTAssertFalse(result.keychainWriteFailed)
    }

    func testEmptyStringsAreTreatedAsAbsent() {
        let result = APIKeyMigration.resolve(
            keychainKey: "",
            legacyKey: "",
            saveToKeychain: { _ in XCTFail("Nothing to migrate"); return false }
        )

        XCTAssertEqual(result.apiKey, "")
        XCTAssertFalse(result.removeLegacyKey)
        XCTAssertFalse(result.keychainWriteFailed)
    }

    func testKeychainKeyPresentWithNoLegacyCopyLeavesLegacyStorageAlone() {
        let result = APIKeyMigration.resolve(
            keychainKey: "keychain-key",
            legacyKey: nil,
            saveToKeychain: { _ in XCTFail("Nothing to migrate"); return false }
        )

        XCTAssertEqual(result.apiKey, "keychain-key")
        XCTAssertFalse(result.removeLegacyKey)
    }
}

/// Exercises the real Keychain against a throwaway service name so the test can
/// never disturb the key the shipped app stores under `defaultService`.
final class APIKeyStoreTests: XCTestCase {
    private let service = "com.cocolab.cocotrack.tests"

    override func setUp() {
        super.setUp()
        APIKeyStore.delete(service: service)
    }

    override func tearDown() {
        APIKeyStore.delete(service: service)
        super.tearDown()
    }

    /// The regression that matters: the test bundle is ad-hoc signed, exactly like
    /// a direct-distribution build, so this fails outright without the fallback to
    /// the classic login keychain.
    func testSaveSucceedsAndRoundTripsWithoutEntitlements() {
        XCTAssertTrue(APIKeyStore.save("secret-value", service: service))
        XCTAssertEqual(APIKeyStore.load(service: service), "secret-value")
    }

    func testSaveOverwritesPreviousValue() {
        XCTAssertTrue(APIKeyStore.save("first", service: service))
        XCTAssertTrue(APIKeyStore.save("second", service: service))
        XCTAssertEqual(APIKeyStore.load(service: service), "second")
    }

    func testDeleteRemovesTheStoredValue() {
        XCTAssertTrue(APIKeyStore.save("secret-value", service: service))
        XCTAssertTrue(APIKeyStore.delete(service: service))
        XCTAssertNil(APIKeyStore.load(service: service))
    }

    func testDeleteOnAbsentItemIsNotAFailure() {
        XCTAssertTrue(APIKeyStore.delete(service: service))
    }

    func testLoadReturnsNilWhenNothingStored() {
        XCTAssertNil(APIKeyStore.load(service: service))
    }

    func testUnicodeAndLongKeysSurviveTheRoundTrip() {
        let value = String(repeating: "ą🔑Ω", count: 200)
        XCTAssertTrue(APIKeyStore.save(value, service: service))
        XCTAssertEqual(APIKeyStore.load(service: service), value)
    }
}
