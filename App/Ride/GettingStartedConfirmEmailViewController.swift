//
//  GettingStartedConfirmEmailViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class GettingStartedConfirmEmailViewController: GettingStartedChildViewController, BKPasscodeInputViewDelegate {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var passcodeInputView : BKPasscodeInputView!
    @IBOutlet weak var passcodeInputViewBottomLayoutConstraint: NSLayoutConstraint!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.passcodeInputView.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle
        self.passcodeInputView.keyboardType = UIKeyboardType.NumberPad
        self.passcodeInputView.keyboardAppearance = UIKeyboardAppearance.Dark
        self.passcodeInputView.maximumLength = 6
        self.passcodeInputView.delegate = self
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.Plain, target: self, action: "back")
    }
    
    func back() {
        self.parent?.previousPage(self)
    }
    
    override func childViewControllerWillPresent(userInfo: [String: AnyObject]? = nil) {
        super.childViewControllerWillPresent(userInfo: userInfo)
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
            self.passcodeInputView.hidden = true
            helperTextLabel.markdownStringValue = "Check your email! You'll find a **button to tap** in the email we just sent."
            self.passcodeInputView.resignFirstResponder()
        }
    }

    override func viewWillAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "layoutPasscodeInputViewBottomContraints:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "layoutPasscodeInputViewBottomContraints:", name: UIKeyboardWillHideNotification, object: nil)
        
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
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
        
        UIView.animateWithDuration(animationDuration, delay: 0.0, options: .BeginFromCurrentState | animationCurve, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func passcodeInputViewDidFinish(passcodeInputView: BKPasscodeInputView!) {
        APIClient.sharedClient.verifyToken(passcodeInputView.passcode).response { (request, response, data, error) in
            if (error == nil) {
                self.parent?.nextPage(self)
            } else {
                if (response?.statusCode == 404) {
                    passcodeInputView.errorMessage = "That's not it."
                    passcodeInputView.passcodeField.shake() {
                        UIView.transitionWithView(passcodeInputView, duration: 0.3, options: UIViewAnimationOptions.OverrideInheritedDuration|UIViewAnimationOptions.TransitionCrossDissolve, animations: { () -> Void in
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