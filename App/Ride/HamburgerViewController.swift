//
//  HamburgerViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import ECSlidingViewController
import Mixpanel
import MessageUI
import RouteRecorder

class HamburgerNavController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = [UIRectEdge.bottom, UIRectEdge.top, UIRectEdge.left]
    }
    
    @IBAction func unwind(_ segue: UIStoryboardSegue) {
        
    }
    
}

class HamburgerViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var accountTableViewCell: UITableViewCell!
    @IBOutlet weak var connectedAppsTableViewCell: UITableViewCell!
    @IBOutlet weak var pauseResueTableViewCell: UITableViewCell!
    @IBOutlet weak var sendReportTableViewCell: UITableViewCell!
    @IBOutlet weak var debugCrazyPersonTableViewCell: UITableViewCell!
    @IBOutlet weak var debugContinousPredictionTableViewCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.slidingViewController().topViewAnchoredGesture = [ECSlidingViewControllerAnchoredGesture.tapping, ECSlidingViewControllerAnchoredGesture.panning]
        self.tableView.backgroundColor = ColorPallete.shared.primary
        self.tableView.scrollsToTop = false // https://github.com/KnockSoftware/Ride/issues/204
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateAccountStatusText()
        self.updatePauseResumeText()
        #if DEBUG
            self.updateDebugCrazyPersonModeCellText()
            self.updateContinousPredictionsModeCellText()
        #endif
        self.tableView.reloadData()

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RideReportAPIClientAccountStatusDidChange"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
            DispatchQueue.main.async(execute: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.updateAccountStatusText()
            })
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RideReportAPIClientAccountStatusDidGetArea"), object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.tableView.reloadData()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateAccountStatusText() {
        switch RideReportAPIClient.shared.accountVerificationStatus {
        case .unknown:
            self.accountTableViewCell.isUserInteractionEnabled = false
            self.accountTableViewCell.textLabel?.textColor = ColorPallete.shared.unknownGrey
            self.accountTableViewCell.textLabel?.text = "Updating…"
        case .unverified:
            self.accountTableViewCell.isUserInteractionEnabled = true
            self.accountTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.accountTableViewCell.textLabel?.text = "Create Account"
        case .verified:
            self.accountTableViewCell.isUserInteractionEnabled = true
            self.accountTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.accountTableViewCell.textLabel?.text = "Log Out"
        }
        
    }
    
    func updatePauseResumeText() {
        if (RouteRecorder.shared.routeManager.isPaused()) {
            self.pauseResueTableViewCell.textLabel?.text = "Resume Ride Report"
        } else {
            self.pauseResueTableViewCell.textLabel?.text = "Pause Ride Report"
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        return CGFloat.leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        #if DEBUG
            return 7
        #else
            return 5
        #endif
    }
    
    #if DEBUG
    func updateDebugCrazyPersonModeCellText() {
        if (UserDefaults.standard.bool(forKey: "DebugVerbosityMode")) {
            self.debugCrazyPersonTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugCrazyPersonTableViewCell.accessoryType = UITableViewCellAccessoryType.checkmark
        } else {
            self.debugCrazyPersonTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugCrazyPersonTableViewCell.accessoryType = UITableViewCellAccessoryType.none
        }
    }

    func updateContinousPredictionsModeCellText() {
        if (UserDefaults.standard.bool(forKey: "DebugContinousMode")) {
            self.debugContinousPredictionTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugContinousPredictionTableViewCell.accessoryType = UITableViewCellAccessoryType.checkmark
        } else {
            self.debugContinousPredictionTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugContinousPredictionTableViewCell.accessoryType = UITableViewCellAccessoryType.none
        }
    }
    #endif
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        for case let button as UIButton in cell.subviews {
            let image = button.backgroundImage(for: .normal)?.withRenderingMode(.alwaysTemplate)
            button.tintColor = ColorPallete.shared.almostWhite
            button.setBackgroundImage(image, for: .normal)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        if (cell == self.sendReportTableViewCell) {
            self.sendLogFile()
        } else if (cell == self.debugCrazyPersonTableViewCell) {
            #if DEBUG
                let debugVerbosityMode = UserDefaults.standard.bool(forKey: "DebugVerbosityMode")
                UserDefaults.standard.set(!debugVerbosityMode, forKey: "DebugVerbosityMode")
                UserDefaults.standard.synchronize()
                self.updateDebugCrazyPersonModeCellText()
                self.tableView.deselectRow(at: indexPath, animated: true)
            #endif
        } else if (cell == self.debugContinousPredictionTableViewCell) {
            #if DEBUG
                let debugVerbosityMode = UserDefaults.standard.bool(forKey: "DebugContinousMode")
                UserDefaults.standard.set(!debugVerbosityMode, forKey: "DebugContinousMode")
                UserDefaults.standard.synchronize()
                self.updateContinousPredictionsModeCellText()
                self.tableView.deselectRow(at: indexPath, animated: true)
            #endif
        }  else if (cell == self.accountTableViewCell) {
            if (RideReportAPIClient.shared.accountVerificationStatus == .unverified) {
                AppDelegate.appDelegate().transitionToCreatProfile()
            } else if (RideReportAPIClient.shared.accountVerificationStatus == .verified){
                let alertController = UIAlertController(title: nil, message: "Your trips and other data will be removed from this iPhone but remain backed up in the cloud. You can log back in later to retrieve your data.", preferredStyle: UIAlertControllerStyle.actionSheet)
                alertController.addAction(UIAlertAction(title: "Log Out and Delete Data", style: UIAlertActionStyle.destructive, handler: { (_) in
                    RouteRecorder.shared.logout()
                    AppDelegate.appDelegate().logout()
                }))
                alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
                self.tableView.deselectRow(at: indexPath, animated: true)
            }
        } else if (cell == self.pauseResueTableViewCell) {
            if (RouteRecorder.shared.routeManager.isPaused()) {
                Mixpanel.mainInstance().track(
                    event: "resumedTracking"
                )
                RouteRecorder.shared.routeManager.resumeTracking()
                self.updatePauseResumeText()
                if let routesVC = (((self.view.window?.rootViewController as? ECSlidingViewController)?.topViewController as? UINavigationController)?.topViewController as? TripsViewController) {
                    routesVC.refreshHelperPopupUI()
                }
            } else {
                let updateUIBlock = {
                    self.updatePauseResumeText()
                    if let mainViewController = (((self.view.window?.rootViewController as? ECSlidingViewController)?.topViewController as? UINavigationController)?.topViewController as? TripsViewController) {
                        mainViewController.refreshHelperPopupUI()
                    }
                }
                
                let alertController = UIAlertController(title: "How Long Would You Like to Pause Ride Report?", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
                alertController.addAction(UIAlertAction(title: "Pause For an Hour", style: UIAlertActionStyle.default, handler: { (_) in
                    Mixpanel.mainInstance().track(
                        event: "pausedTracking",
                        properties: ["duration": "hour"]
                    )
                    RouteRecorder.shared.routeManager.pauseTracking(Date().hoursFrom(1))
                    updateUIBlock()
                }))
                alertController.addAction(UIAlertAction(title: "Pause Until Tomorrow", style: UIAlertActionStyle.default, handler: { (_) in
                    Mixpanel.mainInstance().track(
                        event: "pausedTracking",
                        properties: ["duration": "day"]
                    )
                    RouteRecorder.shared.routeManager.pauseTracking(Date.tomorrow())
                    updateUIBlock()
                }))
                alertController.addAction(UIAlertAction(title: "Pause For a Week", style: UIAlertActionStyle.default, handler: { (_) in
                    Mixpanel.mainInstance().track(
                        event: "pausedTracking",
                        properties: ["duration": "week"]
                    )
                    RouteRecorder.shared.routeManager.pauseTracking(Date.nextWeek())
                    updateUIBlock()
                }))
                alertController.addAction(UIAlertAction(title: "Pause For Now", style: UIAlertActionStyle.default, handler: { (_) in
                    Mixpanel.mainInstance().track(
                        event: "pausedTracking",
                        properties: ["duration": "indefinite"]
                    )
                    RouteRecorder.shared.routeManager.pauseTracking()
                    updateUIBlock()
                }))
                
                alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
            
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func sendLogFile() {
        guard MFMailComposeViewController.canSendMail() else {
            let alert = UIAlertView(title:"No email account", message: "Whoops, it looks like you don't have an email account configured on this iPhone", delegate: nil, cancelButtonTitle:"Ima Fix It")
            alert.show()
            return
        }
        
        let fileInfos = AppDelegate.appDelegate().fileLogger.logFileManager.sortedLogFileInfos
        if (fileInfos == nil || fileInfos?.count == 0) {
            return
        }
        
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown Version"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let osNumber = UIDevice.current.systemVersion
        let phoneModel = UIDevice.current.deviceModel()
        let supportId = Profile.profile().supportId ?? ""
        let body = String(format: "Tell us briefly what happened.\n\n\n\n\n=====================\n Support Id: %@\nVersion:%@ (%@)\niOS Version: %@\niPhone Model: %@", supportId, versionNumber, buildNumber, osNumber, phoneModel!)
        
        let composer = MFMailComposeViewController()
        composer.setSubject("Ride Report Bug Report " + supportId)
        composer.setToRecipients(["logs@ride.report"])
        composer.mailComposeDelegate = self
        composer.setMessageBody(body as String, isHTML: false)
        
        for fileInfo in fileInfos! {
            if let filePath = fileInfo.filePath, let fileData = NSData(contentsOf: NSURL(fileURLWithPath: filePath) as URL) {
                composer.addAttachmentData(fileData as Data, mimeType: "text/plain", fileName: fileInfo.fileName)
            }
        }
        
        
        self.present(composer, animated:true, completion:nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
}


