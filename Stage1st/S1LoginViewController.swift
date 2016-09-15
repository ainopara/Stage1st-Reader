//
//  S1LoginViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 5/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import SnapKit
import ActionSheetPicker_3_0
import OnePasswordExtension
import CocoaLumberjack

private enum LoginViewControllerState {
    case notLogin
    case notLoginWithAnswerField
    case login
}

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
        self.addSubview(usernameField)

        usernameField.snp.makeConstraints { (make) in
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
        self.addSubview(passwordField)

        passwordField.snp.makeConstraints { (make) in
            make.width.equalTo(self.usernameField.snp.width)
            make.height.equalTo(30.0)
            make.centerX.equalTo(self.usernameField.snp.centerX)
            make.top.equalTo(self.usernameField.snp.bottom).offset(12.0)
        }

        onepasswordButton.setImage(UIImage(named: "OnePasswordButton"), for: UIControlState())
        onepasswordButton.tintColor = APColorManager.sharedInstance.colorForKey("default.text.tint")

        let buttonContainer = UIView(frame: CGRect.zero)
        buttonContainer.snp.makeConstraints { (make) in
            make.height.equalTo(24.0)
            make.width.equalTo(28.0)
        }
        buttonContainer.addSubview(onepasswordButton)

        onepasswordButton.snp.makeConstraints { (make) in
            make.top.leading.bottom.equalTo(buttonContainer)
            make.trailing.equalTo(buttonContainer).offset(-4.0)
        }
        passwordField.rightView = buttonContainer
        passwordField.rightViewMode = OnePasswordExtension.shared().isAppExtensionAvailable() ? .always : .never

        self.addSubview(questionSelectButton)

        self.questionSelectButton.snp.makeConstraints { (make) in
            make.width.centerX.equalTo(self.usernameField)
            make.height.equalTo(30.0)
            make.top.equalTo(self.passwordField.snp.bottom).offset(12.0)
        }

        answerField.borderStyle = .line
        answerField.autocorrectionType = .no
        answerField.autocapitalizationType = .none
        answerField.isSecureTextEntry = true
        answerField.returnKeyType = .go
        answerField.backgroundColor = UIColor.white
        self.addSubview(answerField)

        answerField.snp.makeConstraints { (make) in
            make.width.centerX.equalTo(self.questionSelectButton)
            make.height.equalTo(30.0)
            make.top.equalTo(self.questionSelectButton.snp.bottom).offset(12.0)
        }

        self.addSubview(loginButton)

        loginButton.snp.makeConstraints { (make) in
            make.width.centerX.equalTo(self.usernameField)
            make.height.equalTo(34.0)
            make.bottom.equalTo(self.snp.bottom).offset(-12.0)
        }


    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class SeccodeInputView: UIView {
    let seccodeImageView = UIImageView(image: nil)
    let seccodeField = UITextField(frame: CGRect.zero)
    let seccodeSubmitButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.seccodeImageView)
        seccodeImageView.snp.makeConstraints { (make) in
            make.centerX.equalTo(self)
            make.top.equalTo(self.snp.top).offset(10.0)
            make.width.equalTo(100.0)
            make.height.equalTo(40.0)
        }

        seccodeField.borderStyle = .line
        seccodeField.autocorrectionType = .no
        seccodeField.autocapitalizationType = .none
        seccodeField.returnKeyType = .go
        self.addSubview(self.seccodeField)
        seccodeField.snp.makeConstraints { (make) in
            make.centerX.equalTo(self)
            make.width.equalTo(self.snp.width).offset(-24.0)
            make.top.equalTo(self.seccodeImageView.snp.bottom).offset(10.0)
        }

        self.addSubview(self.seccodeSubmitButton)
        seccodeSubmitButton.snp.makeConstraints { (make) in
            make.centerX.equalTo(self)
            make.width.equalTo(self.snp.width).offset(-24.0)
            make.bottom.equalTo(self.snp.bottom).offset(-10.0)
        }

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class S1LoginViewController: UIViewController {

    fileprivate let backgroundBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    fileprivate let containerView = UIView(frame: CGRect.zero)

    fileprivate let userInfoInputView = UserInfoInputView(frame: .zero)
    fileprivate let seccodeInputView = SeccodeInputView(frame: .zero)

    fileprivate let visibleLayoutGuide = UIView(frame: CGRect.zero)

    fileprivate var dynamicAnimator: UIDynamicAnimator?
    fileprivate var snapBehavior: UISnapBehavior?
    fileprivate var dynamicItemBehavior: UIDynamicItemBehavior?
    fileprivate var attachmentBehavior: UIAttachmentBehavior?
    fileprivate var dragGesture: UIPanGestureRecognizer?
    fileprivate var tapGesture: UITapGestureRecognizer?

    fileprivate var loginButtonTopConstraint: Constraint?

    fileprivate let networkManager: DiscuzAPIManager
    fileprivate var sechash: String?

    fileprivate var state: LoginViewControllerState = .notLogin {
        didSet {
            switch state {
            case .notLogin:
                userInfoInputView.usernameField.isEnabled = true
                userInfoInputView.passwordField.alpha = 1.0
                userInfoInputView.questionSelectButton.alpha = 1.0
                userInfoInputView.answerField.alpha = 0.0

                userInfoInputView.passwordField.returnKeyType = .go
                userInfoInputView.loginButton.setTitle(NSLocalizedString("SettingView_LogIn", comment: "LogIn"), for: UIControlState())
                loginButtonTopConstraint?.uninstall()
                userInfoInputView.loginButton.snp.makeConstraints { (make) in
                    self.loginButtonTopConstraint = make.top.equalTo(self.userInfoInputView.questionSelectButton.snp.bottom).offset(12.0).constraint
                }
            case .notLoginWithAnswerField:
                userInfoInputView.usernameField.isEnabled = true
                userInfoInputView.passwordField.alpha = 1.0
                userInfoInputView.questionSelectButton.alpha = 1.0
                userInfoInputView.answerField.alpha = 1.0

                userInfoInputView.passwordField.returnKeyType = .next
                userInfoInputView.loginButton.setTitle(NSLocalizedString("SettingView_LogIn", comment: "LogIn"), for: UIControlState())
                loginButtonTopConstraint?.uninstall()
                userInfoInputView.loginButton.snp.updateConstraints { (make) in
                    self.loginButtonTopConstraint = make.top.equalTo(self.userInfoInputView.answerField.snp.bottom).offset(12.0).constraint
                }
            case .login:
                userInfoInputView.usernameField.isEnabled = false
                userInfoInputView.passwordField.alpha = 0.0
                userInfoInputView.questionSelectButton.alpha = 0.0
                userInfoInputView.answerField.alpha = 0.0

                userInfoInputView.loginButton.setTitle(NSLocalizedString("SettingView_LogOut", comment: "LogOut"), for: UIControlState())
                loginButtonTopConstraint?.uninstall()
                userInfoInputView.loginButton.snp.updateConstraints { (make) in
                    self.loginButtonTopConstraint = make.top.equalTo(self.userInfoInputView.usernameField.snp.bottom).offset(12.0).constraint
                }
            }
        }
    }

    let secureQuestionChoices = [
        "安全提问（未设置请忽略）",
        "母亲的名字",
        "爷爷的名字",
        "父亲出生的城市",
        "您其中一位老师的名字",
        "您个人计算机的型号",
        "您最喜欢的餐馆名称",
        "驾驶执照最后四位数字"
    ]

    // MARK: -
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.networkManager = DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b")  // FIXME: base URL should not be hard coded.
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }

        containerView.backgroundColor = APColorManager.sharedInstance.colorForKey("login.background")
        containerView.layer.cornerRadius = 4.0
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(containerView)

        userInfoInputView.usernameField.delegate = self
        userInfoInputView.usernameField.placeholder = NSLocalizedString("S1LoginViewController.usernameField.placeholder", comment: "")
        userInfoInputView.usernameField.text = self.cachedUserID() ?? ""
        userInfoInputView.passwordField.delegate = self
        userInfoInputView.passwordField.placeholder = NSLocalizedString("S1LoginViewController.passwordField.placeholder", comment: "")
        userInfoInputView.onepasswordButton.addTarget(self, action: #selector(S1LoginViewController.findLoginFromOnePassword(_:)), for: .touchUpInside)
        userInfoInputView.questionSelectButton.setTitle("安全提问（未设置请忽略）", for: UIControlState())
        userInfoInputView.questionSelectButton.tintColor = APColorManager.sharedInstance.colorForKey("login.text")
        userInfoInputView.questionSelectButton.addTarget(self, action: #selector(S1LoginViewController.selectSecureQuestion(_:)), for: .touchUpInside)
        userInfoInputView.answerField.delegate = self
        userInfoInputView.loginButton.addTarget(self, action: #selector(S1LoginViewController.logIn(_:)), for: .touchUpInside)
        userInfoInputView.loginButton.backgroundColor = APColorManager.sharedInstance.colorForKey("login.button")
        userInfoInputView.loginButton.tintColor = APColorManager.sharedInstance.colorForKey("login.text")

        containerView.addSubview(userInfoInputView)
        userInfoInputView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }

        self.view.insertSubview(visibleLayoutGuide, at: 0)
        visibleLayoutGuide.isUserInteractionEnabled = false
        visibleLayoutGuide.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }

        seccodeInputView.isHidden = true
        seccodeInputView.backgroundColor = APColorManager.sharedInstance.colorForKey("login.background")

        containerView.addSubview(seccodeInputView)
        seccodeInputView.snp.makeConstraints { (make) in
            make.edges.equalTo(containerView)
        }

        seccodeInputView.seccodeField.delegate = self
        seccodeInputView.seccodeField.backgroundColor = UIColor.white
        seccodeInputView.seccodeSubmitButton.setTitle("提交", for: UIControlState())
        seccodeInputView.seccodeSubmitButton.backgroundColor = APColorManager.sharedInstance.colorForKey("login.button")
        seccodeInputView.seccodeSubmitButton.addTarget(self, action: #selector(S1LoginViewController.LogInWithSeccode(_:)), for: .touchUpInside)

        state = self.inLoginState() ? .login : .notLogin

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(S1LoginViewController.dismiss))
        self.tapGesture = tapGesture
        self.backgroundBlurView.addGestureRecognizer(tapGesture)

        let dynamicAnimator = UIDynamicAnimator(referenceView: self.view)
        self.dynamicAnimator = dynamicAnimator

        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(S1LoginViewController.pan(_:)))
        self.view.addGestureRecognizer(dragGesture)
        self.dragGesture = dragGesture

        NotificationCenter.default.addObserver(self, selector: #selector(S1LoginViewController.keyboardFrameWillChange(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        containerView.center = centerOfContainerView()
        if let dynamicAnimator = self.dynamicAnimator {
            // update snap point
            if #available(iOS 9, *) {
                if let snapBehavior = self.snapBehavior {
                    snapBehavior.snapPoint = centerOfContainerView()
                } else {
                    let snapBehavior = UISnapBehavior(item: containerView, snapTo: centerOfContainerView())
                    dynamicAnimator.addBehavior(snapBehavior)
                    self.snapBehavior = snapBehavior
                }
            } else {
                dynamicAnimator.removeAllBehaviors()
                let snapBehavior = UISnapBehavior(item: containerView, snapTo: centerOfContainerView())
                dynamicAnimator.addBehavior(snapBehavior)
                self.snapBehavior = snapBehavior
            }
        }
    }
}

