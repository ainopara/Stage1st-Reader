//
//  S1QuoteFloorViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 7/12/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

import UIKit
import JTSImageViewController
import Crashlytics

class S1QuoteFloorViewController: UIViewController {
    var htmlString: String?
    var topic: S1Topic?
    var floors: [S1Floor]?
    var centerFloorID: Int = 0
    
    @IBOutlet weak var tableView: UITableView!

    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = APColorManager.sharedInstance.colorForKey("content.background")
        self.tableView.backgroundColor = APColorManager.sharedInstance.colorForKey("content.background")
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.separatorStyle = .None
        self.tableView.estimatedRowHeight = 100.0
        
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        Crashlytics.sharedInstance().setObjectValue("QuoteViewController", forKey: "lastViewController")
    }
    

}
    // MARK: - Table View Delegate
extension S1QuoteFloorViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.floors?.count ?? 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: S1QuoteFloorCell = tableView.dequeueReusableCellWithIdentifier("QuoteCell") as? S1QuoteFloorCell ?? S1QuoteFloorCell(style:.Default,reuseIdentifier:"QuoteCell")
        let floor = self.floors![indexPath.row]
        let viewModel = FloorViewModel(floorModel: floor, topicModel: self.topic!)
        cell.updateWithViewModel(viewModel)

        return cell
    }
}