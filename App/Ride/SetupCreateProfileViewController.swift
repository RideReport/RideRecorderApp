//
//  SetupCreateProfileViewController.swift
//  Ride Report
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON
import FBSDKLoginKit

class SetupCreateProfileViewController: SetupChildViewController, UITextFieldDelegate, FBSDKLoginButtonDelegate {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var detailTextLabel : UILabel!
    @IBOutlet weak var emailTextField : UITextField!
    @IBOutlet weak var haveAccountButton: UIButton!
    @IBOutlet weak var facebookButton: FBSDKLoginButton!
    
    private var isCreatingProfileOutsideGettingStarted = false
    private var isInAlreadyHaveAccountState = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: "didTap:")
        self.view.addGestureRecognizer(tapRecognizer)
        self.facebookButton.readPermissions = ["public_profile", "email"]
        self.facebookButton.delegate = self
    }
    
    override func childViewControllerWillPresent(userInfo: [String: AnyObject]? = nil) {
        super.childViewControllerWillPresent(userInfo: userInfo)
        
        if let isCreatingProfileOutsideGettingStarted = userInfo?["isCreatingProfileOutsideGettingStarted"] as! Bool? where isCreatingProfileOutsideGettingStarted {
            self.isCreatingProfileOutsideGettingStarted = true
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Later", style: UIBarButtonItemStyle.Plain, target: self, action: "skip")
        } else {
            self.isCreatingProfileOutsideGettingStarted = false
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Skip", style: UIBarButtonItemStyle.Plain, target: self, action: "skip")
        }
        
        self.reloadUI()
    }
    
    func reloadUI() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Create", style: UIBarButtonItemStyle.Done, target: self, action: "create")
        
        if (isInAlreadyHaveAccountState) {
            self.navigationItem.rightBarButtonItem?.title = "Log In"
            self.helperTextLabel.markdownStringValue = "Log in to your account to **load your trip data** onto this iPhone."
            self.detailTextLabel.markdownStringValue = ""
            self.haveAccountButton.setTitle("Don't have an account?", forState: UIControlState.Normal)
        } else {
            self.navigationItem.rightBarButtonItem?.title = "Create"
            self.helperTextLabel.markdownStringValue = "Create an account so you can **recover your trip data** if your phone is lost."
            self.detailTextLabel.markdownStringValue = "Using Ride Report is anonymous. Creating a account is completely optional and you can do it later if you change your mind."
            self.haveAccountButton.setTitle("Already have an account?", forState: UIControlState.Normal)
        }
    }
    
    func skip() {
        self.parent?.done(userInfo: ["finishType": self.isCreatingProfileOutsideGettingStarted ? "CreateAccountSkippedAccount" : "InitialSetupSkippedAccount"])
    }
    
    func create() {
        self.facebookButton.enabled = false
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.emailTextField.enabled = false
        
        APIClient.sharedClient.sendVerificationTokenForEmail(self.emailTextField.text).after() { (response, jsonData, error) -> Void in
            self.facebookButton.enabled = true
            self.navigationItem.rightBarButtonItem?.enabled = true
            self.emailTextField.enabled = true
            
            if (error == nil) {
                self.verifyEmailWithJsonData(jsonData)
            } else {
                self.emailTextField.becomeFirstResponder()
            }
        }

    }
    
    func verifyEmailWithJsonData(jsonData: JSON) {
        if let shortcodeLength = jsonData["shortcode_length"].int {
            self.parent?.nextPage(self, userInfo: ["shortcodeLength": shortcodeLength, "isCreatingProfileOutsideGettingStarted" : self.isCreatingProfileOutsideGettingStarted])
        } else {
            self.parent?.nextPage(self, userInfo: ["isCreatingProfileOutsideGettingStarted" : self.isCreatingProfileOutsideGettingStarted])
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
    
    @IBAction func tappedHaveAccount(sender: AnyObject) {
        self.isInAlreadyHaveAccountState = !self.isInAlreadyHaveAccountState
        self.reloadUI()
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
        self.create()
        
        return true
    }
    
    func loginButton(loginButton: FBSDKLoginButton!, didCompleteWithResult result: FBSDKLoginManagerLoginResult!, error: NSError!) {
        if (result.isCancelled) {
            // don't do anything, i guess
        } else if let token = result.token?.tokenString {
            // submit token to zion mainframes.
            self.facebookButton.enabled = false
            self.navigationItem.rightBarButtonItem?.enabled = false
            self.emailTextField.enabled = false
            
            APIClient.sharedClient.verifyFacebook(token).after({ (response, jsonData, error) -> Void in
                if (error == nil) {
                    if let needsEmailVerification = jsonData["needs_email_verification"].bool, let email = jsonData["facebook"]["email"].string where needsEmailVerification {
                        APIClient.sharedClient.sendVerificationTokenForEmail(email).after() { (response, jsonData, error) -> Void in
                            
                            self.facebookButton.enabled = true
                            self.navigationItem.rightBarButtonItem?.enabled = true
                            self.emailTextField.enabled = true

                            if (error == nil) {
                                self.verifyEmailWithJsonData(jsonData)
                            } else {
                                let alert = UIAlertView(title:nil, message: "There was an error validating your email from Facebook. Please try signing up using your email address instead.", delegate: nil, cancelButtonTitle:"On it")
                                alert.show()
                                self.emailTextField.becomeFirstResponder()
                            }
                        }
                    } else {
                        self.parent?.done(userInfo: ["finishType": self.isCreatingProfileOutsideGettingStarted ? "CreatedAccountCreatedAccount" : "InitialSetupCreatedAccount"])
                    }
                } else {
                    self.facebookButton.enabled = true
                    self.navigationItem.rightBarButtonItem?.enabled = true
                    self.emailTextField.enabled = true
                }
            })
        }
    }
    
    func loginButtonDidLogOut(loginButton: FBSDKLoginButton!) {
        // do something
    }
}