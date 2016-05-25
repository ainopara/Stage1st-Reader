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

final class S1LoginViewController: UIViewController {
    let backgroundBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
    let containerView = UIView(frame: CGRect.zero)
    let usernameField = UITextField(frame: CGRect.zero)
    let passwordField = UITextField(frame: CGRect.zero)
    let loginButton = UIButton(type: .System)
    let onepasswordButton = UIButton(type: .System)
    let questionSelectButton = UIButton(type: .System)
    let answerField = UITextField(frame: CGRect.zero)
    let seccodeImageView = UIImageView(image: nil)
    let seccodeField = UITextField(frame: CGRect.zero)

    let visibleLayoutGuide = UIView(frame: CGRect.zero)

    var dynamicAnimator: UIDynamicAnimator?
    var snapBehavior: UISnapBehavior?
    var dynamicItemBehavior: UIDynamicItemBehavior?
    var attachmentBehavior: UIAttachmentBehavior?
    var dragGesture: UIPanGestureRecognizer?
    var tapGesture: UITapGestureRecognizer?

    var loginButtonTopConstraint: Constraint?

    let networkManager: DiscuzAPIManager

    private var state: LoginViewControllerState = .NotLogin {
        didSet {
            switch state {
            case .NotLogin:
                usernameField.enabled = true
                passwordField.alpha = 1.0
                questionSelectButton.alpha = 1.0
                answerField.alpha = 0.0

                passwordField.returnKeyType = .Go
                loginButton.setTitle(NSLocalizedString("SettingView_LogIn", comment: "LogIn"), forState: .Normal)
                loginButtonTopConstraint?.uninstall()
                loginButton.snp_makeConstraints { (make) in
                    self.loginButtonTopConstraint = make.top.equalTo(questionSelectButton.snp_bottom).offset(12.0).constraint
                }
            case .NotLoginWithAnswerField:
                usernameField.enabled = true
                passwordField.alpha = 1.0
                questionSelectButton.alpha = 1.0
                answerField.alpha = 1.0

                passwordField.returnKeyType = .Next
                loginButton.setTitle(NSLocalizedString("SettingView_LogIn", comment: "LogIn"), forState: .Normal)
                loginButtonTopConstraint?.uninstall()
                loginButton.snp_updateConstraints { (make) in
                    self.loginButtonTopConstraint = make.top.equalTo(answerField.snp_bottom).offset(12.0).constraint
                }
            case .Login:
                usernameField.enabled = false
                passwordField.alpha = 0.0
                questionSelectButton.alpha = 0.0
                answerField.alpha = 0.0

                loginButton.setTitle(NSLocalizedString("SettingView_LogOut", comment: "LogOut"), forState: .Normal)
                loginButtonTopConstraint?.uninstall()
                loginButton.snp_updateConstraints { (make) in
                    self.loginButtonTopConstraint = make.top.equalTo(usernameField.snp_bottom).offset(12.0).constraint
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
        self.networkManager = DiscuzAPIManager(baseURL: "http://bbs.saraba1st.com/2b")
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
        self.view.addSubview(containerView)

        usernameField.delegate = self
        usernameField.placeholder = NSLocalizedString("S1LoginViewController.usernameField.placeholder", comment: "")
        usernameField.text = self.cachedUserID() ?? ""
        usernameField.borderStyle = .Line
        usernameField.autocorrectionType = .No
        usernameField.autocapitalizationType = .None
        usernameField.returnKeyType = .Next
        usernameField.backgroundColor = UIColor.whiteColor()
        containerView.addSubview(usernameField)

        usernameField.snp_makeConstraints { (make) in
            make.width.equalTo(300.0)
            make.height.equalTo(30.0)
            make.top.equalTo(containerView.snp_top).offset(20.0)
            make.centerX.equalTo(containerView.snp_centerX)
        }

        passwordField.delegate = self
        passwordField.placeholder = NSLocalizedString("S1LoginViewController.passwordField.placeholder", comment: "")
        passwordField.borderStyle = .Line
        passwordField.secureTextEntry = true
        passwordField.returnKeyType = .Go
        passwordField.backgroundColor = UIColor.whiteColor()
        containerView.addSubview(passwordField)

        passwordField.snp_makeConstraints { (make) in
            make.width.equalTo(usernameField.snp_width)
            make.height.equalTo(30.0)
            make.centerX.equalTo(usernameField.snp_centerX)
            make.top.equalTo(usernameField.snp_bottom).offset(12.0)
        }

        onepasswordButton.setImage(UIImage(named: "OnePasswordButton"), forState: .Normal)
        onepasswordButton.addTarget(self, action: #selector(S1LoginViewController.findLoginFromOnePassword(_:)), forControlEvents: .TouchUpInside)
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

        questionSelectButton.setTitle("安全提问（未设置请忽略）", forState: .Normal)
        questionSelectButton.tintColor = APColorManager.sharedInstance.colorForKey("login.text")
        questionSelectButton.addTarget(self, action: #selector(S1LoginViewController.selectSecureQuestion(_:)), forControlEvents: .TouchUpInside)
        containerView.addSubview(questionSelectButton)

        self.questionSelectButton.snp_makeConstraints { (make) in
            make.width.centerX.equalTo(self.usernameField)
            make.height.equalTo(30.0)
            make.top.equalTo(self.passwordField.snp_bottom).offset(12.0)
        }

        answerField.delegate = self
        answerField.borderStyle = .Line
        answerField.autocorrectionType = .No
        answerField.autocapitalizationType = .None
        answerField.secureTextEntry = true
        answerField.returnKeyType = .Go
        answerField.backgroundColor = UIColor.whiteColor()
        containerView.addSubview(answerField)

        answerField.snp_makeConstraints { (make) in
            make.width.centerX.equalTo(self.questionSelectButton)
            make.height.equalTo(30.0)
            make.top.equalTo(self.questionSelectButton.snp_bottom).offset(12.0)
        }

        loginButton.addTarget(self, action: #selector(S1LoginViewController.logIn(_:)), forControlEvents: .TouchUpInside)
        loginButton.backgroundColor = APColorManager.sharedInstance.colorForKey("login.button")
        loginButton.tintColor = APColorManager.sharedInstance.colorForKey("login.text")

        containerView.addSubview(loginButton)

        loginButton.snp_makeConstraints { (make) in
            make.width.centerX.equalTo(self.usernameField)
            make.height.equalTo(34.0)
            make.bottom.equalTo(self.containerView.snp_bottom).offset(-12.0)
        }

        containerView.snp_makeConstraints { (make) in
            make.width.equalTo(self.usernameField.snp_width).offset(10.0)
        }

        self.view.insertSubview(visibleLayoutGuide, atIndex: 0)
        visibleLayoutGuide.userInteractionEnabled = false
        visibleLayoutGuide.snp_makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }

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

    // MARK: - Actions
    func logIn(sender: UIButton) {
        if self.inLoginState() {
            self.logoutAction()
        } else {
            self.loginAction()
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

            strongSelf.usernameField.text = loginDict[AppExtensionUsernameKey] as? String ?? ""
            strongSelf.passwordField.text = loginDict[AppExtensionPasswordKey] as? String ?? ""
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
        if textField == self.usernameField {
            passwordField.becomeFirstResponder()
        } else if textField == self.passwordField {
            switch state {
            case .NotLogin:
                textField.resignFirstResponder()
                self.logIn(self.loginButton)
            case .NotLoginWithAnswerField:
                answerField.becomeFirstResponder()
            case .Login:
                break
            }
        } else if textField == self.answerField {
            textField.resignFirstResponder()
            self.logIn(self.loginButton)
        }
        return true
    }
}

// MARK: Login Logic
extension S1LoginViewController {

    func loginAction() {
        guard let username = self.usernameField.text, password = self.passwordField.text where username != "" && password != "" else {
            self.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: "用户名和密码不能为空")
            return
        }
        NSUserDefaults.standardUserDefaults().setObject(username, forKey: "UserIDCached")
        let secureQuestionNumber = self.currentSecureQuestionNumber()
        let secureQuestionAnswer = self.currentSecureQuestionAnswer()

        loginButton.enabled = false
        networkManager.checkLoginType(noSechashBlock: {
            self.networkManager.logIn(username, password: password, secureQuestionNumber: secureQuestionNumber, secureQuestionAnswer: secureQuestionAnswer, successBlock: { (message) in
                self.loginButton.enabled = true
                NSUserDefaults.standardUserDefaults().setObject(username, forKey: "InLoginStateID")
                self.state = .Login
                let alertController = UIAlertController(title: NSLocalizedString("SettingView_LogIn", comment:""), message: message ?? "登录成功", preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment:""), style: .Cancel, handler: { action in
                    self.dismiss()
                }))
                self.presentViewController(alertController, animated: true, completion: nil)
                }, failureBlock: { (error) in
                    self.loginButton.enabled = true
                    self.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: error.localizedDescription)
            })
        }, hasSeccodeBlock: { (sechash) in
            self.loginButton.enabled = true
            self.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: "尚未实现验证码登录功能")
        }, failureBlock: { (error) in
            self.loginButton.enabled = true
            self.alert(title: NSLocalizedString("SettingView_LogIn", comment:""), message: error.localizedDescription)
        })
    }

    func logoutAction() {
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
        if let text = questionSelectButton.currentTitle, index = self.secureQuestionChoices.indexOf(text) {
            return index
        } else {
            return 0
        }
    }

    private func currentSecureQuestionAnswer() -> String {
        if currentSecureQuestionNumber() == 0 {
            return ""
        } else {
            return self.answerField.text ?? ""
        }
    }

    private func inLoginStateID() -> String? {
        return NSUserDefaults.standardUserDefaults().objectForKey("InLoginStateID") as? String
    }

    private func cachedUserID() -> String? {
        return NSUserDefaults.standardUserDefaults().objectForKey("InLoginStateID") as? String
    }

    private func inLoginState() -> Bool {
        return self.inLoginStateID() != nil
    }
}
