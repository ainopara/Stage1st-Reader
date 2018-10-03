//
//  LoginViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 5/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import SnapKit
import ActionSheetPicker_3_0
import OnePasswordExtension

private class UserInfoInputView: UIView {
    let usernameField = UITextField(frame: CGRect.zero)
    let passwordField = UITextField(frame: CGRect.zero)
    let onepasswordButton = UIButton(type: .system)
    let questionSelectButton = UIButton(type: .system)
    let answerField = UITextField(frame: CGRect.zero)
    let loginButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        usernameField.borderStyle = .line
        usernameField.autocorrectionType = .no
        usernameField.autocapitalizationType = .none
        usernameField.returnKeyType = .next
        usernameField.backgroundColor = UIColor.white
        addSubview(usernameField)

        usernameField.snp.makeConstraints { make in
            make.width.equalTo(300.0)
            make.height.equalTo(30.0)
            make.top.equalTo(self.snp.top).offset(20.0)
            make.centerX.equalTo(self.snp.centerX)
            make.leading.equalTo(self.snp.leading).offset(5.0)
        }

        passwordField.borderStyle = .line
        passwordField.isSecureTextEntry = true
        passwordField.returnKeyType = .go
        passwordField.backgroundColor = UIColor.white
        addSubview(passwordField)

        passwordField.snp.makeConstraints { make in
            make.width.equalTo(self.usernameField.snp.width)
            make.height.equalTo(30.0)
            make.centerX.equalTo(self.usernameField.snp.centerX)
            make.top.equalTo(self.usernameField.snp.bottom).offset(12.0)
        }

        onepasswordButton.setImage(UIImage(named: "OnePasswordButton"), for: .normal)
        onepasswordButton.tintColor = AppEnvironment.current.colorManager.colorForKey("default.text.tint")

        let buttonContainer = UIView(frame: CGRect.zero)
        buttonContainer.snp.makeConstraints { make in
            make.height.equalTo(24.0)
            make.width.equalTo(28.0)
        }
        buttonContainer.addSubview(onepasswordButton)

        onepasswordButton.snp.makeConstraints { make in
            make.top.leading.bottom.equalTo(buttonContainer)
            make.trailing.equalTo(buttonContainer).offset(-4.0)
        }
        passwordField.rightView = buttonContainer
        passwordField.rightViewMode = OnePasswordExtension.shared().isAppExtensionAvailable() ? .always : .never

        addSubview(questionSelectButton)

        questionSelectButton.snp.makeConstraints { make in
            make.width.centerX.equalTo(self.usernameField)
            make.height.equalTo(30.0)
            make.top.equalTo(self.passwordField.snp.bottom).offset(12.0)
        }

        answerField.borderStyle = .line
        answerField.autocorrectionType = .no
        answerField.autocapitalizationType = .none
        // Note: The ability of input chinese characters is necessary. Detail: http://stackoverflow.com/questions/9944769/why-cant-i-use-securetextentry-with-a-utf-8-keyboard
        //        answerField.isSecureTextEntry = true
        answerField.returnKeyType = .go
        answerField.backgroundColor = UIColor.white
        addSubview(answerField)

        answerField.snp.makeConstraints { make in
            make.width.centerX.equalTo(self.questionSelectButton)
            make.height.equalTo(30.0)
            make.top.equalTo(self.questionSelectButton.snp.bottom).offset(12.0)
        }

        addSubview(loginButton)

        loginButton.snp.makeConstraints { make in
            make.width.centerX.equalTo(self.usernameField)
            make.height.equalTo(34.0)
            make.bottom.equalTo(self.snp.bottom).offset(-12.0)
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class SeccodeInputView: UIView {
    let seccodeImageView = UIImageView(image: nil)
    let seccodeField = UITextField(frame: CGRect.zero)
    let seccodeSubmitButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(seccodeImageView)
        seccodeImageView.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.top.equalTo(self.snp.top).offset(10.0)
            make.width.equalTo(100.0)
            make.height.equalTo(40.0)
        }

        seccodeField.borderStyle = .line
        seccodeField.autocorrectionType = .no
        seccodeField.autocapitalizationType = .none
        seccodeField.returnKeyType = .go
        addSubview(seccodeField)
        seccodeField.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.width.equalTo(self.snp.width).offset(-24.0)
            make.top.equalTo(self.seccodeImageView.snp.bottom).offset(10.0)
        }

