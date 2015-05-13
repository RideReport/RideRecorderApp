//
//  PopSegue.swift
//  Ride
//
//  Created by William Henderson on 5/12/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import UIKit

class PopSegue : UIStoryboardSegue {
    override func perform() {
        let transition = CATransition()
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        
        let source = self.sourceViewController as! UIViewController
        let dest = self.destinationViewController as! UIViewController
        
        dest.view.layer.addAnimation(transition, forKey: kCATransition)
        source.navigationController?.pushViewController(dest, animated: false)
    }
}