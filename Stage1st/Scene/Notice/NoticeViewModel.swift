//
//  NoticeViewModel.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/12/2.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import ReactiveSwift

class NoticeViewModel {
    enum State {
        case loading
        enum LoadError {
            case networkError(Error)
        }
        case error(LoadError)
        case loaded([ReplyNotice])
        case fetchingMore([ReplyNotice])
        case allLoaded([ReplyNotice])
    }
    let state = MutableProperty<State>(.loading)

    let cellViewModels = MutableProperty<[NoticeCell.ViewModel]>([])
    let isEmptyViewHidden = MutableProperty<Bool>(false)
    let shouldShowErrorView = MutableProperty<Bool>(false)

    init() {
        cellViewModels <~ state
            .map { (state) -> [ReplyNotice] in
                switch state {
                case .loading, .error:
                    return []
                case .loaded(let notice), .fetchingMore(let notice), .allLoaded(let notice):
                    return notice
                }
            }
            .map { (models) in
                models.compactMap { try? NoticeCell.ViewModel(replyNotice: $0) }
            }

        isEmptyViewHidden <~ state.map { state in
            switch state {
            case .loaded(let data), .allLoaded(let data):
                return !data.isEmpty
            case .loading, .error, .fetchingMore:
                return true
            }
        }

        shouldShowErrorView <~ state.map { (state) in
            switch state {
            case .error:
                return true
            default:
                return false
            }
        }

        if AppEnvironment.current.settings.currentUsername.value != nil {
            AppEnvironment.current.apiService.notices(page: 1) { [weak self] (response) in
                guard let strongSelf = self else { return }

                switch response.result {
                case .success(let notices):
                    let notices = notices.list.sorted(by: { $0.dateline > $1.dateline })
                    strongSelf.state.value = .loaded(notices)
                case .failure(let error):
                    strongSelf.state.value = .error(.networkError(error))
                }
            }
        } else {
            state.value = .allLoaded([])
        }

        state.producer.startWithValues { (state) in
            switch state {
            case .loading:
                S1LogDebug("state -> loading")
            case .loaded(let data):
                S1LogDebug("state -> laoded(\(data.count))")
            case .fetchingMore(let data):
                S1LogDebug("state -> fetchingMore(\(data.count))")
            case .allLoaded(let data):
                S1LogDebug("state -> allLoaded(\(data.count))")
            case .error(let error):
                S1LogDebug("state -> error(\(error))")
            }
        }
    }
}

// MARK: - Output

extension NoticeViewModel {

    func numberOfItem() -> Int {
        return cellViewModels.value.count
    }

    func cellViewModel(at index: Int) -> NoticeCell.ViewModel {
        return cellViewModels.value[index]
    }
}
