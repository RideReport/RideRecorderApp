//
//  SetupConfirmEmailViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import RouteRecorder

class SetupConfirmEmailViewController: SetupChildViewController, BKPasscodeInputViewDelegate {
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var passcodeInputView : BKPasscodeInputView!
    @IBOutlet weak var passcodeInputViewBottomLayoutConstraint: NSLayoutConstraint!
    
    private var pollTimer : Timer? = nil
    private var timeOfInitialPresesntation : Date? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.passcodeInputView.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle
        self.passcodeInputView.keyboardType = UIKeyboardType.numberPad
        self.passcodeInputView.keyboardAppearance = UIKeyboardAppearance.light
        self.passcodeInputView.delegate = self
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.plain, target: self, action: #selector(SetupConfirmEmailViewController.back))
    }
    
    @objc func back() {
        self.parentSetupViewController?.previousPage(sender: self)
    }
    
    override func childViewControllerWillPresent(_ userInfo: [String: Any]? = nil) {
        super.childViewControllerWillPresent(userInfo)
        
        let _ = self.view.subviews // hack for a gross crash.
        
        self.timeOfInitialPresesntation = Date()
        
        if let shortCode = userInfo?["shortcodeLength"] as! Int? {
            self.passcodeInputView.maximumLength = UInt(shortCode)
            if self.passcodeInputView.maximumLength > 4 {
                self.passcodeInputView.drawsPasscodeSeparator = true
            }
            self.passcodeInputView.isHidden = false
            helperTextLabel.markdownStringValue = "**Enter the secret code** in the email we just sent."
        
            // make sure the keyboard does not animate in initially.
            UIView.setAnimationsEnabled(false)
            NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardDidShow, object: nil, queue: nil) {[weak self] (notif) -> Void in
                UIView.setAnimationsEnabled(true)

                guard let strongSelf = self else {
                    return
                }
                NotificationCenter.default.removeObserver(strongSelf, name: NSNotification.Name.UIKeyboardDidShow, object: nil)
            }
            self.passcodeInputView.becomeFirstResponder()
        } else {
            self.showVerifyViaButtonUI()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(SetupConfirmEmailViewController.layoutPasscodeInputViewBottomContraints(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SetupConfirmEmailViewController.layoutPasscodeInputViewBottomContraints(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SetupConfirmEmailViewController.hidePINUIIfExpired), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)

        self.pollTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(SetupConfirmEmailViewController.pollAccountStatus), userInfo: nil, repeats: true)
        
        self.hidePINUIIfExpired()
    
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        
        self.pollTimer?.invalidate()
        self.pollTimer = nil
    }
    
    @objc func hidePINUIIfExpired() {
        if (self.timeOfInitialPresesntation != nil && abs(self.timeOfInitialPresesntation!.timeIntervalSinceNow) > 120.0) {
            // if they are coming back into the app and it's been too long for the code to be valid, show the other UI
            self.showVerifyViaButtonUI()
        }
    }
    
    @objc func pollAccountStatus() {
        RideReportAPIClient.shared.updateAccountStatus().apiResponse() { (response) in
            if (RideReportAPIClient.shared.accountVerificationStatus == .verified) {
                self.parentSetupViewController?.nextPage(sender: self)
            }
        }
    }
    
    private func showVerifyViaButtonUI() {
        self.passcodeInputView.isHidden = true
        helperTextLabel.markdownStringValue = "Check your email! You'll find a **button to tap** in the email we just sent."
        self.passcodeInputView.resignFirstResponder()
    }
    
    @objc func layoutPasscodeInputViewBottomContraints(_ notification: Notification) {
        let userInfo = notification.userInfo!
        
        let animationDuration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let keyboardEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let convertedKeyboardEndFrame = view.convert(keyboardEndFrame, from: view.window)
        let rawAnimationCurve = (notification.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).uint32Value << 16
        let animationCurve = UIViewAnimationOptions(rawValue: UInt(rawAnimationCurve))
        
        let margin : CGFloat = 30
        
        passcodeInputViewBottomLayoutConstraint.constant = view.bounds.maxY - convertedKeyboardEndFrame.minY + margin
        
        UIView.animate(withDuration: animationDuration, delay: 0.0, options: UIViewAnimationOptions.beginFromCurrentState.union(animationCurve), animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func passcodeInputViewDidFinish(_ passcodeInputView: BKPasscodeInputView!) {
        RideReportAPIClient.shared.verifyToken(passcodeInputView.passcode).apiResponse() { (response) in
            switch response.result {
            case .success:
                self.parentSetupViewController?.nextPage(sender: self)
            case .failure:
                if let httpResponse = response.response, httpResponse.statusCode == 404 {
                    passcodeInputView.errorMessage = "That's not it."
                    passcodeInputView.passcodeField.shake() {
                        UIView.transition(with: passcodeInputView, duration: 0.3, options: [UIViewAnimationOptions.overrideInheritedDuration, UIViewAnimationOptions.transitionCrossDissolve], animations: { () -> Void in
                            passcodeInputView.passcode = nil
                            }, completion: nil)
                    }
                } else {
                    passcodeInputView.passcode = nil
                }
            }
        }
    }
}
