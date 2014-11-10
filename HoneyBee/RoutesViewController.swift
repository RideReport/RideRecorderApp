//
//  RoutesViewController.swift
//  HoneyBee
//
//  Created by William Henderson on 10/30/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class RoutesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    private var trips : [Trip]! = nil
    private var dateFormatter : NSDateFormatter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.trips = Trip.allTrips() as [Trip]!
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.locale = NSLocale.currentLocale()
        self.dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH;mm;ss"
    }
    
    @IBAction func done(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.trips.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let trip = trips[indexPath.row]
        let reuseID = "RoutesViewTableCell"
        
        var tableCell = self.tableView.dequeueReusableCellWithIdentifier(reuseID) as UITableViewCell?
        if (tableCell == nil) {
            tableCell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: reuseID)
        }
        tableCell!.textLabel.text = self.dateFormatter.stringFromDate(trip.creationDate)
        if (trip.locations != nil) {
            tableCell!.detailTextLabel!.text = NSString(format: "Points: %i", trip.locations.count)
        } else {
            tableCell!.detailTextLabel!.text = "No locations"
        }
        
        return tableCell!
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let viewController = self.presentingViewController
        if (viewController != nil && viewController!.isKindOfClass(ViewController)) {
            (viewController as ViewController).setSelectedTrip(trips[indexPath.row])
        }
        
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}