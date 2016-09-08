
//
//  ConnectedAppsBrowseViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import Kingfisher
import SafariServices
import WatchConnectivity

class ConnectedAppsBrowseViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate, SFSafariViewControllerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableView: UIView!
    
    private var selectedConnectedApp: ConnectedApp? = nil
    private var safariViewController: UIViewController? = nil
    private var safariViewControllerActivityIndicator: UIActivityIndicatorView? = nil
    private var fetchedResultsController : NSFetchedResultsController! = nil
    
    @IBAction func cancel(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.emptyTableView.hidden = true
        
        self.coreDataDidLoad()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func coreDataDidLoad() {
        let cacheName = "ConnectedAppsBrowserFetchedResultsController"
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        NSFetchedResultsController.deleteCacheWithName(cacheName)
        let fetchedRequest = NSFetchRequest(entityName: "ConnectedApp")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchedRequest.predicate = NSPredicate(format: "profile == nil")
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: nil, cacheName:cacheName )
        self.fetchedResultsController.delegate = self
        do {
            try self.fetchedResultsController.performFetch()
        } catch let error {
            DDLogError("Error loading connected apps view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        self.slidingViewController().anchorRightRevealAmount = 276.0 // the default
        self.slidingViewController().viewDidLayoutSubviews()
        APIClient.sharedClient.getAllApplications().apiResponse { _ in
            self.refreshEmptyTableView()
        }
        
        if let indexPath = tableView.indexPathForSelectedRow {
            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    //
    // MARK: - Fetched Results Controller
    //
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
        
        self.refreshEmptyTableView()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch(type) {
            
        case .Update:
            if let path = indexPath, app = self.fetchedResultsController.objectAtIndexPath(path) as? ConnectedApp,
                cell = self.tableView!.cellForRowAtIndexPath(NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)) {
                configureCell(cell, app:app)
            }
        case .Insert:
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: newIndexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
        case .Delete:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)], withRowAnimation: UITableViewRowAnimation.Fade)
        case .Move:
            self.tableView!.deleteRowsAtIndexPaths([NSIndexPath(forRow: indexPath!.row, inSection: indexPath!.section + 1)],
                                                   withRowAnimation: UITableViewRowAnimation.Fade)
            self.tableView!.insertRowsAtIndexPaths([NSIndexPath(forRow: newIndexPath!.row, inSection: newIndexPath!.section + 1)],
                                                   withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return NSUserDefaults.standardUserDefaults().boolForKey("healthKitIsSetup") ? 0 : 1
        }
        
        let sectionInfo = self.fetchedResultsController.sections![0]
        return sectionInfo.numberOfObjects
    }
    
    //
    // MARK: - Table View
    //
    
    private func refreshEmptyTableView() {
        guard let _ = self.fetchedResultsController else {
            // Core Data hasn't loaded yet
            self.emptyTableView.hidden = true
            return
        }
        
        if self.tableView.numberOfRowsInSection(0) + self.tableView.numberOfRowsInSection(1) > 0 {
            self.emptyTableView.hidden = true
        } else {
            self.emptyTableView.hidden = false
        }
    }
    
    
    func configureCell(tableCell: UITableViewCell, app: ConnectedApp) {
        if let nameLabel = tableCell.viewWithTag(1) as? UILabel,
            descriptionLabel = tableCell.viewWithTag(2) as? UILabel,
            imageView = tableCell.viewWithTag(3) as? UIImageView {
            nameLabel.text = app.name
            descriptionLabel.text = app.descriptionText
            
            if let urlString = app.baseImageUrl, url = NSURL(string: urlString) {
                imageView.kf_setImageWithURL(url)
            }
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            // handled by storyboard
        } else {
            guard let app = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: 0)) as? ConnectedApp else {
                self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
                return
            }

            guard let urlString = app.webAuthorizeUrl, url = NSURL(string: urlString) where url.host != nil else {
                // if there is no authorize url, go straight to permissions screen
                self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
                self.selectedConnectedApp = app
                self.performSegueWithIdentifier("showConnectAppConfirmViewController", sender: self)
                return
            }
            
            if url.scheme != "https" {
                self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
                return
            }
            
            
            self.selectedConnectedApp = app
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ConnectedAppsBrowseViewController.authCodeCallbackNotificationReceived), name: "RideReportAuthCodeCallBackNotification", object: nil)
            
            if #available(iOS 9.0, *) {
                let sfvc = SFSafariViewController(URL: url)
                self.safariViewController = sfvc
                sfvc.delegate = self
                self.navigationController?.pushViewController(sfvc, animated: true)
                if let coordinator = transitionCoordinator() {
                    coordinator.animateAlongsideTransition(nil, completion: { (context) in
                        let targetSubview = sfvc.view
                        let loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
                        loadingIndicator.color = ColorPallete.sharedPallete.darkGrey
                        self.safariViewControllerActivityIndicator = loadingIndicator
                        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
                        targetSubview.addSubview(loadingIndicator)
                        NSLayoutConstraint(item: loadingIndicator, attribute: .CenterY, relatedBy: NSLayoutRelation.Equal, toItem: targetSubview, attribute: .CenterY, multiplier: 1, constant: 0).active = true
                        NSLayoutConstraint(item: loadingIndicator, attribute: .CenterX, relatedBy: NSLayoutRelation.Equal, toItem: targetSubview, attribute: .CenterX, multiplier: 1, constant: 0).active = true
                        loadingIndicator.startAnimating()
                    })
                }
            } else {
                UIApplication.sharedApplication().openURL(url)
            }
        }
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return CGFloat.min
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let tableCell = self.tableView.dequeueReusableCellWithIdentifier("HealthAppCell", forIndexPath: indexPath)
            if #available(iOS 10.0, *) {
                if WCSession.isSupported() {
                    // if a watch is paired
                    if let nameLabel = tableCell.viewWithTag(1) as? UILabel,
                        descriptionLabel = tableCell.viewWithTag(2) as? UILabel {
                        nameLabel.text = "Apple Watch"
                        descriptionLabel.text = "Automatically save your rides to your Apple Watch."
                    }
                }
            }
            
            return tableCell
        } else {
            let tableCell = self.tableView.dequeueReusableCellWithIdentifier("ConnectedAppCell", forIndexPath: indexPath)
            if let app = self.fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: indexPath.row, inSection: 0)) as? ConnectedApp {
                self.configureCell(tableCell, app: app)
            }
            return tableCell
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "showConnectAppConfirmViewController") {
            if let app = self.selectedConnectedApp,
                appVC = segue.destinationViewController as? ConnectedAppConfirmViewController {
                appVC.connectingApp = app
                
                self.selectedConnectedApp = nil
            }
        }
    }
    
    func authCodeCallbackNotificationReceived(notification: NSNotification) {
        if let _ = self.safariViewController, callbackUrl = notification.object as? NSURL, app = self.selectedConnectedApp,
            uuid = callbackUrl.lastPathComponent {
            if uuid == app.uuid {
                if let code = NSURLComponents(URL: callbackUrl, resolvingAgainstBaseURL: false)?.queryItems?.filter({ $0.name == "code" }).first?.value {
                    NSNotificationCenter.defaultCenter().removeObserver(self)
                    
                    app.authorizationCode = code
                    
                    if #available(iOS 9.0, *) {
                        // Avoid a possible scenario where didCompleteInitialLoad gets called with didLoadSuccessfully=false because the webpage
                        // decided to callback early. This can happen if the user is already logged in.
                        // We delay showPageLoadError to give authCodeCallbackNotificationReceived a chance to callback
                        
                        NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(ConnectedAppsBrowseViewController.showPageLoadError), object: nil)
                        if let sfc = self.safariViewController as? SFSafariViewController {
                            sfc.delegate = nil
                        }
                    }

                    self.performSegueWithIdentifier("showConnectAppConfirmViewController", sender: self)
                } else if let _ = NSURLComponents(URL: callbackUrl, resolvingAgainstBaseURL: false)?.queryItems?.filter({ $0.name == "error" }).first?.value {
                    self.navigationController?.popViewControllerAnimated(true)
                }
            } else {
                // For now, ignore this edge case because we only have one app.
                // The right thing to do here may be to look up the app by the uuid and show that app
            }
        }
    }
    
    @objc private func showPageLoadError() {
        let alertController = UIAlertController(title:nil, message: String(format: "Ride Report cannot connect to %@. Please try again later.", self.selectedConnectedApp?.name ?? "App"), preferredStyle: UIAlertControllerStyle.ActionSheet)
        alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.Destructive, handler: { (_) in
            self.navigationController?.popViewControllerAnimated(true)
        }))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    @available(iOS 9.0, *)
    func safariViewController(controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        if let loadingIndicator = self.safariViewControllerActivityIndicator {
            loadingIndicator.removeFromSuperview()
            self.safariViewControllerActivityIndicator = nil
        }
        
        if !didLoadSuccessfully {
            self.performSelector(#selector(ConnectedAppsBrowseViewController.showPageLoadError), withObject: nil, afterDelay: 1.0)
        }
    }
}
