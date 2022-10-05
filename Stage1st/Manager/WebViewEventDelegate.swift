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

class GeneralScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WebViewEventDelegate?

    init(delegate: WebViewEventDelegate) {
        self.delegate = delegate
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        S1LogVerbose("[ContentVC] message body: \(message.body)")
        guard let messageDictionary = message.body as? [String: Any],
            let type = messageDictionary["type"] as? String else {
            S1LogWarn("[ContentVC] unexpected message format")
            return
        }

        switch type {
        case "ready": // called when dom finish loading
            S1LogDebug("[WebView] ready")
            delegate?.generalScriptMessageHandler(self, readyWith: messageDictionary)
        case "load": // called when all the images finish loading
            S1LogDebug("[WebView] load")
            delegate?.generalScriptMessageHandler(self, loadWith: messageDictionary)
        case "touch":
            S1LogVerbose("[WebView] touch event")
            delegate?.generalScriptMessageHandlerTouchEvent(self)
        case "action":
            guard let floorID = messageDictionary["id"] as? Int else {
                S1LogError("unexpected message format: \(messageDictionary)")
                return
            }
            delegate?.generalScriptMessageHandler(self, actionButtonTappedFor: floorID)
        case "user":
            guard let userID = messageDictionary["id"] as? Int else {
                S1LogError("unexpected message format: \(messageDictionary)")
                return
            }
            delegate?.generalScriptMessageHandler(self, showUserProfileWith: userID)
        case "image":
            guard let imageID = messageDictionary["id"] as? String,
                let imageURLString = messageDictionary["src"] as? String else {
                S1LogError("unexpected message format: \(messageDictionary)")
                return
            }
            delegate?.generalScriptMessageHandler(self, showImageWith: imageID, imageURLString: imageURLString)
        default:
            S1LogWarn("[WebView] unexpected type: \(type)")
            delegate?.generalScriptMessageHandler(self, handleUnkonwnEventWith: messageDictionary)
        }
    }
}

// MARK: -
protocol WebViewEventDelegate: class {
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, readyWith messageDictionary: [String: Any])
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, loadWith messageDictionary: [String: Any])
    func generalScriptMessageHandlerTouchEvent(_ scriptMessageHandler: GeneralScriptMessageHandler)
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, actionButtonTappedFor floorID: Int)
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, showUserProfileWith userID: Int)
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, showImageWith imageID: String, imageURLString: String)
    func generalScriptMessageHandler(_ scriptMessageHandler: GeneralScriptMessageHandler, handleUnkonwnEventWith messageDictionary: [String: Any])
}

extension WebViewEventDelegate {
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, readyWith _: [String: Any]) {}
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, loadWith _: [String: Any]) {}
    func generalScriptMessageHandlerTouchEvent(_: GeneralScriptMessageHandler) {}
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, actionButtonTappedFor _: Int) {}
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, showUserProfileWith _: Int) {}
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, showImageWith _: String, imageURLString _: String) {}
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, handleUnkonwnEventWith _: [String: Any]) {}
}

// MARK: - User
protocol UserViewModelMaker {
    func userViewModel(userID: Int) -> UserViewModel
}

protocol UserPresenter: AnyObject {
    associatedtype ViewModel: UserViewModelMaker
    var presentType: PresentType { get set }
    var viewModel: ViewModel { get }

    func showUserViewController(userID: Int)
}

extension UserPresenter where Self: UIViewController {
    func showUserViewController(userID: Int) {
        self.presentType = .user

        let userViewModel = viewModel.userViewModel(userID: userID)
        let userViewController = UserViewController(viewModel: userViewModel)
        navigationController?.pushViewController(userViewController, animated: true)
    }
}

extension WebViewEventDelegate where Self: UserPresenter {
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, showUserProfileWith userID: Int) {
        AppEnvironment.current.eventTracker.logEvent("Click User", attributes: [
            "source": "UserPresenter",
        ])
        showUserViewController(userID: userID)
    }
}

// MARK: - Content
protocol ContentViewModelMaker {
    func contentViewModel(topic: S1Topic) -> ContentViewModel
}