// MARK: - Actions
extension S1LoginViewController {

    func logIn(_ sender: UIButton) {
        if self.inLoginState() {
            self.logoutAction()
        } else {
            self.loginAction()
        }
    }

    func LogInWithSeccode(_ sender: UIButton) {
        let username = currentUsername()
        let password = currentPassword()
        guard username != "" && password != "" else {
            self.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: "用户名和密码不能为空")
            return
        }
        self.seccodeInputView.seccodeSubmitButton.isEnabled = false
        networkManager.logIn(username, password: password, secureQuestionNumber: currentSecureQuestionNumber(), secureQuestionAnswer: currentSecureQuestionAnswer(), authMode: .Secure(hash: currentSechash(), code: currentSeccode()), successBlock: { [weak self] (message) in
            guard let strongSelf = self else { return }
            strongSelf.seccodeInputView.seccodeSubmitButton.enabled = true
            NSUserDefaults.standardUserDefaults().setObject(username, forKey: "InLoginStateID")
            strongSelf.state = .Login
            let alertController = UIAlertController(title: NSLocalizedString("SettingView_LogIn", comment:""), message: message ?? "登录成功", preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment:""), style: .Cancel, handler: { action in
                strongSelf.dismiss()
            }))
            strongSelf.presentViewController(alertController, animated: true, completion: nil)
            }) { [weak self] (error) in
                guard let strongSelf = self else { return }
                strongSelf.seccodeInputView.seccodeSubmitButton.enabled = true
                strongSelf.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: error.localizedDescription)
        }
    }

    func findLoginFromOnePassword(_ button: UIButton) {
        OnePasswordExtension.shared().findLogin(forURLString: UserDefaults.standard.object(forKey: "BaseURL") as? String ?? "", for: self, sender: button) { [weak self] (loginDict, error) in
            guard let strongSelf = self else {
                return
            }
            guard let loginDict = loginDict else {
                return
            }
            if let error = error , error.code != Int(AppExtensionErrorCodeCancelledByUser) {
                DDLogInfo("Error invoking 1Password App Extension for find login: \(error)")
                return
            }

            strongSelf.userInfoInputView.usernameField.text = loginDict[AppExtensionUsernameKey] as? String ?? ""
            strongSelf.userInfoInputView.passwordField.text = loginDict[AppExtensionPasswordKey] as? String ?? ""
        }
    }

    func selectSecureQuestion(_ button: UIButton) {
        DDLogDebug("debug secure question")
        self.view.endEditing(true)
        // TODO: Make action sheet picker a view controller to avoid keyboard overlay.
        let picker = ActionSheetStringPicker(title: "安全提问", rows: secureQuestionChoices, initialSelection: currentSecureQuestionNumber(), doneBlock: { (pciker, selectedIndex, selectedValue) in
                button.setTitle(selectedValue as? String ?? "??", for: UIControlState())
                if selectedIndex == 0 {
                    self.state = .notLogin
                } else {
                    self.state = .notLoginWithAnswerField
                }
            }, cancel: nil, origin: button)!
        picker.toolbarBackgroundColor = APColorManager.sharedInstance.colorForKey("appearance.toolbar.bartint")
        picker.toolbarButtonsColor = APColorManager.sharedInstance.colorForKey("appearance.toolbar.tint")
        picker.show()
    }

    func dismiss() {
        if let presentingViewController = self.presentingViewController {
            presentingViewController.dismiss(animated: true, completion: nil)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    func keyboardFrameWillChange(_ notification: Notification) {
        guard let userInfo = (notification as NSNotification).userInfo, let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue else { return }

        let keyboardHeightInView = self.view.bounds.maxY - endFrame.minY
        DDLogDebug("[LoginVC] keytboard height: \(keyboardHeightInView)")
        visibleLayoutGuide.snp.updateConstraints { (make) in
            make.bottom.equalTo(self.view).offset(-keyboardHeightInView)
        }
    }
}

// MARK: - UITextFieldDelegate
extension S1LoginViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == userInfoInputView.usernameField {
            userInfoInputView.passwordField.becomeFirstResponder()
        } else if textField == userInfoInputView.passwordField {
            switch state {
            case .notLogin:
                textField.resignFirstResponder()
                self.logIn(userInfoInputView.loginButton)
            case .notLoginWithAnswerField:
                userInfoInputView.answerField.becomeFirstResponder()
            case .login:
                break
            }
        } else if textField == userInfoInputView.answerField {
            textField.resignFirstResponder()
            self.logIn(userInfoInputView.loginButton)
        } else if textField === seccodeInputView.seccodeField {
            textField.resignFirstResponder()
            self.LogInWithSeccode(seccodeInputView.seccodeSubmitButton)
        }
        return true
    }
}

