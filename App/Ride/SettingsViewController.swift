//
//  SettingsViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Mixpanel
import MessageUI
import RouteRecorder

class SettingsViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var accountTableViewCell: UITableViewCell!
    @IBOutlet weak var connectedAppsTableViewCell: UITableViewCell!
    @IBOutlet weak var pauseResueTableViewCell: UITableViewCell!
    @IBOutlet weak var sendReportTableViewCell: UITableViewCell!
    @IBOutlet weak var debugCrazyPersonTableViewCell: UITableViewCell!
    @IBOutlet weak var debugContinousPredictionTableViewCell: UITableViewCell!
    
    var shouldShowDebugRows = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.scrollsToTop = false // https://github.com/KnockSoftware/Ride/issues/204
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateAccountStatusText()
        self.updatePauseResumeText()
        #if MDEBUG
            shouldShowDebugRows = true
            
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
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RouteManagerDidPauseOrResume"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updatePauseResumeText()
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
            self.accountTableViewCell.textLabel?.text = " Updating…"
        case .unverified:
            self.accountTableViewCell.isUserInteractionEnabled = true
            self.accountTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.accountTableViewCell.textLabel?.text = "🚨 Create Account"
        case .verified:
            self.accountTableViewCell.isUserInteractionEnabled = true
            self.accountTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.accountTableViewCell.textLabel?.text = "🚪 Log Out"
        }
        
    }
    
    func updatePauseResumeText() {
        if (RouteRecorder.shared.routeManager.isPaused()) {
            self.pauseResueTableViewCell.textLabel?.text = "▶️ Resume Ride Report"
        } else {
            self.pauseResueTableViewCell.textLabel?.text = "⏸ Pause Ride Report"
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row > 1 && !shouldShowDebugRows {
            return 0
        }
        
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            if (RideReportAPIClient.shared.accountVerificationStatus == .verified) {
                if let emailAddress = RideReportAPIClient.shared.accountEmailAddress {
                    return emailAddress
                } else if let fullName = RideReportAPIClient.shared.accountFacebookName {
                    return "Logged in with Facebook as " + fullName
                } else {
                    return "Logged in"
                }
            } else {
                return "Don't lose your rides!"
            }
        }
        
        return ""
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if (RideReportAPIClient.shared.accountVerificationStatus == .verified) && section == 1 {
            return "Create an account so you can recover your rides if your phone is lost."
        }
        
        return ""
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // returning 0 uses the default, not what you think it does
        if section == 1 {
            return 60.0
        }
        return 30.0
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if (RideReportAPIClient.shared.accountVerificationStatus != .verified) && section == 1 {
            return 50.0
        }
        
        return CGFloat.leastNormalMagnitude
    }
    
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        if (cell == self.sendReportTableViewCell) {
            self.sendLogFile()
        } else if (cell == self.debugCrazyPersonTableViewCell) {
                let debugVerbosityMode = UserDefaults.standard.bool(forKey: "DebugVerbosityMode")
                UserDefaults.standard.set(!debugVerbosityMode, forKey: "DebugVerbosityMode")
                UserDefaults.standard.synchronize()
                self.updateDebugCrazyPersonModeCellText()
                self.tableView.deselectRow(at: indexPath, animated: true)
        } else if (cell == self.debugContinousPredictionTableViewCell) {
                let debugVerbosityMode = UserDefaults.standard.bool(forKey: "DebugContinousMode")
                UserDefaults.standard.set(!debugVerbosityMode, forKey: "DebugContinousMode")
                UserDefaults.standard.synchronize()
                self.updateContinousPredictionsModeCellText()
                self.tableView.deselectRow(at: indexPath, animated: true)
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
            } else {
                let updateUIBlock = {
                    self.updatePauseResumeText()
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
            let alertController = UIAlertController(title: "No email account", message: "Whoops, it looks like you don't have an email account configured on this iPhone. Please add one and try again.", preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "On it", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            
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


