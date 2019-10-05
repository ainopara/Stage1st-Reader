//
//  TopicComposeViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/6/10.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation
import Fuzi

final class TopicComposeViewController: UIViewController {

    let forumID: Int

    let textField = S1TextField()
    let separatorView = SeparatorView()
    let textView = UITextView()

    let hud = Hud()

    init(forumID: Int) {
        assert(forumID != 0)
        self.forumID = forumID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Submit", comment: ""),
            style: .done,
            target: self,
            action: #selector(submitAction)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Close", comment: ""),
            style: .plain,
            target: self,
            action: #selector(closeAction)
        )
        navigationItem.title = "创建主题"

        textField.placeholder = "标题"
        textField.backgroundColor = .white
        view.addSubview(textField)

        view.addSubview(separatorView)

        textView.backgroundColor = .white
        view.addSubview(textView)

        view.addSubview(hud)

        textField.snp.makeConstraints { (make) in
            if #available(iOS 11.0, *) {
                make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            } else {
                make.top.equalTo(self.topLayoutGuide.snp.top)
            }
            make.leading.trailing.equalTo(view)
            make.height.equalTo(44.0)
        }

        separatorView.snp.makeConstraints { (make) in
            make.top.equalTo(textField.snp.bottom)
            make.leading.trailing.equalTo(view)
        }

        textView.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(view)
            make.top.equalTo(textField.snp.bottom)
            make.bottom.equalTo(view)
        }

        hud.snp.makeConstraints { (make) in
            make.center.equalTo(self.view)
        }
    }
}

extension TopicComposeViewController {

    @objc
    func submitAction() {
        AppEnvironment.current.apiService.newTopic(
            forumID: self.forumID,
            typeID: 0,
            formhash: AppEnvironment.current.dataCenter.formhash.value!,
            subject: textField.text ?? "",
            message: textView.text,
            saveAsDraft: false,
            noticeUser: true
        ) { [weak self] (result) in
            guard let strongSelf = self else { return }

            let processedResult = result.tryMap { (rawHTMLString) -> String in
                let document = try HTMLDocument(string: rawHTMLString)
                guard let result = document.xpath("//div[@id = 'messagetext']").first?.stringValue else {
                    throw "No message text found"
                }
                return result
            }

            switch processedResult {
            case .success(let string):
                strongSelf.dismiss(animated: true, completion: nil)
            case .failure(let error):
                strongSelf.hud.show(message: error.localizedDescription)
                strongSelf.hud.hide(delay: 2.0)
            }
        }
    }

    @objc
    func closeAction() {
        self.dismiss(animated: true, completion: nil)
    }
}
