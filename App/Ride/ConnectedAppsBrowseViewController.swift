
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
    
    var selectedConnectedApp: ConnectedApp? = nil
    private var safariViewController: UIViewController? = nil
    private var safariViewControllerActivityIndicator: UIActivityIndicatorView? = nil
    private var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>!
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.emptyTableView.isHidden = true
        
        self.coreDataDidLoad()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func coreDataDidLoad() {
        let cacheName = "ConnectedAppsBrowserFetchedResultsController"
        let context = CoreDataManager.shared.currentManagedObjectContext()
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: cacheName)
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ConnectedApp")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchedRequest.predicate = NSPredicate(format: "profile == nil")
        
        self.fetchedResultsController = NSFetchedResultsController<NSFetchRequestResult>(fetchRequest:fetchedRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName:cacheName )
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
    
    override func viewWillAppear(_ animated: Bool) {
        self.slidingViewController().anchorRightRevealAmount = 276.0 // the default
        self.slidingViewController().viewDidLayoutSubviews()
        APIClient.shared.getAllApplications().apiResponse { _ in
            self.refreshEmptyTableView()
        }
        
        if let indexPath = tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        
        if (self.selectedConnectedApp != nil) {
            // if we've already been told to select an app
            self.handleSelectedApp(fromList: false)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    //
    // MARK: - Fetched Results Controller
    //
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
        
        self.refreshEmptyTableView()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch(type) {
            
        case .update:
            if let path = newIndexPath, let app = self.fetchedResultsController.object(at: path) as? ConnectedApp,
                let cell = self.tableView!.cellForRow(at: IndexPath(row: indexPath!.row, section: indexPath!.section + 1)) {
                configureCell(cell, app:app)
            }
        case .insert:
            self.tableView!.insertRows(at: [IndexPath(row: newIndexPath!.row, section: newIndexPath!.section + 1)], with: UITableViewRowAnimation.fade)
        case .delete:
            self.tableView!.deleteRows(at: [IndexPath(row: indexPath!.row, section: indexPath!.section + 1)], with: UITableViewRowAnimation.fade)
        case .move:
            self.tableView!.deleteRows(at: [IndexPath(row: indexPath!.row, section: indexPath!.section + 1)],
                                                   with: UITableViewRowAnimation.fade)
            self.tableView!.insertRows(at: [IndexPath(row: newIndexPath!.row, section: newIndexPath!.section + 1)],
                                                   with: UITableViewRowAnimation.fade)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return UserDefaults.standard.bool(forKey: "healthKitIsSetup") ? 0 : 1
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
            self.emptyTableView.isHidden = true
            return
        }
        
        if self.tableView.numberOfRows(inSection: 0) + self.tableView.numberOfRows(inSection: 1) > 0 {
            self.emptyTableView.isHidden = true
        } else {
            self.emptyTableView.isHidden = false
        }
    }
    
    
    func configureCell(_ tableCell: UITableViewCell, app: ConnectedApp) {
        if let nameLabel = tableCell.viewWithTag(1) as? UILabel,
            let descriptionLabel = tableCell.viewWithTag(2) as? UILabel,
            let imageView = tableCell.viewWithTag(3) as? UIImageView {
            nameLabel.text = app.name
            descriptionLabel.text = app.descriptionText
            
            if let urlString = app.baseImageUrl, let url = URL(string: urlString) {
                imageView.kf.setImage(with: url)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            // handled by storyboard
        } else {
            guard let app = self.fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: 0)) as? ConnectedApp else {
                self.tableView.deselectRow(at: indexPath, animated: true)
                return
            }

            self.tableView.deselectRow(at: indexPath, animated: true)
            
            self.selectedConnectedApp = app
            self.handleSelectedApp(fromList: true)
        }
    }
    
    func handleSelectedApp(fromList: Bool) {
        guard let urlString = self.selectedConnectedApp?.webAuthorizeUrl, let url = URL(string: urlString), url.host != nil else {
            // if there is no authorize url, go straight to permissions screen
            self.performSegue(withIdentifier: "showConnectAppConfirmViewController", sender: self)
            return
        }
        
        if url.scheme != "https" {
            return
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(ConnectedAppsBrowseViewController.authCodeCallbackNotificationReceived), name: NSNotification.Name(rawValue: "RideReportAuthCodeCallBackNotification"), object: nil)
        
        if #available(iOS 9.0, *) {
            let sfvc = SFSafariViewController(url: url)
            self.safariViewController = sfvc
            sfvc.delegate = self
            if (fromList) {
                self.navigationController?.pushViewController(sfvc, animated: true)
            } else {
                self.navigationController?.pushViewController(sfvc, animated: false)
                sfvc.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.plain, target: AppDelegate.appDelegate(), action: #selector(AppDelegate.dismissCurrentPresentedViewController))
            }
            if let coordinator = transitionCoordinator {
                coordinator.animate(alongsideTransition: nil, completion: { (context) in
                    let targetSubview = sfvc.view
                    let loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
                    loadingIndicator.color = ColorPallete.shared.darkGrey
                    self.safariViewControllerActivityIndicator = loadingIndicator
                    loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
                    targetSubview?.addSubview(loadingIndicator)
                    NSLayoutConstraint(item: loadingIndicator, attribute: .centerY, relatedBy: NSLayoutRelation.equal, toItem: targetSubview, attribute: .centerY, multiplier: 1, constant: 0).isActive = true
                    NSLayoutConstraint(item: loadingIndicator, attribute: .centerX, relatedBy: NSLayoutRelation.equal, toItem: targetSubview, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
                    loadingIndicator.startAnimating()
                })
            }
        } else {
            UIApplication.shared.openURL(url)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return CGFloat.leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let tableCell = self.tableView.dequeueReusableCell(withIdentifier: "HealthAppCell", for: indexPath)
            if #available(iOS 10.0, *) {
                if WatchManager.shared.paired {
                    // if a watch is paired
                    if let nameLabel = tableCell.viewWithTag(1) as? UILabel,
                        let descriptionLabel = tableCell.viewWithTag(2) as? UILabel {
                        nameLabel.text = "Apple Watch"
                        descriptionLabel.text = "Automatically save your rides to your Apple Watch."
                    }
                }
            }
            
            return tableCell
        } else {
            let tableCell = self.tableView.dequeueReusableCell(withIdentifier: "ConnectedAppCell", for: indexPath)
            if let app = self.fetchedResultsController.object(at: IndexPath(row: indexPath.row, section: 0)) as? ConnectedApp {
                self.configureCell(tableCell, app: app)
            }
            return tableCell
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showConnectAppConfirmViewController") {
            if let app = self.selectedConnectedApp,
                let appVC = segue.destination as? ConnectedAppConfirmViewController {
                appVC.connectingApp = app
                
                self.selectedConnectedApp = nil
            }
        }
    }
    
    func authCodeCallbackNotificationReceived(_ notification: Notification) {
        if let _ = self.safariViewController, let callbackUrl = notification.object as? URL, let app = self.selectedConnectedApp {
            let uuid = callbackUrl.lastPathComponent
            if uuid == app.uuid {
                if let code = URLComponents(url: callbackUrl, resolvingAgainstBaseURL: false)?.queryItems?.filter({ $0.name == "code" }).first?.value {
                    NotificationCenter.default.removeObserver(self)
                    
                    app.authorizationCode = code
                    
                    if #available(iOS 9.0, *) {
                        // Avoid a possible scenario where didCompleteInitialLoad gets called with didLoadSuccessfully=false because the webpage
                        // decided to callback early. This can happen if the user is already logged in.
                        // We delay showPageLoadError to give authCodeCallbackNotificationReceived a chance to callback
                        
                        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ConnectedAppsBrowseViewController.showPageLoadError), object: nil)
                        if let sfc = self.safariViewController as? SFSafariViewController {
                            sfc.delegate = nil
                        }
                    }

                    self.performSegue(withIdentifier: "showConnectAppConfirmViewController", sender: self)
                } else if let _ = URLComponents(url: callbackUrl, resolvingAgainstBaseURL: false)?.queryItems?.filter({ $0.name == "error" }).first?.value {
                    self.navigationController?.popViewController(animated: true)
                }
            } else {
                // For now, ignore this edge case because we only have one app.
                // The right thing to do here may be to look up the app by the uuid and show that app
            }
        }
    }
    
    @objc private func showPageLoadError() {
        let alertController = UIAlertController(title:nil, message: String(format: "Ride Report cannot connect to %@. Please try again later.", self.selectedConnectedApp?.name ?? "App"), preferredStyle: UIAlertControllerStyle.actionSheet)
        alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.destructive, handler: { (_) in
            self.navigationController?.popViewController(animated: true)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    @available(iOS 9.0, *)
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        if let loadingIndicator = self.safariViewControllerActivityIndicator {
            loadingIndicator.removeFromSuperview()
            self.safariViewControllerActivityIndicator = nil
        }
        
        if !didLoadSuccessfully {
            self.perform(#selector(ConnectedAppsBrowseViewController.showPageLoadError), with: nil, afterDelay: 1.0)
        }
    }
}