        addSubview(seccodeSubmitButton)
        seccodeSubmitButton.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.width.equalTo(self.snp.width).offset(-24.0)
            make.bottom.equalTo(self.snp.bottom).offset(-10.0)
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class LoginViewController: UIViewController, CardWithBlurredBackground {

    let backgroundBlurView = UIVisualEffectView(effect: nil)
    let containerView = UIView(frame: CGRect.zero)

    private let userInfoInputView = UserInfoInputView(frame: .zero)
    private let seccodeInputView = SeccodeInputView(frame: .zero)

    private let visibleLayoutGuide = UIView(frame: CGRect.zero)

    private var dynamicAnimator: UIDynamicAnimator?
    private var snapBehavior: UISnapBehavior?
    private var dynamicItemBehavior: UIDynamicItemBehavior?
    private var attachmentBehavior: UIAttachmentBehavior?
    private var dragGesture: UIPanGestureRecognizer?
    private var tapGesture: UITapGestureRecognizer?

    private var loginButtonTopConstraint: Constraint?

    private let networkManager: DiscuzClient
    private var sechash: String?

    enum State {
        case notLogin
        case notLoginWithAnswerField
        case login
    }

    private var state: State = .notLogin {
        didSet {
            switch state {
            case .notLogin:
                userInfoInputView.usernameField.isEnabled = true
                userInfoInputView.passwordField.alpha = 1.0
                userInfoInputView.questionSelectButton.alpha = 1.0
                userInfoInputView.answerField.alpha = 0.0

                userInfoInputView.passwordField.returnKeyType = .go
                userInfoInputView.loginButton.setTitle(NSLocalizedString("SettingsViewController.LogIn", comment: "LogIn"), for: .normal)
                loginButtonTopConstraint?.deactivate()
                userInfoInputView.loginButton.snp.remakeConstraints { make in
                    make.width.centerX.equalTo(self.userInfoInputView.usernameField)
                    make.height.equalTo(34.0)
                    make.bottom.equalTo(self.userInfoInputView.snp.bottom).offset(-12.0)

                    self.loginButtonTopConstraint = make.top.equalTo(self.userInfoInputView.questionSelectButton.snp.bottom).offset(12.0).constraint
                }
                dynamicAnimator?.removeAllBehaviors()
                containerView.setNeedsLayout()
            case .notLoginWithAnswerField:
                userInfoInputView.usernameField.isEnabled = true
                userInfoInputView.passwordField.alpha = 1.0
                userInfoInputView.questionSelectButton.alpha = 1.0
                userInfoInputView.answerField.alpha = 1.0

                userInfoInputView.passwordField.returnKeyType = .next
                userInfoInputView.loginButton.setTitle(NSLocalizedString("SettingsViewController.LogIn", comment: "LogIn"), for: .normal)
                loginButtonTopConstraint?.deactivate()
                userInfoInputView.loginButton.snp.remakeConstraints { make in
                    make.width.centerX.equalTo(self.userInfoInputView.usernameField)
                    make.height.equalTo(34.0)
                    make.bottom.equalTo(self.userInfoInputView.snp.bottom).offset(-12.0)

                    self.loginButtonTopConstraint = make.top.equalTo(self.userInfoInputView.answerField.snp.bottom).offset(12.0).constraint
                }
                dynamicAnimator?.removeAllBehaviors()
                containerView.setNeedsLayout()
            case .login:
                userInfoInputView.usernameField.isEnabled = false
                userInfoInputView.passwordField.alpha = 0.0
                userInfoInputView.questionSelectButton.alpha = 0.0
                userInfoInputView.answerField.alpha = 0.0

                userInfoInputView.loginButton.setTitle(NSLocalizedString("SettingsViewController.LogOut", comment: "LogOut"), for: .normal)
                loginButtonTopConstraint?.deactivate()
                userInfoInputView.loginButton.snp.remakeConstraints { make in
                    make.width.centerX.equalTo(self.userInfoInputView.usernameField)
                    make.height.equalTo(34.0)
                    make.bottom.equalTo(self.userInfoInputView.snp.bottom).offset(-12.0)

                    self.loginButtonTopConstraint = make.top.equalTo(self.userInfoInputView.usernameField.snp.bottom).offset(12.0).constraint
                }
                dynamicAnimator?.removeAllBehaviors()
                containerView.setNeedsLayout()
            }
        }
    }

    private let secureQuestionChoices = [
        "安全提问（未设置请忽略）",
        "母亲的名字",
        "爷爷的名字",
        "父亲出生的城市",
        "您其中一位老师的名字",
        "您个人计算机的型号",
        "您最喜欢的餐馆名称",
        "驾驶执照最后四位数字",
    ]

    // MARK: - Life Cycle

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        networkManager = AppEnvironment.current.apiService
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }

