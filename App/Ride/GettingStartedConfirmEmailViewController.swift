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
    
    
    override func viewDidLoad() {
        helperTextLabel.markdownStringValue = "We just sent you an email! Go **tap the button** inside it "
        self.passcodeInputView.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle
        self.passcodeInputView.keyboardType = UIKeyboardType.NumberPad
        self.passcodeInputView.keyboardAppearance = UIKeyboardAppearance.Dark
        self.passcodeInputView.delegate = self
        
        self.passcodeInputView.title = "Or enter the PIN from the subject line."
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.passcodeInputView.becomeFirstResponder()
    }
    
    func passcodeInputViewDidFinish(aInputView: BKPasscodeInputView!) {
        //
    }
}