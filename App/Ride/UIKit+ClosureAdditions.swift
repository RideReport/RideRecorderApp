//
//  UIControl+HBAdditions.swift
//  Ride Report
//
//  Created by William Henderson on 12/12/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation

class ClosureSleeve {
    let closure: () -> ()
    
    init(attachTo: AnyObject, closure: @escaping () -> ()) {
        self.closure = closure
        objc_setAssociatedObject(attachTo, "[\(arc4random())]", self, .OBJC_ASSOCIATION_RETAIN)
    }
    
    @objc func invoke() {
        closure()
    }
}

extension UIControl {
    func addAction(for controlEvents: UIControlEvents, action: @escaping () -> ()) {
        let sleeve = ClosureSleeve(attachTo: self, closure: action)
        addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: controlEvents)
    }
}

extension UIGestureRecognizer {
    convenience init(action: @escaping () -> ()) {
        self.init()
        
        let sleeve = ClosureSleeve(attachTo: self, closure: action)
        self.addTarget(sleeve, action: #selector(ClosureSleeve.invoke))
    }
}