        containerView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("login.background")
        containerView.layer.cornerRadius = 4.0
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        userInfoInputView.usernameField.delegate = self
        userInfoInputView.usernameField.placeholder = NSLocalizedString("LoginViewController.usernameField.placeholder", comment: "")
        userInfoInputView.usernameField.text = self.inLoginStateID() ?? ""
        userInfoInputView.passwordField.delegate = self
        userInfoInputView.passwordField.placeholder = NSLocalizedString("LoginViewController.passwordField.placeholder", comment: "")
        userInfoInputView.onepasswordButton.addTarget(self, action: #selector(LoginViewController.findLoginFromOnePassword(_:)), for: .touchUpInside)
        userInfoInputView.questionSelectButton.setTitle("安全提问（未设置请忽略）", for: .normal)
        userInfoInputView.questionSelectButton.tintColor = AppEnvironment.current.colorManager.colorForKey("login.text")
        userInfoInputView.questionSelectButton.addTarget(self, action: #selector(LoginViewController.selectSecureQuestion(_:)), for: .touchUpInside)
        userInfoInputView.answerField.delegate = self
        userInfoInputView.loginButton.addTarget(self, action: #selector(LoginViewController.logIn(_:)), for: .touchUpInside)
        userInfoInputView.loginButton.backgroundColor = AppEnvironment.current.colorManager.colorForKey("login.button")
        userInfoInputView.loginButton.tintColor = AppEnvironment.current.colorManager.colorForKey("login.text")

        containerView.addSubview(userInfoInputView)
        userInfoInputView.snp.makeConstraints { make in
            make.edges.equalTo(self.containerView)
        }

        view.insertSubview(visibleLayoutGuide, at: 0)
        visibleLayoutGuide.isUserInteractionEnabled = false
        visibleLayoutGuide.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }

        seccodeInputView.isHidden = true
        seccodeInputView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("login.background")

        containerView.addSubview(seccodeInputView)
        seccodeInputView.snp.makeConstraints { make in
            make.edges.equalTo(containerView)
        }

        seccodeInputView.seccodeField.delegate = self
        seccodeInputView.seccodeField.backgroundColor = UIColor.white
        seccodeInputView.seccodeSubmitButton.setTitle("提交", for: .normal)
        seccodeInputView.seccodeSubmitButton.backgroundColor = AppEnvironment.current.colorManager.colorForKey("login.button")
        seccodeInputView.seccodeSubmitButton.addTarget(self, action: #selector(LoginViewController.logInWithSeccode(_:)), for: .touchUpInside)

        state = inLoginState() ? .login : .notLogin

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(_dismiss))
        self.tapGesture = tapGesture
        backgroundBlurView.addGestureRecognizer(tapGesture)

        let dynamicAnimator = UIDynamicAnimator(referenceView: view)
        self.dynamicAnimator = dynamicAnimator

        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(LoginViewController.pan(_:)))
        view.addGestureRecognizer(dragGesture)
        self.dragGesture = dragGesture

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(LoginViewController.keyboardFrameWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        containerView.center = expectedCenterOfContainerView()
        if let dynamicAnimator = self.dynamicAnimator {
            // update snap point
            if let snapBehavior = self.snapBehavior {
                snapBehavior.snapPoint = expectedCenterOfContainerView()
            } else {
                let snapBehavior = UISnapBehavior(item: containerView, snapTo: expectedCenterOfContainerView())
                dynamicAnimator.addBehavior(snapBehavior)
                self.snapBehavior = snapBehavior
            }
        }
    }
}

// MARK: - Actions
extension LoginViewController {

