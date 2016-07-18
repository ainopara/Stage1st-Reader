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
    case NotLogin
    case NotLoginWithAnswerField
    case Login
}

private class UserInfoInputView: UIView {
    let usernameField = UITextField(frame: CGRect.zero)
    let passwordField = UITextField(frame: CGRect.zero)
    let onepasswordButton = UIButton(type: .System)
    let questionSelectButton = UIButton(type: .System)
    let answerField = UITextField(frame: CGRect.zero)
    let loginButton = UIButton(type: .System)

    override init(frame: CGRect) {
        super.init(frame: frame)

        usernameField.borderStyle = .Line
        usernameField.autocorrectionType = .No
        usernameField.autocapitalizationType = .None
        usernameField.returnKeyType = .Next
        usernameField.backgroundColor = UIColor.whiteColor()
        self.addSubview(usernameField)

        usernameField.snp_makeConstraints { (make) in
            make.width.equalTo(300.0)
            make.height.equalTo(30.0)
            make.top.equalTo(self.snp_top).offset(20.0)
            make.centerX.equalTo(self.snp_centerX)
            make.leading.equalTo(self.snp_leading).offset(5.0)
        }

        passwordField.borderStyle = .Line
        passwordField.secureTextEntry = true
        passwordField.returnKeyType = .Go
        passwordField.backgroundColor = UIColor.whiteColor()
        self.addSubview(passwordField)

        passwordField.snp_makeConstraints { (make) in
            make.width.equalTo(self.usernameField.snp_width)
            make.height.equalTo(30.0)
            make.centerX.equalTo(self.usernameField.snp_centerX)
            make.top.equalTo(self.usernameField.snp_bottom).offset(12.0)
        }

        onepasswordButton.setImage(UIImage(named: "OnePasswordButton"), forState: .Normal)
        onepasswordButton.tintColor = APColorManager.sharedInstance.colorForKey("default.text.tint")

        let buttonContainer = UIView(frame: CGRect.zero)
        buttonContainer.snp_makeConstraints { (make) in
            make.height.equalTo(24.0)
            make.width.equalTo(28.0)
        }
        buttonContainer.addSubview(onepasswordButton)

        onepasswordButton.snp_makeConstraints { (make) in
            make.top.leading.bottom.equalTo(buttonContainer)
            make.trailing.equalTo(buttonContainer).offset(-4.0)
        }
        passwordField.rightView = buttonContainer
        passwordField.rightViewMode = OnePasswordExtension.sharedExtension().isAppExtensionAvailable() ? .Always : .Never

        self.addSubview(questionSelectButton)

        self.questionSelectButton.snp_makeConstraints { (make) in
            make.width.centerX.equalTo(self.usernameField)
            make.height.equalTo(30.0)
            make.top.equalTo(self.passwordField.snp_bottom).offset(12.0)
        }

        answerField.borderStyle = .Line
        answerField.autocorrectionType = .No
        answerField.autocapitalizationType = .None
        answerField.secureTextEntry = true
        answerField.returnKeyType = .Go
        answerField.backgroundColor = UIColor.whiteColor()
        self.addSubview(answerField)

        answerField.snp_makeConstraints { (make) in
            make.width.centerX.equalTo(self.questionSelectButton)
            make.height.equalTo(30.0)
            make.top.equalTo(self.questionSelectButton.snp_bottom).offset(12.0)
        }

        self.addSubview(loginButton)

        loginButton.snp_makeConstraints { (make) in
            make.width.centerX.equalTo(self.usernameField)
            make.height.equalTo(34.0)
            make.bottom.equalTo(self.snp_bottom).offset(-12.0)
        }


    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class SeccodeInputView: UIView {
    let seccodeImageView = UIImageView(image: nil)
    let seccodeField = UITextField(frame: CGRect.zero)
    let seccodeSubmitButton = UIButton(type: .System)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.seccodeImageView)
        seccodeImageView.snp_makeConstraints { (make) in
            make.centerX.equalTo(self)
            make.top.equalTo(self.snp_top).offset(10.0)
            make.width.equalTo(100.0)
            make.height.equalTo(40.0)
        }

        seccodeField.borderStyle = .Line
        seccodeField.autocorrectionType = .No
        seccodeField.autocapitalizationType = .None
        seccodeField.returnKeyType = .Go
        self.addSubview(self.seccodeField)
        seccodeField.snp_makeConstraints { (make) in
            make.centerX.equalTo(self)
            make.width.equalTo(self.snp_width).offset(-24.0)
            make.top.equalTo(self.seccodeImageView.snp_bottom).offset(10.0)
        }

        self.addSubview(self.seccodeSubmitButton)
        seccodeSubmitButton.snp_makeConstraints { (make) in
            make.centerX.equalTo(self)
            make.width.equalTo(self.snp_width).offset(-24.0)
            make.bottom.equalTo(self.snp_bottom).offset(-10.0)
        }

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class S1LoginViewController: UIViewController {

    private let backgroundBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
    private let containerView = UIView(frame: CGRect.zero)

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

    private let networkManager: DiscuzAPIManager
    private var sechash: String?

    private var state: LoginViewControllerState = .NotLogin {
        didSet {
            switch state {
            case .NotLogin:
                userInfoInputView.usernameField.enabled = true
                userInfoInputView.passwordField.alpha = 1.0
                userInfoInputView.questionSelectButton.alpha = 1.0
                userInfoInputView.answerField.alpha = 0.0

                userInfoInputView.passwordField.returnKeyType = .Go
                userInfoInputView.loginButton.setTitle(NSLocalizedString("SettingView_LogIn", comment: "LogIn"), forState: .Normal)
                loginButtonTopConstraint?.uninstall()
                userInfoInputView.loginButton.snp_makeConstraints { (make) in
                    self.loginButtonTopConstraint = make.top.equalTo(self.userInfoInputView.questionSelectButton.snp_bottom).offset(12.0).constraint
                }
            case .NotLoginWithAnswerField:
                userInfoInputView.usernameField.enabled = true
                userInfoInputView.passwordField.alpha = 1.0
                userInfoInputView.questionSelectButton.alpha = 1.0
                userInfoInputView.answerField.alpha = 1.0

                userInfoInputView.passwordField.returnKeyType = .Next
                userInfoInputView.loginButton.setTitle(NSLocalizedString("SettingView_LogIn", comment: "LogIn"), forState: .Normal)
                loginButtonTopConstraint?.uninstall()
                userInfoInputView.loginButton.snp_updateConstraints { (make) in
                    self.loginButtonTopConstraint = make.top.equalTo(self.userInfoInputView.answerField.snp_bottom).offset(12.0).constraint
                }
            case .Login:
                userInfoInputView.usernameField.enabled = false
                userInfoInputView.passwordField.alpha = 0.0
                userInfoInputView.questionSelectButton.alpha = 0.0
                userInfoInputView.answerField.alpha = 0.0

                userInfoInputView.loginButton.setTitle(NSLocalizedString("SettingView_LogOut", comment: "LogOut"), forState: .Normal)
                loginButtonTopConstraint?.uninstall()
                userInfoInputView.loginButton.snp_updateConstraints { (make) in
                    self.loginButtonTopConstraint = make.top.equalTo(self.userInfoInputView.usernameField.snp_bottom).offset(12.0).constraint
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
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.networkManager = DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b")  // FIXME: base URL should not be hard coded.
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.modalPresentationStyle = .OverFullScreen
        self.modalTransitionStyle = .CrossDissolve
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(backgroundBlurView)
        backgroundBlurView.snp_makeConstraints { (make) in
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
        userInfoInputView.onepasswordButton.addTarget(self, action: #selector(S1LoginViewController.findLoginFromOnePassword(_:)), forControlEvents: .TouchUpInside)
        userInfoInputView.questionSelectButton.setTitle("安全提问（未设置请忽略）", forState: .Normal)
        userInfoInputView.questionSelectButton.tintColor = APColorManager.sharedInstance.colorForKey("login.text")
        userInfoInputView.questionSelectButton.addTarget(self, action: #selector(S1LoginViewController.selectSecureQuestion(_:)), forControlEvents: .TouchUpInside)
        userInfoInputView.answerField.delegate = self
        userInfoInputView.loginButton.addTarget(self, action: #selector(S1LoginViewController.logIn(_:)), forControlEvents: .TouchUpInside)
        userInfoInputView.loginButton.backgroundColor = APColorManager.sharedInstance.colorForKey("login.button")
        userInfoInputView.loginButton.tintColor = APColorManager.sharedInstance.colorForKey("login.text")

        containerView.addSubview(userInfoInputView)
        userInfoInputView.snp_makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }

        self.view.insertSubview(visibleLayoutGuide, atIndex: 0)
        visibleLayoutGuide.userInteractionEnabled = false
        visibleLayoutGuide.snp_makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }

        seccodeInputView.hidden = true
        seccodeInputView.backgroundColor = APColorManager.sharedInstance.colorForKey("login.background")

        containerView.addSubview(seccodeInputView)
        seccodeInputView.snp_makeConstraints { (make) in
            make.edges.equalTo(containerView)
        }

        seccodeInputView.seccodeField.delegate = self
        seccodeInputView.seccodeField.backgroundColor = UIColor.whiteColor()
        seccodeInputView.seccodeSubmitButton.setTitle("提交", forState: .Normal)
        seccodeInputView.seccodeSubmitButton.backgroundColor = APColorManager.sharedInstance.colorForKey("login.button")
        seccodeInputView.seccodeSubmitButton.addTarget(self, action: #selector(S1LoginViewController.LogInWithSeccode(_:)), forControlEvents: .TouchUpInside)

        state = self.inLoginState() ? .Login : .NotLogin

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(S1LoginViewController.dismiss))
        self.tapGesture = tapGesture
        self.backgroundBlurView.addGestureRecognizer(tapGesture)

        let dynamicAnimator = UIDynamicAnimator(referenceView: self.view)
        self.dynamicAnimator = dynamicAnimator

        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(S1LoginViewController.pan(_:)))
        self.view.addGestureRecognizer(dragGesture)
        self.dragGesture = dragGesture

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(S1LoginViewController.keyboardFrameWillChange(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
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
                    let snapBehavior = UISnapBehavior(item: containerView, snapToPoint: centerOfContainerView())
                    dynamicAnimator.addBehavior(snapBehavior)
                    self.snapBehavior = snapBehavior
                }
            } else {
                dynamicAnimator.removeAllBehaviors()
                let snapBehavior = UISnapBehavior(item: containerView, snapToPoint: centerOfContainerView())
                dynamicAnimator.addBehavior(snapBehavior)
                self.snapBehavior = snapBehavior
            }
        }
    }
}

// MARK: - Actions
extension S1LoginViewController {

    func logIn(sender: UIButton) {
        if self.inLoginState() {
            self.logoutAction()
        } else {
            self.loginAction()
        }
    }

    func LogInWithSeccode(sender: UIButton) {
        let username = currentUsername()
        let password = currentPassword()
        guard username != "" && password != "" else {
            self.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: "用户名和密码不能为空")
            return
        }
        self.seccodeInputView.seccodeSubmitButton.enabled = false
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

    func findLoginFromOnePassword(button: UIButton) {
        OnePasswordExtension.sharedExtension().findLoginForURLString(NSUserDefaults.standardUserDefaults().objectForKey("BaseURL") as? String ?? "", forViewController: self, sender: button) { [weak self] (loginDict, error) in
            guard let strongSelf = self else {
                return
            }
            guard let loginDict = loginDict else {
                return
            }
            if let error = error where error.code != Int(AppExtensionErrorCodeCancelledByUser) {
                DDLogInfo("Error invoking 1Password App Extension for find login: \(error)")
                return
            }

            strongSelf.userInfoInputView.usernameField.text = loginDict[AppExtensionUsernameKey] as? String ?? ""
            strongSelf.userInfoInputView.passwordField.text = loginDict[AppExtensionPasswordKey] as? String ?? ""
        }
    }

    func selectSecureQuestion(button: UIButton) {
        DDLogDebug("debug secure question")
        self.view.endEditing(true)
        // TODO: Make action sheet picker a view controller to avoid keyboard overlay.
        let picker = ActionSheetStringPicker(title: "安全提问", rows: secureQuestionChoices, initialSelection: currentSecureQuestionNumber(), doneBlock: { (pciker, selectedIndex, selectedValue) in
                button.setTitle(selectedValue as? String ?? "??", forState: .Normal)
                if selectedIndex == 0 {
                    self.state = .NotLogin
                } else {
                    self.state = .NotLoginWithAnswerField
                }
            }, cancelBlock: nil, origin: button)
        picker.toolbarBackgroundColor = APColorManager.sharedInstance.colorForKey("appearance.toolbar.bartint")
        picker.toolbarButtonsColor = APColorManager.sharedInstance.colorForKey("appearance.toolbar.tint")
        picker.showActionSheetPicker()
    }

    func dismiss() {
        if let presentingViewController = self.presentingViewController {
            presentingViewController.dismissViewControllerAnimated(true, completion: nil)
        } else {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }

    func keyboardFrameWillChange(notification: NSNotification) {
        guard let userInfo = notification.userInfo, endFrame = userInfo[UIKeyboardFrameEndUserInfoKey]?.CGRectValue() else { return }

        let keyboardHeightInView = self.view.bounds.maxY - endFrame.minY
        DDLogDebug("[LoginVC] keytboard height: \(keyboardHeightInView)")
        visibleLayoutGuide.snp_updateConstraints { (make) in
            make.bottom.equalTo(self.view).offset(-keyboardHeightInView)
        }
    }
}

// MARK: - UITextFieldDelegate
extension S1LoginViewController: UITextFieldDelegate {

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == userInfoInputView.usernameField {
            userInfoInputView.passwordField.becomeFirstResponder()
        } else if textField == userInfoInputView.passwordField {
            switch state {
            case .NotLogin:
                textField.resignFirstResponder()
                self.logIn(userInfoInputView.loginButton)
            case .NotLoginWithAnswerField:
                userInfoInputView.answerField.becomeFirstResponder()
            case .Login:
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

    private func loginAction() {
        let username = currentUsername()
        let password = currentPassword()
        guard username != "" && password != "" else {
            self.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: "用户名和密码不能为空")
            return
        }
        NSUserDefaults.standardUserDefaults().setObject(username, forKey: "UserIDCached")
        let secureQuestionNumber = self.currentSecureQuestionNumber()
        let secureQuestionAnswer = self.currentSecureQuestionAnswer()

        userInfoInputView.loginButton.enabled = false
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

    private func logoutAction() {
        self.networkManager.logOut()
        self.state = .NotLogin
        self.alert(title: NSLocalizedString("SettingView_LogOut", comment:""), message: NSLocalizedString("LoginView_Logout_Message", comment:""))
    }
}

// MARK: Helper
extension S1LoginViewController {

    private func alert(title title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment:""), style: .Cancel, handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }

    func pan(gesture: UIPanGestureRecognizer) {
        guard let dynamicAnimator = dynamicAnimator else { return }

        switch gesture.state {
        case .Began:
            dynamicAnimator.removeAllBehaviors()
            DDLogDebug("[LoginVC] pan location begin \(gesture.locationInView(self.view))")
            attachmentBehavior = UIAttachmentBehavior(item: containerView,
                                                       offsetFromCenter: offsetFromCenter(gesture.locationInView(view), viewCenter: containerView.center),
                                                       attachedToAnchor: gesture.locationInView(self.view))
            dynamicAnimator.addBehavior(attachmentBehavior!)
            dynamicItemBehavior = UIDynamicItemBehavior(items: [containerView])
            dynamicAnimator.addBehavior(dynamicItemBehavior!)

        case .Changed:
            DDLogDebug("[LoginVC] pan location \(gesture.locationInView(self.view))")
            attachmentBehavior?.anchorPoint = gesture.locationInView(self.view)
        default:
            let velocity = gesture.velocityInView(self.view)
            DDLogVerbose("[LoginVC] pan velocity: \(velocity)")
            if velocity.x * velocity.x + velocity.y * velocity.y > 1000000 {
                if let attachmentBehavior = attachmentBehavior {
                    dynamicAnimator.removeBehavior(attachmentBehavior)
                }
                DDLogVerbose("[LoginVC] dismiss triggered with original velocity: \(dynamicItemBehavior?.linearVelocityForItem(containerView))")
                dynamicItemBehavior?.addLinearVelocity(velocity, forItem: containerView)
                dynamicItemBehavior?.action = { [weak self] in
                    guard let strongSelf = self else { return }
                    if let items = strongSelf.dynamicAnimator?.itemsInRect(strongSelf.view.bounds) where items.count == 0 {
                        if !strongSelf.isBeingDismissed() {
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

    private func centerOfContainerView() -> CGPoint {
        return CGPoint(x: self.visibleLayoutGuide.center.x, y: self.visibleLayoutGuide.center.y)
    }

    private func offsetFromCenter(touchPointInView: CGPoint, viewCenter: CGPoint) -> UIOffset {
        return UIOffset(horizontal: touchPointInView.x - viewCenter.x, vertical: touchPointInView.y - viewCenter.y)
    }
}

// MARK: View Model
extension S1LoginViewController {

    private func currentSecureQuestionNumber() -> Int {
        if let text = userInfoInputView.questionSelectButton.currentTitle, index = self.secureQuestionChoices.indexOf(text) {
            return index
        } else {
            return 0
        }
    }

    private func currentSecureQuestionAnswer() -> String {
        if currentSecureQuestionNumber() == 0 {
            return ""
        } else {
            return userInfoInputView.answerField.text ?? ""
        }
    }

    private func currentSechash() -> String {
        return sechash ?? ""
    }

    private func currentSeccode() -> String {
        return seccodeInputView.seccodeField.text ?? ""
    }

    private func currentUsername() -> String {
        return userInfoInputView.usernameField.text ?? ""
    }

    private func currentPassword() -> String {
        return userInfoInputView.passwordField.text ?? ""
    }

    private func inLoginStateID() -> String? {
        return NSUserDefaults.standardUserDefaults().objectForKey("InLoginStateID") as? String
    }

    private func cachedUserID() -> String? {
        return NSUserDefaults.standardUserDefaults().objectForKey("InLoginStateID") as? String
    }

    private func inLoginState() -> Bool {
        return inLoginStateID() != nil
    }
}
