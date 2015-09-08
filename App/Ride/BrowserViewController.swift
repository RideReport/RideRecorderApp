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
        
        if let url = NSURL(string: self.urlString!)
        {
            
//            if let safariViewController : SFSafariViewController = NSClassFromString("SFSafariViewController") {
//                let instance = safariViewController(URL: loadUrl)
//            } else {
                self.webView = UIWebView(frame: self.view.frame)
                webView.loadRequest(NSURLRequest(URL: url))
                self.view.addSubview(webView)
//            }
        }
    }
}