//
//  TopicComposeView.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/6/10.
//  Copyright © 2019 Renaissance. All rights reserved.
//

//import SwiftUI
//
//@available(iOS 13.0, *)
//struct TopicComposeView: UIViewControllerRepresentable {
//
//    let title: String
//    let content: String
//
//    init(title: String = "", content: String = "") {
//        self.title = title
//        self.content = content
//    }
//
//    func makeUIViewController(context: UIViewControllerRepresentableContext<TopicComposeView>) -> UINavigationController {
//        return UINavigationController(rootViewController: TopicComposeViewController(forumID: 6))
//    }
//
//    func updateUIViewController(_ uiViewController: UINavigationController, context: UIViewControllerRepresentableContext<TopicComposeView>) {
//        let composeViewController = uiViewController.viewControllers.first! as! TopicComposeViewController
//        composeViewController.textField.text = title
//        composeViewController.textView.text = content
//    }
//
//}
//
//#if DEBUG
//@available(iOS 13.0, *)
//struct TopicComposeView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            TopicComposeView()
//            TopicComposeView(title: "Hello World")
//            TopicComposeView(title: "Hello World", content: "WWWWWWWWWWWWWWWWWWWWWWWWWWWW")
//        }
//    }
//}
//#endif
