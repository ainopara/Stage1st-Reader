//
//  ReorderForumViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 2020/3/7.
//  Copyright © 2020 Renaissance. All rights reserved.
//

import Foundation

@objc
final class ReorderForumViewController: UIViewController {

    let tableView = UITableView(frame: .zero, style: .grouped)

    var forumGroups: [[ForumInfo]] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        let forums = (try? JSONDecoder().decode(ForumBundle.self, from: AppEnvironment.current.settings.forumBundle.value))?.forums ?? []
        let order = AppEnvironment.current.settings.forumOrderV2.value
        let selectedForums = order.compactMap { id in forums.first { forum in forum.id == id } }
        let otherForums = forums.filter { !Set(order).contains($0.id) }
        forumGroups = [selectedForums, otherForums]

        tableView.delegate = self
        tableView.dataSource = self
        tableView.isEditing = true
        view.addSubview(tableView)

        tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(view)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppEnvironment.current.settings.forumOrderV2.value = forumGroups[0].map { $0.id }
    }
}

extension ReorderForumViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return forumGroups[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "forum")  ?? UITableViewCell(style: .value1, reuseIdentifier: "forum")

        cell.selectionStyle = .none
        cell.showsReorderControl = true
        cell.textLabel?.text = forumGroups[indexPath.section][indexPath.item].name
        return cell

    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let removedForum = forumGroups[sourceIndexPath.section].remove(at: sourceIndexPath.item)
        forumGroups[destinationIndexPath.section].insert(removedForum, at: destinationIndexPath.item)
        tableView.reloadData()
    }
}

extension ReorderForumViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
}
