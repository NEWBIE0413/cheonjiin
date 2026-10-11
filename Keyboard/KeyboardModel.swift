import CheonjiinCore
import UIKit

enum Layer {
    /// symbols = 숫자와 특수문자를 한 화면에.
    case korean, english, symbols

    var isLetters: Bool { self == .korean || self == .english }
}

enum Shift {
    case off, on, locked
}

enum KeyAction: Equatable {
    case cheonjiin(CheonjiinInput)
    case character(String)
    case backspace, space, enter, globe, shift
    /// . , ? ! 를 연타로 순환.
    case punctuation
    /// 숫자·특수문자 화면의 1/2 ↔ 2/2.
    case symbolPage
    case layer(Layer)
}

/// 키보드의 모든 입력 동작. 화면은 `press`/`release`만 부르고, 상태가 바뀌면 `onChange`로 다시 그린다.
@MainActor
final class KeyboardModel {
    var layer: Layer = .korean { didSet { if layer != oldValue { onChange?() } } }
    var shift: Shift = .off { didSet { if shift != oldValue { onChange?() } } }
    private(set) var forcedDark = false { didSet { if forcedDark != oldValue { onChange?() } } }
    /// 조합 중인 글자(문장부호 순환 포함)가 있는지 — 이때 간격 키는 띄어쓰지 않고 조합만 끝낸다.
    private(set) var composing = false { didSet { if composing != oldValue { onChange?() } } }
    /// 간격 키를 끌어 커서를 옮기는 중 — 시스템 키보드처럼 키 글자를 감춘다.
    private(set) var cursorMode = false { didSet { if cursorMode != oldValue { onChange?() } } }
    /// 숫자·특수문자 화면의 쪽(0 = 1/2, 1 = 2/2).
    private(set) var symbolPage = 0 { didSet { if symbolPage != oldValue { onChange?() } } }
    /// 숫자·기호에서 돌아갈 글자 레이어.
    private(set) var letterLayer: Layer = .korean

    var onChange: (() -> Void)?

    private weak var controller: UIInputViewController?
    /// 같은 자음 연타는 시간 제한 없이 순환한다. 끊을 때는 간격 키를 누른다("안녕": ㄴ, 간격, ㄴ).
    private var engine = CheonjiinEngine(cycleWindow: .infinity)
    private var hapticsAllowed = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var lastShiftTap = 0.0
    private var repeatTask: Task<Void, Never>?
    private var globeTask: Task<Void, Never>?
    private var globeLongPressed = false
    private var spaceSteps = 0
    /// 간격을 누르는 순간 띄어쓰기를 넣었는지 — 끌어서 커서 이동이 되면 되돌린다.
    private var spaceInserted = false
    /// 문장부호 키로 넣은 마지막 부호의 순번. 다른 키를 누르면 끝난다.
    private var punctuationIndex: Int?
    private var lastEditTime = 0.0
    private var syncTask: Task<Void, Never>?

    static let punctuationMarks = [".", ",", "?", "!"]

    /// 간격 키를 끌 때 커서 한 칸에 해당하는 거리(pt).
    private static let cursorStep: CGFloat = 9

    init(controller: UIInputViewController) {
        self.controller = controller
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }
    private var now: Double { ProcessInfo.processInfo.systemUptime }

    // MARK: 키

