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
    @IBOutlet weak var emailTextField : UITextField!
    @IBOutlet weak var haveAccountButton: UIButton!
    @IBOutlet weak var facebookButton: FBSDKLoginButton!
    
    private var isCreatingProfileOutsideGettingStarted = false
    private var isInAlreadyHaveAccountState = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(SetupCreateProfileViewController.didTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
        self.facebookButton.readPermissions = ["public_profile", "email"]
        self.facebookButton.delegate = self
    }
    
    override func childViewControllerWillPresent(userInfo: [String: AnyObject]? = nil) {
        super.childViewControllerWillPresent(userInfo)
        
        if let isCreatingProfileOutsideGettingStarted = userInfo?["isCreatingProfileOutsideGettingStarted"] as! Bool? where isCreatingProfileOutsideGettingStarted {
            self.isCreatingProfileOutsideGettingStarted = true
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Later", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(SetupCreateProfileViewController.skip))
        } else {
            self.isCreatingProfileOutsideGettingStarted = false
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Skip", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(SetupCreateProfileViewController.skip))
        }
    }
    
    func reloadUI() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Create", style: UIBarButtonItemStyle.Done, target: self, action: #selector(SetupCreateProfileViewController.create))
        
        if (isInAlreadyHaveAccountState) {
            self.navigationItem.rightBarButtonItem?.title = "Log In"
            self.helperTextLabel.markdownStringValue = "Log in to your account to **load your ride data** onto this iPhone."
            self.haveAccountButton.setTitle("Don't have an account?", forState: UIControlState.Normal)
        } else {
            self.navigationItem.rightBarButtonItem?.title = "Create"
            self.helperTextLabel.markdownStringValue = "Create a free account to **keep your rides backed up** in case your phone is lost or stolen."
            self.haveAccountButton.setTitle("Already have an account?", forState: UIControlState.Normal)
        }
    }
    
    func skip() {
        self.parent?.done(["finishType": self.isCreatingProfileOutsideGettingStarted ? "CreateAccountSkippedAccount" : "InitialSetupSkippedAccount"])
    }
    
    func create() {
        self.facebookButton.enabled = false
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.emailTextField.enabled = false
        
        APIClient.sharedClient.sendVerificationTokenForEmail(self.emailTextField.text!).apiResponse() { (response) -> Void in
            self.facebookButton.enabled = true
            self.navigationItem.rightBarButtonItem?.enabled = true
            self.emailTextField.enabled = true
            
            switch response.result {
            case .Success(let json):
                self.verifyEmailWithJson(json)
            case .Failure:
                self.emailTextField.becomeFirstResponder()
            }
        }

    }
    
    func verifyEmailWithJson(json: JSON) {
        if let shortcodeLength = json["shortcode_length"].int {
            self.parent?.nextPage(self, userInfo: ["shortcodeLength": shortcodeLength, "isCreatingProfileOutsideGettingStarted" : self.isCreatingProfileOutsideGettingStarted])
        } else {
            self.parent?.nextPage(self, userInfo: ["isCreatingProfileOutsideGettingStarted" : self.isCreatingProfileOutsideGettingStarted])
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.reloadUI()
        
        self.navigationController?.navigationBarHidden = false
        self.navigationItem.rightBarButtonItem?.enabled = false
        
        NSNotificationCenter.defaultCenter().addObserverForName(UITextFieldTextDidChangeNotification, object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }

            let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
            
            if (emailPredicate.evaluateWithObject(strongSelf.emailTextField.text)) {
                strongSelf.navigationItem.rightBarButtonItem?.enabled = true
                strongSelf.emailTextField.returnKeyType = UIReturnKeyType.Done
            } else {
                strongSelf.navigationItem.rightBarButtonItem?.enabled = false
                strongSelf.emailTextField.returnKeyType = UIReturnKeyType.Done
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

            
            APIClient.sharedClient.verifyFacebook(token).apiResponse() { (response) -> Void in
                switch response.result {
                case .Success(let json):
                    if let needsEmailVerification = json["needs_email_verification"].bool, let email = json["facebook"]["email"].string where needsEmailVerification {
                        APIClient.sharedClient.sendVerificationTokenForEmail(email).apiResponse() { (response) -> Void in
                            
                            self.facebookButton.enabled = true
                            self.navigationItem.rightBarButtonItem?.enabled = true
                            self.emailTextField.enabled = true
                            
                            switch response.result {
                            case .Success(let json):
                                self.verifyEmailWithJson(json)
                            case .Failure:
                                let alert = UIAlertView(title:nil, message: "There was an error validating your email from Facebook. Please try signing up using your email address instead.", delegate: nil, cancelButtonTitle:"On it")
                                alert.show()
                                self.emailTextField.becomeFirstResponder()
                            }
                         }
                    } else {
                        self.parent?.done(["finishType": self.isCreatingProfileOutsideGettingStarted ? "CreatedAccountCreatedAccount" : "InitialSetupCreatedAccount"])
                    }
                case .Failure:
                    self.facebookButton.enabled = true
                    self.navigationItem.rightBarButtonItem?.enabled = true
                    self.emailTextField.enabled = true
                }
            }
        }
    }
    
    func loginButtonDidLogOut(loginButton: FBSDKLoginButton!) {
        // do something
    }
}