protocol ContentPresenter: AnyObject {
    associatedtype ViewModel: ContentViewModelMaker
    var presentType: PresentType { get set }
    var viewModel: ViewModel { get }

    func showContentViewController(topic: S1Topic)
}

extension ContentPresenter where Self: UIViewController {
    func showContentViewController(topic: S1Topic) {
        self.presentType = .content

        let contentViewModel = viewModel.contentViewModel(topic: topic)
        let contentViewController = ContentViewController(viewModel: contentViewModel)
        navigationController?.pushViewController(contentViewController, animated: true)
    }
}

// MARK: - Quote Floor
protocol QuoteFloorViewModelMaker {
    func quoteFloorViewModel(floors: [Floor], centerFloorID: Int) -> QuoteFloorViewModel
}

protocol QuoteFloorPresenter: AnyObject {
    associatedtype ViewModel: QuoteFloorViewModelMaker
    var presentType: PresentType { get set }
    var viewModel: ViewModel { get }

    func showQuoteFloorViewController(floors: [Floor], centerFloorID: Int)
}

extension QuoteFloorPresenter where Self: UIViewController {
    func showQuoteFloorViewController(floors: [Floor], centerFloorID: Int) {
        self.presentType = .quote

        let quoteFloorViewModel = viewModel.quoteFloorViewModel(floors: floors, centerFloorID: centerFloorID)
        let quoteFloorViewController = QuoteFloorViewController(viewModel: quoteFloorViewModel)
        navigationController?.pushViewController(quoteFloorViewController, animated: true)
    }
}

// MARK: - Image
enum ImagePresenterTransitionSource {
    case offScreen
    case positionOfElementID(String)
    case position(CGRect)
}

protocol ImagePresenter: AnyObject {
    var presentType: PresentType { get set }
    var webView: WKWebView { get }

    func showImageViewController(transitionSource: ImagePresenterTransitionSource, imageURL: URL)
}

extension ImagePresenter where Self: UIViewController, Self: JTSImageViewControllerInteractionsDelegate, Self: JTSImageViewControllerOptionsDelegate {
    func showImageViewController(transitionSource: ImagePresenterTransitionSource, imageURL: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.presentType = .image
            S1LogDebug("[ImagePresenter] JTS View Image: \(imageURL)")

            func configureImageInfo(completion: @escaping (JTSImageInfo) -> Void) {
                let imageInfo = JTSImageInfo()
                imageInfo.imageURL = imageURL
                switch transitionSource {
                case .offScreen:
                    completion(imageInfo)
                case let .positionOfElementID(imageID):
                    self.webView.s1_positionOfElement(with: imageID, completion: { (rect) in
                        imageInfo.referenceRect = rect ?? CGRect(origin: self.webView.center, size: .zero)
                        imageInfo.referenceView = self.webView
                        completion(imageInfo)
                    })
                case let .position(positionRect):
                    imageInfo.referenceRect = positionRect
                    imageInfo.referenceView = self.view
                    completion(imageInfo)
                }
            }

            configureImageInfo { [weak self] (imageInfo) in
                guard let self = self else { return }
                let imageViewController = JTSImageViewController(imageInfo: imageInfo, mode: .image, backgroundStyle: .blurred)
                imageViewController?.interactionsDelegate = self
                imageViewController?.optionsDelegate = self
                imageViewController?.modalPresentationStyle = .fullScreen
                switch transitionSource {
                case .offScreen:
                    imageViewController?.show(from: self, transition: .fromOffscreen)
                default:
                    imageViewController?.show(from: self, transition: .fromOriginalPosition)
                }
            }
        }
    }
}

extension WebViewEventDelegate where Self: ImagePresenter {
    func generalScriptMessageHandler(_: GeneralScriptMessageHandler, showImageWith imageID: String, imageURLString: String) {
        guard let url = URL(string: imageURLString) else {
            return
        }
        AppEnvironment.current.eventTracker.logEvent("Inspect Image", attributes: [
            "type": "Processed",
            "source": "ImagePresenter",
        ])
        showImageViewController(transitionSource: .positionOfElementID(imageID), imageURL: url)
    }
}