    @objc func logIn(_: UIButton) {
        if inLoginState() {
            AppEnvironment.current.eventTracker.logEvent(with: "Log Out")
            logoutAction()
        } else {
            AppEnvironment.current.eventTracker.logEvent(with: "Log In")
            loginAction()
        }
    }

    @objc func logInWithSeccode(_: UIButton) {
        let username = currentUsername()
        let password = currentPassword()
        guard username != "" && password != "" else {
            alert(title: NSLocalizedString("SettingsViewController.LogIn", comment: ""), message: "用户名和密码不能为空")
            return
        }
        seccodeInputView.seccodeSubmitButton.isEnabled = false
        let authMode: DiscuzClient.AuthMode = .secure(hash: currentSechash(), code: currentSeccode())
        networkManager.logIn(username: username, password: password, secureQuestionNumber: currentSecureQuestionNumber(), secureQuestionAnswer: currentSecureQuestionAnswer(), authMode: authMode) { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case let .success(message):
                strongSelf.seccodeInputView.seccodeSubmitButton.isEnabled = true
                strongSelf.state = .login
                let alertController = UIAlertController(title: NSLocalizedString("SettingsViewController.LogIn", comment: ""), message: message ?? "登录成功", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment: ""), style: .cancel, handler: { _ in
                    strongSelf._dismiss()
                }))
                strongSelf.present(alertController, animated: true, completion: nil)
            case let .failure(error):
                strongSelf.seccodeInputView.seccodeSubmitButton.isEnabled = true
                strongSelf.alert(title: NSLocalizedString("SettingsViewController.LogIn", comment: ""), message: error.localizedDescription)
            }
        }
    }

    @objc func findLoginFromOnePassword(_ button: UIButton) {
        OnePasswordExtension.shared().findLogin(forURLString: AppEnvironment.current.serverAddress.main, for: self, sender: button) { [weak self] loginDict, error in
            guard let strongSelf = self else {
                return
            }
            guard let loginDict = loginDict else {
                return
            }
            if let error = error as NSError?, error.code != Int(AppExtensionErrorCodeCancelledByUser) {
                S1LogInfo("Error invoking 1Password App Extension for find login: \(error)")
                return
            }

            strongSelf.userInfoInputView.usernameField.text = loginDict[AppExtensionUsernameKey] as? String ?? ""
            strongSelf.userInfoInputView.passwordField.text = loginDict[AppExtensionPasswordKey] as? String ?? ""
            strongSelf.logIn(button)
        }
    }

    @objc func selectSecureQuestion(_ button: UIButton) {
        S1LogDebug("debug secure question")
        view.endEditing(true)
        // TODO: Make action sheet picker a view controller to avoid keyboard overlay.
        let picker = ActionSheetStringPicker(title: "安全提问", rows: secureQuestionChoices, initialSelection: currentSecureQuestionNumber(), doneBlock: { _, selectedIndex, selectedValue in
            button.setTitle(selectedValue as? String ?? "??", for: .normal)
            if selectedIndex == 0 {
                self.state = .notLogin
            } else {
                self.state = .notLoginWithAnswerField
            }
        }, cancel: nil, origin: button)!
        picker.toolbarBackgroundColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.bartint")
        picker.toolbarButtonsColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.tint")
        picker.show()
    }

    @objc func _dismiss() {
        if let presentingViewController = self.presentingViewController {
            presentingViewController.dismiss(animated: true, completion: nil)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    @objc func keyboardFrameWillChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
        else {
            return
        }

        let keyboardHeightInView = view.bounds.maxY - endFrame.minY
        S1LogDebug("[LoginVC] keytboard height: \(keyboardHeightInView)")
        visibleLayoutGuide.snp.updateConstraints { make in
            make.bottom.equalTo(self.view).offset(-keyboardHeightInView)
        }
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == userInfoInputView.usernameField {
            userInfoInputView.passwordField.becomeFirstResponder()
        } else if textField == userInfoInputView.passwordField {
            switch state {
            case .notLogin:
                textField.resignFirstResponder()
                logIn(userInfoInputView.loginButton)
            case .notLoginWithAnswerField:
                userInfoInputView.answerField.becomeFirstResponder()
            case .login:
                break
            }
        } else if textField == userInfoInputView.answerField {
            textField.resignFirstResponder()
            logIn(userInfoInputView.loginButton)
        } else if textField === seccodeInputView.seccodeField {
            textField.resignFirstResponder()
            logInWithSeccode(seccodeInputView.seccodeSubmitButton)
        }
        return true
    }
}

