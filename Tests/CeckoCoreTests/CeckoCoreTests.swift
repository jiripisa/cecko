import Testing
@testable import CeckoCore

@Suite("CeckoCore")
struct CeckoCoreTests {

    @Test("Greeting names the app")
    func greetingNamesTheApp() {
        #expect(CeckoCore.greeting(appName: "Cecko") == "Welcome to Cecko")
    }
}
