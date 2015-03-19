//
//  GettingStartedTermsViewController.swift
//  Ride
//
//  Created by William Henderson on 1/19/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class GettingStartedTermsViewController: GettingStartedChildViewController, UITextViewDelegate {
    
    @IBOutlet weak var helperTextLabel : UILabel!
    @IBOutlet weak var termsTextView : UITextView!
    
    
    override func viewDidLoad() {
        self.termsTextView.selectable = true
        self.termsTextView.editable = false
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: "didTapLink:")
        self.termsTextView.addGestureRecognizer(tapRecognizer)
        
        helperTextLabel.markdownStringValue = "You don't need to do anything to use Ride. Hop on your bike and Ride will begin automatically."
    }
    
    func didTapLink(tapGesture: UIGestureRecognizer) {
        if tapGesture.state != UIGestureRecognizerState.Ended {
            return
        }
        
        let tapLocation = tapGesture.locationInView(self.termsTextView)
        let textPosition = self.termsTextView.closestPositionToPoint(tapLocation)
        let attributes = self.termsTextView.textStylingAtPosition(textPosition, inDirection: UITextStorageDirection.Forward)
        
        let underline = attributes[NSUnderlineStyleAttributeName] as NSNumber?
        if (underline?.integerValue == NSUnderlineStyle.StyleSingle.rawValue) {
            UIApplication.sharedApplication().openURL(NSURL(string: "http://ride.report/terms")!)

        }
    }
}