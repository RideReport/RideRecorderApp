//
//  SettingsViewController.swift
//  Ride
//
//  Created by William Henderson on 9/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import MessageUI
import RouteRecorder

class SettingsViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var pauseResueTableViewCell: UITableViewCell!
    @IBOutlet weak var sendReportTableViewCell: UITableViewCell!
    @IBOutlet weak var debugCrazyPersonTableViewCell: UITableViewCell!
    @IBOutlet weak var debugContinousPredictionTableViewCell: UITableViewCell!
    @IBOutlet weak var manuallyStartRideTableViewCell: UITableViewCell!
    
    var shouldShowDebugRows = false
    
    var shouldShowManualStartOption: Bool {
        true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.scrollsToTop = false // https://github.com/KnockSoftware/Ride/issues/204
        
        self.tableView.estimatedSectionHeaderHeight = 18.0
        self.tableView.estimatedSectionFooterHeight = 18.0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updatePauseResumeText()
        #if MDEBUG
            shouldShowDebugRows = true
            
            self.updateDebugCrazyPersonModeCellText()
            self.updateContinousPredictionsModeCellText()
        #endif
        self.tableView.reloadData()

        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RouteManagerDidPauseOrResume"), object: nil, queue: nil) {[weak self] (notification : Notification) -> Void in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updatePauseResumeText()
        }
        
        if let index = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: index, animated: false)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    
    func updatePauseResumeText() {
        if (RouteRecorder.shared.routeManager.isPaused()) {
            self.pauseResueTableViewCell.textLabel?.text = "▶️ Resume Trip Tracking"
        } else {
            self.pauseResueTableViewCell.textLabel?.text = "⏸ Pause Trip Tracking"
        }
    }
    
    func updateManualStartText() {
        self.manuallyStartRideTableViewCell.isSelected = false
         if RouteRecorder.shared.routeManager.isBikeTripInProgress() {
            self.manuallyStartRideTableViewCell.textLabel?.text = "🛑 Manually Stop Bike Ride"
        }
         else {
            self.manuallyStartRideTableViewCell.textLabel?.text = "🚲 Manually Start Bike Ride"
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath.section == 0 && indexPath.row > 1 && indexPath.row < 4 && !shouldShowDebugRows) || ((indexPath.section == 0 && indexPath.row == 5 && !shouldShowManualStartOption)) {
            return 0
        }
        
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
 
        return ""
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
  
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
   
        return CGFloat.leastNormalMagnitude
    }
    
    func updateDebugCrazyPersonModeCellText() {
        if (UserDefaults.standard.bool(forKey: "DebugVerbosityMode")) {
            self.debugCrazyPersonTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugCrazyPersonTableViewCell.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            self.debugCrazyPersonTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugCrazyPersonTableViewCell.accessoryType = UITableViewCell.AccessoryType.none
        }
    }

    func updateContinousPredictionsModeCellText() {
        if (UserDefaults.standard.bool(forKey: "DebugContinousMode")) {
            self.debugContinousPredictionTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugContinousPredictionTableViewCell.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            self.debugContinousPredictionTableViewCell.textLabel?.textColor = self.pauseResueTableViewCell.textLabel?.textColor
            self.debugContinousPredictionTableViewCell.accessoryType = UITableViewCell.AccessoryType.none
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
        } else if (cell == self.manuallyStartRideTableViewCell) {
            if RouteRecorder.shared.routeManager.isBikeTripInProgress() {
                RouteRecorder.shared.routeManager.stopRoute()
            }
            else {
                RouteRecorder.shared.routeManager.manuallyStartBikeTrip()
                
            }
            self.updateManualStartText()
        } else if (cell == self.pauseResueTableViewCell) {
            if (RouteRecorder.shared.routeManager.isPaused()) {
                RouteRecorder.shared.routeManager.resumeTracking()
                self.updatePauseResumeText()
            } else {
                let updateUIBlock = {
                    self.updatePauseResumeText()
                }
                
                let alertController = UIAlertController(title: "How Long Would You Like to Pause Trip Tracking?", message: nil, preferredStyle: UIAlertController.Style.actionSheet)
                alertController.addAction(UIAlertAction(title: "Pause For an Hour", style: UIAlertAction.Style.default, handler: { (_) in
                    RouteRecorder.shared.routeManager.pauseTracking(Date().hoursFrom(1))
                    updateUIBlock()
                }))
                alertController.addAction(UIAlertAction(title: "Pause Until Tomorrow", style: UIAlertAction.Style.default, handler: { (_) in
                    RouteRecorder.shared.routeManager.pauseTracking(Date.tomorrow())
                    updateUIBlock()
                }))
                alertController.addAction(UIAlertAction(title: "Pause For a Week", style: UIAlertAction.Style.default, handler: { (_) in
                    RouteRecorder.shared.routeManager.pauseTracking(Date.nextWeek())
                    updateUIBlock()
                }))
                alertController.addAction(UIAlertAction(title: "Pause For Now", style: UIAlertAction.Style.default, handler: { (_) in
                    RouteRecorder.shared.routeManager.pauseTracking()
                    updateUIBlock()
                }))
                
                alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
            
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func sendLogFile() {
        guard MFMailComposeViewController.canSendMail() else {
            let alertController = UIAlertController(title: "No email account", message: "Whoops, it looks like you don't have an email account configured on this iPhone. Please add one and try again.", preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "On it", style: UIAlertAction.Style.cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        
        let fileInfos = AppDelegate.appDelegate().fileLogger.logFileManager.sortedLogFileInfos
        if (fileInfos == nil || fileInfos.count == 0) {
            return
        }
        
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown Version"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let osNumber = UIDevice.current.systemVersion
        let phoneModel = UIDevice.current.deviceModel()
        let body = String(format: "Tell us briefly what happened.\n\n\n\n\n=====================\n Version:%@ (%@)\niOS Version: %@\niPhone Model: %@", versionNumber, buildNumber, osNumber, phoneModel!)
        
        let composer = MFMailComposeViewController()
        composer.setSubject("Bug Report")

        composer.mailComposeDelegate = self
        composer.setMessageBody(body as String, isHTML: false)
        
        for fileInfo in fileInfos {
            let filePath = fileInfo.filePath
            if let fileData = NSData(contentsOf: NSURL(fileURLWithPath: filePath) as URL) {
                composer.addAttachmentData(fileData as Data, mimeType: "text/plain", fileName: fileInfo.fileName)
            }
        }
        
        
        self.present(composer, animated:true, completion:nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
}


