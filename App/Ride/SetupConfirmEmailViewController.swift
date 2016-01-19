//
//  SetupConfirmEmailViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class SetupConfirmEmailViewController: SetupChildViewController, BKPasscodeInputViewDelegate {
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var passcodeInputView : BKPasscodeInputView!
    @IBOutlet weak var passcodeInputViewBottomLayoutConstraint: NSLayoutConstraint!
    
    private var pollTimer : NSTimer? = nil
    private var timeOfInitialPresesntation : NSDate? = nil
    private var isCreatingProfileOutsideGettingStarted = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.passcodeInputView.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle
        self.passcodeInputView.keyboardType = UIKeyboardType.NumberPad
        self.passcodeInputView.keyboardAppearance = UIKeyboardAppearance.Light
        self.passcodeInputView.delegate = self
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.Plain, target: self, action: "back")
    }
    
    func back() {
        self.parent?.previousPage(self)
    }
    
    override func childViewControllerWillPresent(userInfo: [String: AnyObject]? = nil) {
        super.childViewControllerWillPresent(userInfo)
        
        let _ = self.view.subviews // hack for a gross crash.
        
        self.timeOfInitialPresesntation = NSDate()
        
        if let isCreatingProfileOutsideGettingStarted = userInfo?["isCreatingProfileOutsideGettingStarted"] as! Bool? where isCreatingProfileOutsideGettingStarted {
            self.isCreatingProfileOutsideGettingStarted = true
        } else {
            self.isCreatingProfileOutsideGettingStarted = false
        }
        
        if let shortCode = userInfo?["shortcodeLength"] as! Int? {
            self.passcodeInputView.maximumLength = UInt(shortCode)
            self.passcodeInputView.hidden = false
            helperTextLabel.markdownStringValue = "**Enter the secret code** in the email we just sent."
        
            // make sure the keyboard does not animate in initially.
            UIView.setAnimationsEnabled(false)
            NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardDidShowNotification, object: nil, queue: nil) { (notif) -> Void in
                NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardDidShowNotification, object: nil)
                UIView.setAnimationsEnabled(true)
            }
            self.passcodeInputView.becomeFirstResponder()
        } else {
            self.showVerifyViaButtonUI()
        }
    }

    override func viewWillAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "layoutPasscodeInputViewBottomContraints:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "layoutPasscodeInputViewBottomContraints:", name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "hidePINUIIfExpired", name: UIApplicationDidBecomeActiveNotification, object: nil)

        self.pollTimer = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: Selector("pollAccountStatus"), userInfo: nil, repeats: true)
        
        self.hidePINUIIfExpired()
    
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        self.pollTimer?.invalidate()
        self.pollTimer = nil
    }
    
    func hidePINUIIfExpired() {
        if (self.timeOfInitialPresesntation != nil && abs(self.timeOfInitialPresesntation!.timeIntervalSinceNow) > 120.0) {
            // if they are coming back into the app and it's been too long for the code to be valid, show the other UI
            self.showVerifyViaButtonUI()
        }
    }
    
    func pollAccountStatus() {
        APIClient.sharedClient.updateAccountStatus().apiResponse() { (response) in
            if (APIClient.sharedClient.accountVerificationStatus == .Verified) {
                self.parent?.done(["finishType": self.isCreatingProfileOutsideGettingStarted ? "CreatedAccountCreatedAccount" : "InitialSetupCreatedAccount"])
            }
        }
    }
    
    private func showVerifyViaButtonUI() {
        self.passcodeInputView.hidden = true
        helperTextLabel.markdownStringValue = "Check your email! You'll find a **button to tap** in the email we just sent."
        self.passcodeInputView.resignFirstResponder()
    }
    
    func layoutPasscodeInputViewBottomContraints(notification: NSNotification) {
        let userInfo = notification.userInfo!
        
        let animationDuration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let keyboardEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        let convertedKeyboardEndFrame = view.convertRect(keyboardEndFrame, fromView: view.window)
        let rawAnimationCurve = (notification.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).unsignedIntValue << 16
        let animationCurve = UIViewAnimationOptions(rawValue: UInt(rawAnimationCurve))
        
        let margin : CGFloat = 30
        
        passcodeInputViewBottomLayoutConstraint.constant = CGRectGetMaxY(view.bounds) - CGRectGetMinY(convertedKeyboardEndFrame) + margin
        
        UIView.animateWithDuration(animationDuration, delay: 0.0, options: UIViewAnimationOptions.BeginFromCurrentState.union(animationCurve), animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func passcodeInputViewDidFinish(passcodeInputView: BKPasscodeInputView!) {
        APIClient.sharedClient.verifyToken(passcodeInputView.passcode).apiResponse() { (response) in
            switch response.result {
            case .Success:
                self.parent?.done(["finishType": self.isCreatingProfileOutsideGettingStarted ? "CreatedAccountCreatedAccount" : "InitialSetupCreatedAccount"])
            case .Failure:
                if let httpResponse = response.response where httpResponse.statusCode == 404 {
                    passcodeInputView.errorMessage = "That's not it."
                    passcodeInputView.passcodeField.shake() {
                        UIView.transitionWithView(passcodeInputView, duration: 0.3, options: [UIViewAnimationOptions.OverrideInheritedDuration, UIViewAnimationOptions.TransitionCrossDissolve], animations: { () -> Void in
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