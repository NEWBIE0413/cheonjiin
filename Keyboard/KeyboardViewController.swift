import UIKit

/// 키 클릭음(`playInputClick`)은 입력 뷰가 이 프로토콜을 따를 때만 난다.
final class ClickableInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

final class KeyboardViewController: UIInputViewController {
    private lazy var model = KeyboardModel(controller: self)
    private lazy var keyboardView = KeyboardView(model: model)
    private var heightConstraint: NSLayoutConstraint?

    override func loadView() {
        let view = ClickableInputView(frame: .zero, inputViewStyle: .keyboard)
        view.allowsSelfSizing = true
        inputView = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        let height = view.heightAnchor.constraint(equalToConstant: KeyboardView.height(rowHeight: KeyboardView.rowHeight))
        height.priority = .required - 1
        heightConstraint = height
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])
        model.onChange = { [weak self] in self?.keyboardView.refresh() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.refreshContext()
        keyboardView.refresh()
    }

    /// 가로 화면에서는 키를 낮춰 글이 가려지지 않게 한다.
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let rowHeight = traitCollection.verticalSizeClass == .compact ? KeyboardView.compactRowHeight : KeyboardView.rowHeight
        keyboardView.rowHeight = rowHeight
        heightConstraint?.constant = KeyboardView.height(rowHeight: rowHeight)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 시스템의 화면 가장자리 제스처가 터치를 붙잡았다 늦게 넘겨서 양 끝 키가 굼떠진다.
        var current: UIView? = view
        while let v = current {
            v.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
            current = v.superview
        }
        view.window?.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        model.documentChanged()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        model.documentChanged()
    }
}
