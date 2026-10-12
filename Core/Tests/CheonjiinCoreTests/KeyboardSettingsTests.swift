import Foundation
import Testing
@testable import CheonjiinCore

@Test func settingsRoundTripThroughDefaults() throws {
    let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
    var s = KeyboardSettings()
    s.languages = [.english, .dubeolsik, .cheonjiin]
    s.hapticStrength = 0.5
    s.keyRepeat = false
    s.save(to: defaults)
    #expect(KeyboardSettings.load(from: defaults) == s)
}

@Test func missingDefaultsGiveDefaults() {
    #expect(KeyboardSettings.load(from: nil) == KeyboardSettings())
}

@Test func olderOrPartialJSONKeepsDefaultsForMissingFields() throws {
    let json = #"{"languages":["english","klingon"],"haptics":false}"#
    let s = try JSONDecoder().decode(KeyboardSettings.self, from: Data(json.utf8))
    #expect(s.languages == [.english])
    #expect(s.haptics == false)
    #expect(s.portraitRowHeight == KeyboardSettings().portraitRowHeight)
}

@Test func sanitizeFixesEmptyDuplicateAndOutOfRange() {
    var s = KeyboardSettings()
    s.languages = []
    s.portraitRowHeight = 999
    s.repeatInterval = 0
    #expect(s.sanitized().languages == [.cheonjiin])
    #expect(s.sanitized().portraitRowHeight == 60)
    #expect(s.sanitized().repeatInterval == 0.02)
    s.languages = [.english, .english, .cheonjiin]
    #expect(s.sanitized().languages == [.english, .cheonjiin])
}
