//
//  ConnectedAppPINViewController.swift
//  Ride
//
//  Created by William Henderson on 4/12/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class ConnectedAppPINViewController : UIViewController, BKPasscodeInputViewDelegate {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    @IBOutlet weak var passcodeInputView : BKPasscodeInputView!
    @IBOutlet weak var passcodeInputViewBottomLayoutConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.passcodeInputView.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle
        self.passcodeInputView.keyboardType = UIKeyboardType.NumberPad
        self.passcodeInputView.keyboardAppearance = UIKeyboardAppearance.Light
        self.passcodeInputView.delegate = self
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.passcodeInputView.becomeFirstResponder()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ConnectedAppPINViewController.layoutPasscodeInputViewBottomContraints(_:)), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ConnectedAppPINViewController.layoutPasscodeInputViewBottomContraints(_:)), name: UIKeyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    @IBAction func cancel(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func done(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func layoutPasscodeInputViewBottomContraints(notification: NSNotification) {
        let userInfo = notification.userInfo!
        
        let animationDuration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let keyboardEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        let convertedKeyboardEndFrame = view.convertRect(keyboardEndFrame, fromView: view.window)
        let rawAnimationCurve = (notification.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).unsignedIntValue << 16
        let animationCurve = UIViewAnimationOptions(rawValue: UInt(rawAnimationCurve))
        
        let margin : CGFloat = 130
        
        passcodeInputViewBottomLayoutConstraint.constant = CGRectGetMaxY(view.bounds) - CGRectGetMinY(convertedKeyboardEndFrame) + margin
        
        UIView.animateWithDuration(animationDuration, delay: 0.0, options: UIViewAnimationOptions.BeginFromCurrentState.union(animationCurve), animations: {
            self.view.layoutIfNeeded()
            }, completion: nil)
    }
    
    func passcodeInputViewDidFinish(passcodeInputView: BKPasscodeInputView!) {
        self.performSegueWithIdentifier("showConnectedAppConfirm", sender: self)
        
//        APIClient.sharedClient.verifyToken(passcodeInputView.passcode).apiResponse() { (response) in
//            switch response.result {
//            case .Success:
//                self.parent?.done(["finishType": self.isCreatingProfileOutsideGettingStarted ? "CreatedAccountCreatedAccount" : "InitialSetupCreatedAccount"])
//            case .Failure:
//                if let httpResponse = response.response where httpResponse.statusCode == 404 {
//                    passcodeInputView.errorMessage = "That's not it."
//                    passcodeInputView.passcodeField.shake() {
//                        UIView.transitionWithView(passcodeInputView, duration: 0.3, options: [UIViewAnimationOptions.OverrideInheritedDuration, UIViewAnimationOptions.TransitionCrossDissolve], animations: { () -> Void in
//                            passcodeInputView.passcode = nil
//                            }, completion: nil)
//                    }
//                } else {
//                    passcodeInputView.passcode = nil
//                }
//            }
//        }
    }
}