// MARK: Login Logic
extension S1LoginViewController {

    fileprivate func loginAction() {
        let username = currentUsername()
        let password = currentPassword()
        guard username != "" && password != "" else {
            self.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: "用户名和密码不能为空")
            return
        }
        UserDefaults.standard.set(username, forKey: "UserIDCached")
        let secureQuestionNumber = self.currentSecureQuestionNumber()
        let secureQuestionAnswer = self.currentSecureQuestionAnswer()

        userInfoInputView.loginButton.isEnabled = false
        networkManager.checkLoginType(noSechashBlock: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.networkManager.logIn(username, password: password, secureQuestionNumber: secureQuestionNumber, secureQuestionAnswer: secureQuestionAnswer, authMode: .Basic, successBlock: { [weak self] (message) in
                guard let strongSelf = self else { return }
                strongSelf.userInfoInputView.loginButton.enabled = true
                NSUserDefaults.standardUserDefaults().setObject(username, forKey: "InLoginStateID")
                strongSelf.state = .Login
                let alertController = UIAlertController(title: NSLocalizedString("SettingView_LogIn", comment:""), message: message ?? "登录成功", preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment:""), style: .Cancel, handler: { action in
                    strongSelf.dismiss()
                }))
                strongSelf.presentViewController(alertController, animated: true, completion: nil)
                }, failureBlock: { (error) in
                    strongSelf.userInfoInputView.loginButton.enabled = true
                    strongSelf.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: error.localizedDescription)
            })
        }, hasSeccodeBlock: { [weak self] (sechash) in
            guard let strongSelf = self else { return }
            strongSelf.userInfoInputView.loginButton.enabled = true

            strongSelf.sechash = sechash
            strongSelf.seccodeInputView.hidden = false
            strongSelf.networkManager.getSeccodeImage(sechash, successBlock: { (image) in
                strongSelf.seccodeInputView.seccodeImageView.image = image
            }, failureBlock: { (error) in
                strongSelf.alert(title: "下载验证码失败", message: error.localizedDescription)
                strongSelf.userInfoInputView.loginButton.enabled = true
            })


        }, failureBlock: { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.userInfoInputView.loginButton.enabled = true
            strongSelf.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: error.localizedDescription)
        })
    }

    fileprivate func logoutAction() {
        self.networkManager.logOut()
        self.state = .notLogin
        self.alert(title: NSLocalizedString("SettingView_LogOut", comment:""), message: NSLocalizedString("LoginView_Logout_Message", comment:""))
    }
}

