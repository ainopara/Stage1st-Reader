//
//  ReportComposeViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/6/15.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import ReactiveSwift

final class ReportComposeViewModel {
    let topic: S1Topic
    let floor: Floor
    let content = MutableProperty("")

    let canSubmit = MutableProperty(false)
    let isSubmitting = MutableProperty(false)

    init(topic: S1Topic, floor: Floor) {
        self.topic = topic
        self.floor = floor

        canSubmit <~ content.producer
            .map { $0.count > 0 }
            .combineLatest(with: isSubmitting.producer)
            .map { (hasCotent, isSubmitting) in hasCotent && !isSubmitting }
    }

    func submit(_ completion: @escaping (Error?) -> Void) {
        S1LogDebug("submit")
        guard let forumID = topic.fID, let formhash = topic.formhash else {
            return
        }

        AppEnvironment.current.dataCenter.blockUser(with: floor.author.ID)

        isSubmitting.value = true

        AppEnvironment.current.apiService.report(
            topicID: "\(topic.topicID)",
            floorID: "\(floor.ID)",
            forumID: "\(forumID)",
            reason: content.value,
            formhash: formhash
        ) { [weak self] error in
            guard let strongSelf = self else { return }
            strongSelf.isSubmitting.value = false
            completion(error)
        }
    }
}
