//
//  BrowserViewController.swift
//  Ride
//
//  Created by William Henderson on 9/8/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SafariServices

class BrowserViewController: UIViewController
{
    @IBInspectable var urlString: String?
    private var webView:UIWebView!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if let url = URL(string: self.urlString!)
        {
            self.webView = UIWebView(frame: self.view.frame)
            webView.loadRequest(URLRequest(url: url))
            self.view.addSubview(webView)
        }
    }
}