// MARK: Helper
extension S1LoginViewController {

    fileprivate func alert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment:""), style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

    func pan(_ gesture: UIPanGestureRecognizer) {
        guard let dynamicAnimator = dynamicAnimator else { return }

        switch gesture.state {
        case .began:
            dynamicAnimator.removeAllBehaviors()
            DDLogDebug("[LoginVC] pan location begin \(gesture.locationInView(self.view))")
            attachmentBehavior = UIAttachmentBehavior(item: containerView,
                                                       offsetFromCenter: offsetFromCenter(gesture.location(in: view), viewCenter: containerView.center),
                                                       attachedToAnchor: gesture.location(in: self.view))
            dynamicAnimator.addBehavior(attachmentBehavior!)
            dynamicItemBehavior = UIDynamicItemBehavior(items: [containerView])
            dynamicAnimator.addBehavior(dynamicItemBehavior!)

        case .changed:
            DDLogDebug("[LoginVC] pan location \(gesture.locationInView(self.view))")
            attachmentBehavior?.anchorPoint = gesture.location(in: self.view)
        default:
            let velocity = gesture.velocity(in: self.view)
            DDLogVerbose("[LoginVC] pan velocity: \(velocity)")
            if velocity.x * velocity.x + velocity.y * velocity.y > 1000000 {
                if let attachmentBehavior = attachmentBehavior {
                    dynamicAnimator.removeBehavior(attachmentBehavior)
                }
                DDLogVerbose("[LoginVC] dismiss triggered with original velocity: \(dynamicItemBehavior?.linearVelocityForItem(containerView))")
                dynamicItemBehavior?.addLinearVelocity(velocity, for: containerView)
                dynamicItemBehavior?.action = { [weak self] in
                    guard let strongSelf = self else { return }
                    if let items = strongSelf.dynamicAnimator?.items(in: strongSelf.view.bounds) , items.count == 0 {
                        if !strongSelf.isBeingDismissed {
                            strongSelf.dismiss()
                        }
                    }
                }
            } else {
                dynamicAnimator.removeAllBehaviors()
                if let snapBehavior = self.snapBehavior {
                    dynamicAnimator.addBehavior(snapBehavior)
                }
            }
        }
    }

    fileprivate func centerOfContainerView() -> CGPoint {
        return CGPoint(x: self.visibleLayoutGuide.center.x, y: self.visibleLayoutGuide.center.y)
    }

    fileprivate func offsetFromCenter(_ touchPointInView: CGPoint, viewCenter: CGPoint) -> UIOffset {
        return UIOffset(horizontal: touchPointInView.x - viewCenter.x, vertical: touchPointInView.y - viewCenter.y)
    }
}

// MARK: View Model
extension S1LoginViewController {

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
        return UserDefaults.standard.object(forKey: "InLoginStateID") as? String
    }

    fileprivate func cachedUserID() -> String? {
        return UserDefaults.standard.object(forKey: "InLoginStateID") as? String
    }

    fileprivate func inLoginState() -> Bool {
        return inLoginStateID() != nil
    }
}
