//
//  InMemoryLogViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 1/25/17.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import UIKit
import SnapKit

private let reuseIdentifier = "InMemoryLogTableCell"

public final class InMemoryLogViewController: UIViewController {
    let logger: InMemoryLogger

    var snapshot: [String]

    let tableView = UITableView(frame: .zero, style: .plain)
    public init(inMemoryLogger: InMemoryLogger = InMemoryLogger.shared) {
        self.logger = inMemoryLogger
        self.snapshot = inMemoryLogger.messageQueue

        super.init(nibName: nil, bundle: nil)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44.0
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let refreshItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(InMemoryLogViewController.refreshButtonDidTapped))
        navigationItem.setRightBarButton(refreshItem, animated: false)

        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(view)
        }

        // Do any additional setup after loading the view.
    }

    public func refreshButtonDidTapped() {
        snapshot = logger.messageQueue
        tableView.reloadData()
    }
}

extension InMemoryLogViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension InMemoryLogViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snapshot.count
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = snapshot[indexPath.row]
        return cell
    }
}
