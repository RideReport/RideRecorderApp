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
    
    override func childViewControllerWillPresent(_ userInfo: [String: Any]? = nil) {
        super.childViewControllerWillPresent(userInfo)
        
        if let isCreatingProfileOutsideGettingStarted = userInfo?["isCreatingProfileOutsideGettingStarted"] as! Bool?, isCreatingProfileOutsideGettingStarted {
            self.isCreatingProfileOutsideGettingStarted = true
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Later", style: UIBarButtonItemStyle.plain, target: self, action: #selector(SetupCreateProfileViewController.skip))
        } else {
            self.isCreatingProfileOutsideGettingStarted = false
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Skip", style: UIBarButtonItemStyle.plain, target: self, action: #selector(SetupCreateProfileViewController.skip))
        }
    }
    
    func reloadUI() {
        if (isInAlreadyHaveAccountState) {
            self.helperTextLabel.markdownStringValue = "Log in to my Ride Report account"
            self.haveAccountButton.setTitle("I don't have an account", for: UIControlState())
        } else {
            if let _ = self.parentSetupViewController, (parentSetupViewController?.hasAddedWatchkitToSetup)! {
                // it's not the last step
                self.helperTextLabel.markdownStringValue = "Ok, now let's create your **free Ride Report account**."
            } else {
                self.helperTextLabel.markdownStringValue = "Ok, last step!\n Let's create your **free Ride Report account**."
            }
            self.haveAccountButton.setTitle("I already have an account", for: UIControlState())
        }
    }
    
    @objc func skip() {
        self.parentSetupViewController?.nextPage(sender: self, userInfo: nil, skipInterval: 1) // skip confirm
    }
    
    @objc func create() {
        self.facebookButton.isEnabled = false
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        self.emailTextField.isEnabled = false
        
        RideReportAPIClient.shared.sendVerificationTokenForEmail(self.emailTextField.text!).apiResponse() { (response) -> Void in
            self.facebookButton.isEnabled = true
            self.navigationItem.rightBarButtonItem?.isEnabled = true
            self.emailTextField.isEnabled = true
            
            switch response.result {
            case .success(let json):
                self.verifyEmailWithJson(json)
            case .failure:
                self.emailTextField.becomeFirstResponder()
                if let httpResponse = response.response, httpResponse.statusCode == 400 {
                    let alertController = UIAlertController(title: nil, message: "That doesn't look like a valid email address. Please double-check your typing and try again.", preferredStyle: UIAlertControllerStyle.actionSheet)
                    alertController.addAction(UIAlertAction(title: "On it", style: UIAlertActionStyle.cancel, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }

    }
    
    func verifyEmailWithJson(_ json: JSON) {
        if let shortcodeLength = json["shortcode_length"].int {
            self.parentSetupViewController?.nextPage(sender: self, userInfo: ["shortcodeLength": shortcodeLength, "isCreatingProfileOutsideGettingStarted" : self.isCreatingProfileOutsideGettingStarted])
        } else {
            self.parentSetupViewController?.nextPage(sender: self, userInfo: ["isCreatingProfileOutsideGettingStarted" : self.isCreatingProfileOutsideGettingStarted])
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.reloadUI()
        
        self.navigationController?.isNavigationBarHidden = false
        self.navigationItem.rightBarButtonItem = nil
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UITextFieldTextDidChange, object: nil, queue: nil) {[weak self] (notif) -> Void in
            guard let strongSelf = self else {
                return
            }

            if (strongSelf.textFieldHasValidEmail()) {
                strongSelf.navigationItem.rightBarButtonItem?.isEnabled = true
                strongSelf.emailTextField.returnKeyType = UIReturnKeyType.done
            } else {
                strongSelf.navigationItem.rightBarButtonItem?.isEnabled = false
                strongSelf.emailTextField.returnKeyType = UIReturnKeyType.done
            }
        }
    }
    
    private func textFieldHasValidEmail()->Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        
        return emailPredicate.evaluate(with: self.emailTextField.text)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func tappedHaveAccount(_ sender: AnyObject) {
        self.isInAlreadyHaveAccountState = !self.isInAlreadyHaveAccountState
        self.reloadUI()
    }
    
    @objc func didTap(_ tapGesture: UIGestureRecognizer) {
        if tapGesture.state != UIGestureRecognizerState.ended {
            return
        }
        
        let locInView = tapGesture.location(in: tapGesture.view)
        let tappedView = tapGesture.view?.hitTest(locInView, with: nil)
        if (tappedView != nil && !tappedView!.isDescendant(of: self.emailTextField)) {
            self.emailTextField.resignFirstResponder()
        }
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if (isInAlreadyHaveAccountState) {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Log in", style: UIBarButtonItemStyle.done, target: self, action: #selector(SetupCreateProfileViewController.create))
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Create", style: UIBarButtonItemStyle.done, target: self, action: #selector(SetupCreateProfileViewController.create))
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.navigationItem.rightBarButtonItem = nil
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (!self.textFieldHasValidEmail()) {
            return false
        }
        
        self.emailTextField.resignFirstResponder()
        self.create()
        
        return true
    }
    
    
    public func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
        if (result.isCancelled) {
            // don't do anything, i guess
        } else if let token = result.token?.tokenString {
            // submit token to zion mainframes.
            self.facebookButton.isEnabled = false
            self.navigationItem.rightBarButtonItem?.isEnabled = false
            self.emailTextField.isEnabled = false

            
            RideReportAPIClient.shared.verifyFacebook(token).apiResponse() { (response) -> Void in
                switch response.result {
                case .success(let json):
                    if let needsEmailVerification = json["needs_email_verification"].bool, let email = json["facebook"]["email"].string, needsEmailVerification {
                        RideReportAPIClient.shared.sendVerificationTokenForEmail(email).apiResponse() { (response) -> Void in
                            
                            self.facebookButton.isEnabled = true
                            self.navigationItem.rightBarButtonItem?.isEnabled = true
                            self.emailTextField.isEnabled = true
                            
                            switch response.result {
                            case .success(let json):
                                self.verifyEmailWithJson(json)
                            case .failure:
                                let alertController = UIAlertController(title: nil, message: "There was an error validating your email from Facebook. Please try signing up using your email address instead.", preferredStyle: UIAlertControllerStyle.alert)
                                alertController.addAction(UIAlertAction(title: "On it", style: UIAlertActionStyle.cancel, handler: nil))
                                self.present(alertController, animated: true, completion: nil)
                      
                                self.emailTextField.becomeFirstResponder()
                            }
                         }
                    } else {
                        let finishType = self.isCreatingProfileOutsideGettingStarted ? "CreatedAccountCreatedAccount" : "InitialSetupCreatedAccount"
                        self.parentSetupViewController?.done(userInfo: ["finishType": finishType])
                    }
                case .failure:
                    self.facebookButton.isEnabled = true
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.emailTextField.isEnabled = true
                    
                    if let httpResponse = response.response, httpResponse.statusCode == 400 {
                        let alertController = UIAlertController(title: nil, message: "There was an error communicating with Facebook. Please try again later or use sign up using your email address instead.", preferredStyle: UIAlertControllerStyle.alert)
                        alertController.addAction(UIAlertAction(title: "On it", style: UIAlertActionStyle.cancel, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        // do something
    }
}