// MARK: UIViewControllerTransitioningDelegate

extension LoginViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented _: UIViewController, presenting _: UIViewController, source _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return S1ModalAnimator(presentType: .present)
    }

    func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return S1ModalAnimator(presentType: .dismissal)
    }
}

// MARK: Login Logic

extension LoginViewController {
    fileprivate func loginAction() {
        let username = currentUsername()
        let password = currentPassword()

        guard username != "" && password != "" else {
            alert(title: NSLocalizedString("SettingsViewController.LogIn", comment: ""), message: "用户名和密码不能为空")
            return
        }

        let secureQuestionNumber = currentSecureQuestionNumber()
        let secureQuestionAnswer = currentSecureQuestionAnswer()

        userInfoInputView.loginButton.isEnabled = false
        networkManager.checkLoginType(noSechashBlock: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.networkManager.logIn(username: username, password: password, secureQuestionNumber: secureQuestionNumber, secureQuestionAnswer: secureQuestionAnswer, authMode: .basic) { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case let .success(message):
                    strongSelf.userInfoInputView.loginButton.isEnabled = true
                    AppEnvironment.current.settings.currentUsername.value = username
                    strongSelf.state = .login
                    let alertController = UIAlertController(title: NSLocalizedString("SettingsViewController.LogIn", comment: ""), message: message ?? "登录成功", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment: ""), style: .cancel, handler: { _ in
                        strongSelf._dismiss()
                    }))
                    strongSelf.present(alertController, animated: true, completion: nil)
                case let .failure(error):
                    strongSelf.userInfoInputView.loginButton.isEnabled = true
                    strongSelf.alert(title: NSLocalizedString("SettingsViewController.LogIn", comment: ""), message: "\(error)")
                }
            }
        }, hasSeccodeBlock: { [weak self] sechash in
            guard let strongSelf = self else { return }
            strongSelf.userInfoInputView.loginButton.isEnabled = true

            strongSelf.sechash = sechash
            strongSelf.seccodeInputView.isHidden = false
            strongSelf.networkManager.getSeccodeImage(sechash: sechash) { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case let .success(image):
                    strongSelf.seccodeInputView.seccodeImageView.image = image
                case let .failure(error):
                    strongSelf.alert(title: "下载验证码失败", message: error.localizedDescription)
                    strongSelf.userInfoInputView.loginButton.isEnabled = true
                }
            }

        }, failureBlock: { [weak self] error in
            guard let strongSelf = self else { return }
            strongSelf.userInfoInputView.loginButton.isEnabled = true
            strongSelf.alert(title: NSLocalizedString("SettingsViewController.LogIn", comment: ""), message: error.localizedDescription)
        })
    }

    fileprivate func logoutAction() {
        networkManager.logOut()
        state = .notLogin
        alert(
            title: NSLocalizedString("SettingsViewController.LogOut", comment: ""),
            message: NSLocalizedString("LoginViewController.Logout_Message", comment: "")
        )
    }
}

// MARK: Helper

