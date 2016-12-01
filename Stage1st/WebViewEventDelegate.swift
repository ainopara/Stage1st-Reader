//
//  WebViewEventDelegate.swift
//  Stage1st
//
//  Created by Zheng Li on 10/31/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import WebKit
import JTSImageViewController
import CocoaLumberjack
import Crashlytics

class GeneralScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WebViewEventDelegate?

    init(delegate: WebViewEventDelegate) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        DDLogVerbose("[ContentVC] message body: \(message.body)")
        guard let messageDictionary = message.body as? [String: Any],
              let type = messageDictionary["type"] as? String else {
            DDLogWarn("[ContentVC] unexpected message format")
            return
        }

        switch type {
        case "ready": // called when dom finish loading
            DDLogDebug("[WebView] ready")
            delegate?.generalScriptMessageHandler(self, readyWith: messageDictionary)
        case "load": // called when all the images finish loading
            DDLogDebug("[WebView] load")
            delegate?.generalScriptMessageHandler(self, loadWith: messageDictionary)
        case "heightChanged":
            DDLogDebug("[WebView] heightChange")
            delegate?.generalScriptMessageHandler(self, heightChangedTo: messageDictionary["height"] as! Double)
        case "action":
            guard let floorID = messageDictionary["id"] as? Int else {
                DDLogError("unexpected message format: \(messageDictionary)")
                return
            }
            delegate?.generalScriptMessageHandler(self, actionButtonTappedFor: floorID)
        case "user":
            guard let userID = messageDictionary["id"] as? Int else {
                DDLogError("unexpected message format: \(messageDictionary)")
                return
            }
            delegate?.generalScriptMessageHandler(self, showUserProfileWith: userID)
        case "image":
            guard let imageID = messageDictionary["id"] as? String,
               let imageURLString = messageDictionary["src"] as? String else {
                DDLogError("unexpected message format: \(messageDictionary)")
                return
            }
            delegate?.generalScriptMessageHandler(self, showImageWith: imageID, imageURLString: imageURLString)
        default:
            DDLogWarn("[WebView] unexpected type: \(type)")
            delegate?.generalScriptMessageHandler(self, handleUnkonwnEventWith: messageDictionary)
        }
    }
}

protocol WebViewEventDelegate: class {
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, readyWith messageDictionary: [String: Any])
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, loadWith messageDictionary: [String: Any])
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, heightChangedTo height: Double)
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, actionButtonTappedFor floorID: Int)
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, showUserProfileWith userID: Int)
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, showImageWith imageID: String, imageURLString: String)
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, handleUnkonwnEventWith messageDictionary: [String: Any])
}

extension WebViewEventDelegate {
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, readyWith messageDictionary: [String: Any]) {}
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, loadWith messageDictionary: [String: Any]) {}
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, heightChangedTo height: Double) {}
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, actionButtonTappedFor floorID: Int) {}
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, showUserProfileWith userID: Int) {}
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, showImageWith imageID: String, imageURLString: String) {}
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, handleUnkonwnEventWith messageDictionary: [String: Any]) {}
}

protocol UserViewModelGenerator {
    func userViewModel(userID: Int) -> UserViewModel
}

protocol S1ContentViewModelGenerator {
    func contentViewModel() -> S1ContentViewModel
}

protocol QuoteFloorViewModelGenerator {
    func quoteFloorViewModel(floors: [Floor], centerFloorID: Int) -> QuoteFloorViewModel
}

protocol UserPresenter {
    associatedtype ViewModel: UserViewModelGenerator
    var presentType: PresentType { get set }
    var viewModel: ViewModel { get }
}

extension WebViewEventDelegate where Self: UIViewController, Self: UserPresenter {
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, showUserProfileWith userID: Int) {
        var varSelf = self // FIXME: Make swift complier happy, remove this when the issue fixed.
        varSelf.presentType = .user
        let userViewModel = viewModel.userViewModel(userID: userID)
        let userViewController = UserViewController(viewModel: userViewModel)
        navigationController?.pushViewController(userViewController, animated: true)
    }
}

protocol ImagePresenter {
    var presentType: PresentType { get set }
    var webView: WKWebView { get }
}

extension WebViewEventDelegate where Self: UIViewController, Self: ImagePresenter, Self: JTSImageViewControllerInteractionsDelegate, Self: JTSImageViewControllerOptionsDelegate {
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, showImageWith imageID: String, imageURLString: String) {
        DispatchQueue.global(qos: .default).async { [weak self] in
            guard let strongSelf = self else { return }
            var varStrongSelf = strongSelf // FIXME: Make swift complier happy, remove this when the issue fixed.
            varStrongSelf.presentType = .image
            Answers.logCustomEvent(withName: "[Content] Image", customAttributes: ["type": "processed"])
            DDLogDebug("[ContentVC] JTS View Image: \(imageURLString)")

            let imageInfo = JTSImageInfo()
            imageInfo.imageURL = URL(string: imageURLString)
            imageInfo.referenceRect = strongSelf.webView.s1_positionOfElement(with: imageID) ?? CGRect(origin: strongSelf.webView.center, size: .zero)
            imageInfo.referenceView = strongSelf.webView

            let imageViewController = JTSImageViewController(imageInfo: imageInfo, mode: .image, backgroundStyle: .blurred)
            imageViewController?.interactionsDelegate = strongSelf
            imageViewController?.optionsDelegate = strongSelf
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                imageViewController?.show(from: strongSelf, transition: .fromOriginalPosition)
            }
        }
    }
}
