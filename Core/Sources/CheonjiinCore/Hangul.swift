/// 호환 자모(ㄱ, ㅏ …)와 완성형 음절 사이의 변환.
enum Hangul {
    static let initials: [Character] = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    static let vowels: [Character] = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    /// 인덱스 0은 받침 없음.
    static let finals: [Character] = Array(" ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ")

    static let compoundFinals: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ",
        "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ",
    ]

    static func canBeFinal(_ c: Character) -> Bool {
        c != " " && finals.contains(c)
    }

    static func finalCharacter(_ jamo: [Character]) -> Character? {
        switch jamo.count {
        case 0: return nil
        case 1: return canBeFinal(jamo[0]) ? jamo[0] : nil
        case 2: return compoundFinals[String(jamo)]
        default: return nil
        }
    }

    static func compose(initial: Character, vowel: Character, final: Character?) -> Character? {
        guard let l = initials.firstIndex(of: initial),
              let v = vowels.firstIndex(of: vowel) else { return nil }
        let t = final.flatMap { finals.firstIndex(of: $0) } ?? 0
        guard let scalar = Unicode.Scalar(0xAC00 + (l * 21 + v) * 28 + t) else { return nil }
        return Character(scalar)
    }
}