    func press(_ action: KeyAction) {
        feedback()
        syncTask?.cancel()
        lastEditTime = now
        if action != .punctuation, action != .space, punctuationIndex != nil {
            punctuationIndex = nil
            syncComposing()
        }
        switch action {
        case .cheonjiin(let input):
            apply(engine.type(input, at: now))
        case .character(let text):
            commitComposition()
            proxy?.insertText(shift == .off ? text : text.uppercased())
            if shift == .on { shift = .off }
            autoShift()
        case .backspace:
            deleteOnce()
            startRepeat()
        case .space:
            // 누르는 순간 처리한다. 떼는 순간에 하면 빠른 연타에서 간격을 떼기 전에 다음 자음이
            // 먼저 들어가 앞 글자에 붙어 버린다("안" 간격 ㄴ → "알").
            spaceSteps = 0
            spaceInserted = false
            if punctuationIndex != nil || engine.isComposing {
                commitComposition()
            } else {
                proxy?.insertText(" ")
                spaceInserted = true
                if !layer.isLetters { setLayer(letterLayer) }
                autoShift()
            }
        case .punctuation:
            let marks = Self.punctuationMarks
            if let index = punctuationIndex {
                proxy?.deleteBackward()
                punctuationIndex = (index + 1) % marks.count
            } else {
                commitComposition()
                punctuationIndex = 0
            }
            proxy?.insertText(marks[punctuationIndex!])
            syncComposing()
        case .enter:
            commitComposition()
            proxy?.insertText("\n")
            autoShift()
        case .layer(let next):
            setLayer(next)
        case .shift:
            shiftTap()
        case .symbolPage:
            symbolPage = 1 - symbolPage
        case .globe:
            globeLongPressed = false
            globeTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, let self else { return }
                self.globeLongPressed = true
                self.commitComposition()
                self.controller?.advanceToNextInputMode()
            }
        }
    }

    func release(_ action: KeyAction) {
        switch action {
        case .backspace:
            repeatTask?.cancel()
            repeatTask = nil
        case .space:
            cursorMode = false
        case .globe:
            // 한/A 탭: 한글 ↔ 영문. 길게: iOS의 다음 키보드(이모지 등) — 심사 규정상 다음 키보드로 넘어갈 방법.
            globeTask?.cancel()
            if !globeLongPressed { setLayer(layer == .korean ? .english : .korean) }
        default:
            break
        }
    }

    /// 간격 키를 좌우로 끌면 커서가 움직인다.
    func spaceDrag(_ dx: CGFloat) {
        let steps = Int(dx / Self.cursorStep)
        guard steps != spaceSteps else { return }
        if !cursorMode {
            if spaceInserted { proxy?.deleteBackward() }
            commitComposition()
            cursorMode = true
        }
        proxy?.adjustTextPosition(byCharacterOffset: steps - spaceSteps)
        spaceSteps = steps
        if hapticsAllowed { haptic.impactOccurred(intensity: 0.4) }
    }

    // MARK: 문서와 동기화

    func refreshContext() {
        commitComposition()
        hapticsAllowed = controller?.hasFullAccess == true
        if hapticsAllowed { haptic.prepare() }
        forcedDark = proxy?.keyboardAppearance == .dark
        autoShift()
    }

    /// 커서를 옮기거나 앱이 글을 바꾸면(메시지 전송 후 입력창 비우기 등) 조합을 놓는다.
    /// 앱이 알려 주는 문서 내용은 우리 입력보다 늦게 따라오므로, 타자가 멈추고 잠시 뒤에
    /// 확인한다 — 바로 비교하면 빠른 연타 중에 멀쩡한 조합을 끊어 자모가 떨어져 나간다.
    func documentChanged() {
        syncTask?.cancel()
        guard composing else { return }
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            self.verifyComposition()
        }
    }

    private func verifyComposition() {
        guard composing, now - lastEditTime >= 0.3,
              let before = proxy?.documentContextBeforeInput else { return }
        let expected = punctuationIndex.map { Self.punctuationMarks[$0] } ?? engine.composingText
        if !before.hasSuffix(expected) { commitComposition() }
    }

    // MARK: 내부

    private func setLayer(_ next: Layer) {
        commitComposition()
        shift = .off
        symbolPage = 0
        layer = next
        if next.isLetters { letterLayer = next }
        autoShift()
    }

    private func shiftTap() {
        let t = now
        if shift == .on, t - lastShiftTap < 0.35 {
            shift = .locked
        } else {
            shift = shift == .off ? .on : .off
        }
        lastShiftTap = t
    }

    /// 영문에서 문장 첫 글자는 대문자로 — 입력창의 자동 대문자 설정을 따른다.
    private func autoShift() {
        guard layer == .english, shift != .locked, let proxy else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        let wantsCapital: Bool
        switch proxy.autocapitalizationType ?? .sentences {
        case .allCharacters:
            wantsCapital = true
        case .words:
            wantsCapital = before.last.map(\.isWhitespace) ?? true
        case .sentences:
            let trimmed = before.trimmingCharacters(in: .whitespaces)
            wantsCapital = trimmed.isEmpty || before.hasSuffix("\n")
                || (before.last == " " && [".", "!", "?"].contains(trimmed.last))
        default:
            wantsCapital = false
        }
        shift = wantsCapital ? .on : .off
    }

    /// 길게 누르면 처음엔 한 글자씩, 1초쯤 지나면 시스템 키보드처럼 단어째 지운다.
    private func startRepeat() {
        repeatTask?.cancel()
        repeatTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            var count = 0
            while !Task.isCancelled {
                guard let self else { return }
                if count < 14 {
                    self.deleteOnce()
                    if self.hapticsAllowed { self.haptic.impactOccurred(intensity: 0.5) }
                    try? await Task.sleep(for: .milliseconds(70))
                } else {
                    self.deleteWord()
                    try? await Task.sleep(for: .milliseconds(180))
                }
                count += 1
            }
        }
    }

    private func deleteOnce() {
        apply(engine.backspace())
        autoShift()
    }

    private func deleteWord() {
        commitComposition()
        guard let proxy else { return }
        var count = 0
        var sawWord = false
        for ch in (proxy.documentContextBeforeInput ?? "").reversed() {
            if ch.isWhitespace, sawWord { break }
            if !ch.isWhitespace { sawWord = true }
            count += 1
        }
        for _ in 0..<max(count, 1) { proxy.deleteBackward() }
        if hapticsAllowed { haptic.impactOccurred(intensity: 0.6) }
    }

    private func commitComposition() {
        engine.commit()
        punctuationIndex = nil
        composing = false
    }

    private func syncComposing() {
        composing = engine.isComposing || punctuationIndex != nil
    }

    private func apply(_ edit: TextEdit) {
        if let proxy {
            for _ in 0..<edit.deleteCount { proxy.deleteBackward() }
            if !edit.insert.isEmpty { proxy.insertText(edit.insert) }
        }
        syncComposing()
    }

    /// 진동을 먼저 — 문서 편집보다 앞서야 손끝 느낌이 늦지 않는다.
    private func feedback() {
        // 키보드 익스텐션의 진동은 '전체 접근 허용'이 켜져 있을 때만 동작한다.
        if hapticsAllowed {
            haptic.impactOccurred()
            haptic.prepare()
        }
        UIDevice.current.playInputClick()
    }
}
