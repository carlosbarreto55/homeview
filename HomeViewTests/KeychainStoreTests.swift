import XCTest
@testable import HomeView

final class KeychainStoreTests: XCTestCase {
    private var store: KeychainStore!

    override func setUp() {
        super.setUp()
        store = KeychainStore(service: "com.carloseduardo.HomeView.tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        try? store.delete()
        super.tearDown()
    }

    func testNothingSavedReadsNil() throws {
        XCTAssertNil(try store.read())
    }

    func testSaveThenRead() throws {
        try store.save(Credentials(user: "macApp", password: "a@b:c/d#e çã"))
        XCTAssertEqual(try store.read(), Credentials(user: "macApp", password: "a@b:c/d#e çã"))
    }

    func testSaveReplacesTheLogin() throws {
        try store.save(Credentials(user: "macApp", password: "old"))
        try store.save(Credentials(user: "outro", password: "new"))
        XCTAssertEqual(try store.read(), Credentials(user: "outro", password: "new"))
    }

    func testDelete() throws {
        try store.save(Credentials(user: "macApp", password: "secret"))
        try store.delete()
        XCTAssertNil(try store.read())
        XCTAssertNoThrow(try store.delete(), "deleting nothing is fine")
    }

    func testStoresAreSeparatedByService() throws {
        let other = KeychainStore(service: store.service + ".other")
        defer { try? other.delete() }
        try store.save(Credentials(user: "macApp", password: "secret"))
        XCTAssertNil(try other.read())
    }
}