extension LoginViewController {
    fileprivate func alert(title: String, message: String) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(
            title: NSLocalizedString("Message_OK", comment: ""),
            style: .cancel,
            handler: nil)
        )
        present(alertController, animated: true, completion: nil)
    }

    @objc func pan(_ gesture: UIPanGestureRecognizer) {
        guard let dynamicAnimator = dynamicAnimator else { return }

        switch gesture.state {
        case .began:
            S1LogInfo("before: \(containerView.center)")
            let centerOfCurrentContainerView = containerView.center
            dynamicAnimator.removeAllBehaviors() // containerView.center will changed immdediately when doing this since iOS 10
            containerView.center = centerOfCurrentContainerView
            S1LogDebug("[LoginVC] pan location begin \(gesture.location(in: self.view))")
            attachmentBehavior = UIAttachmentBehavior(item: containerView,
                                                      offsetFromCenter: offsetFromCenter(gesture.location(in: view), viewCenter: centerOfCurrentContainerView),
                                                      attachedToAnchor: gesture.location(in: view))
            S1LogInfo("after: \(containerView.center)")
            dynamicAnimator.addBehavior(attachmentBehavior!)
            dynamicItemBehavior = UIDynamicItemBehavior(items: [containerView])
            dynamicAnimator.addBehavior(dynamicItemBehavior!)

        case .changed:
            S1LogDebug("[LoginVC] pan location \(gesture.location(in: self.view))")
            attachmentBehavior?.anchorPoint = gesture.location(in: view)
        default:
            let velocity = gesture.velocity(in: view)
            S1LogVerbose("[LoginVC] pan velocity: \(velocity)")
            if velocity.x * velocity.x + velocity.y * velocity.y > 1_000_000 {
                if let attachmentBehavior = attachmentBehavior {
                    dynamicAnimator.removeBehavior(attachmentBehavior)
                }
                S1LogVerbose("[LoginVC] dismiss triggered with original velocity: \(String(describing: dynamicItemBehavior?.linearVelocity(for: containerView)))")
                dynamicItemBehavior?.addLinearVelocity(velocity, for: containerView)
                dynamicItemBehavior?.action = { [weak self] in
                    guard let strongSelf = self else { return }
                    if let items = strongSelf.dynamicAnimator?.items(in: strongSelf.view.bounds), items.count == 0 {
                        if !strongSelf.isBeingDismissed {
                            strongSelf._dismiss()
                        }
                    }
                }
            } else {
                let centerOfCurrentContainerView = containerView.center
                dynamicAnimator.removeAllBehaviors() // containerView.center will changed immdediately when doing this since iOS 10
                containerView.center = centerOfCurrentContainerView
                if let snapBehavior = self.snapBehavior {
                    dynamicAnimator.addBehavior(snapBehavior)
                }
            }
        }
    }

    fileprivate func expectedCenterOfContainerView() -> CGPoint {
        return CGPoint(x: visibleLayoutGuide.center.x, y: visibleLayoutGuide.center.y)
    }

    fileprivate func offsetFromCenter(_ touchPointInView: CGPoint, viewCenter: CGPoint) -> UIOffset {
        return UIOffset(horizontal: touchPointInView.x - viewCenter.x, vertical: touchPointInView.y - viewCenter.y)
    }
}

// MARK: View Model
extension LoginViewController {

    fileprivate func currentSecureQuestionNumber() -> Int {
        if let text = userInfoInputView.questionSelectButton.currentTitle, let index = self.secureQuestionChoices.index(of: text) {
            return index
        } else {
            return 0
        }
    }

    fileprivate func currentSecureQuestionAnswer() -> String {
        if currentSecureQuestionNumber() == 0 {
            return ""
        } else {
            return userInfoInputView.answerField.text ?? ""
        }
    }

    fileprivate func currentSechash() -> String {
        return sechash ?? ""
    }

    fileprivate func currentSeccode() -> String {
        return seccodeInputView.seccodeField.text ?? ""
    }

    fileprivate func currentUsername() -> String {
        return userInfoInputView.usernameField.text ?? ""
    }

    fileprivate func currentPassword() -> String {
        return userInfoInputView.passwordField.text ?? ""
    }

    fileprivate func inLoginStateID() -> String? {
        return AppEnvironment.current.settings.currentUsername.value
    }

    fileprivate func inLoginState() -> Bool {
        return inLoginStateID() != nil
    }
}
