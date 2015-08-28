//
//  GettingStartedCreateProfileViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

class GettingStartedCreateProfileViewController: GettingStartedChildViewController, UITextFieldDelegate {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var emailTextField : UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        helperTextLabel.markdownStringValue = "Create account so you can **recover your trip data** if your phone is lost."
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Create", style: UIBarButtonItemStyle.Done, target: self, action: "create")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Skip", style: UIBarButtonItemStyle.Plain, target: self, action: "skip")
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: "didTap:")
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    func skip() {
        self.parent?.done()
    }
    
    func create() {
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.emailTextField.enabled = false
        
        APIClient.sharedClient.sendVerificationTokenForEmail(self.emailTextField.text).responseJSON(options: nil) { (request, response, jsonData, error) -> Void in
            self.navigationItem.rightBarButtonItem?.enabled = true
            self.emailTextField.enabled = true
            
            if (error == nil) {
                let data = JSON(jsonData!)
                if let shortcodeLength = data["shortcode_length"].int {
                    self.parent?.nextPage(self, userInfo: ["shortcodeLength": shortcodeLength])
                } else {
                    self.parent?.nextPage(self)
                }
            } else {
                self.emailTextField.becomeFirstResponder()
            }
        }

    }
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBarHidden = false
        self.navigationItem.rightBarButtonItem?.enabled = false
        
        NSNotificationCenter.defaultCenter().addObserverForName(UITextFieldTextDidChangeNotification, object: nil, queue: nil) { (notif) -> Void in
            let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
            
            if (emailPredicate.evaluateWithObject(self.emailTextField.text)) {
                self.navigationItem.rightBarButtonItem?.enabled = true
                self.emailTextField.returnKeyType = UIReturnKeyType.Done
            } else {
                self.navigationItem.rightBarButtonItem?.enabled = false
                self.emailTextField.returnKeyType = UIReturnKeyType.Done
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func didTap(tapGesture: UIGestureRecognizer) {
        if tapGesture.state != UIGestureRecognizerState.Ended {
            return
        }
        
        let locInView = tapGesture.locationInView(tapGesture.view)
        let tappedView = tapGesture.view?.hitTest(locInView, withEvent: nil)
        if (tappedView != nil && !tappedView!.isDescendantOfView(self.emailTextField)) {
            self.emailTextField.resignFirstResponder()
        }
        
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.emailTextField.resignFirstResponder()
        
        return true
    }
}