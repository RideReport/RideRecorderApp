//
//  ConnectedAppConfirmViewController.swift
//  Ride
//
//  Created by William Henderson on 4/25/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Eureka
import SwiftMessages

class ConnectedAppImageView: UIView {
    public var imageView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = CGRect(x: 0, y: 0, width: 320, height: 140)
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        
        let xConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-[imageView]-|", options: [], metrics: nil, views: ["imageView": imageView])
        NSLayoutConstraint.activate(xConstraints)
        
        let yConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-14-[imageView(140)]-0-|", options: [.alignAllCenterX], metrics: nil, views: ["imageView": imageView])
        NSLayoutConstraint.activate(yConstraints)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ConnectedAppTitleView: UIView {
    public var titleView: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleView = UILabel()
        titleView.font = UIFont.boldSystemFont(ofSize: 16)
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.numberOfLines = 0
        titleView.lineBreakMode = .byTruncatingTail
        titleView.setContentCompressionResistancePriority(UILayoutPriority.required, for: .vertical)

        addSubview(titleView)
        
        let xConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-16-[titleView]-16-|", options: [], metrics: nil, views: ["titleView": titleView])
        NSLayoutConstraint.activate(xConstraints)
        
        let yConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[titleView]-|", options: [.alignAllCenterX], metrics: nil, views: ["titleView": titleView])
        NSLayoutConstraint.activate(yConstraints)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ConnectedAppConfirmViewController : FormViewController {
    var connectingApp: ConnectedApp!
    @IBOutlet weak var connectionActivityIndicatorView: UIView!
    @IBOutlet weak var connectionActivityIndicatorViewText: UILabel!
    
    private var hasCanceled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.connectionActivityIndicatorView.isHidden = true
        tableView?.estimatedSectionHeaderHeight = 40
        
        if self.connectingApp != nil {
            for s in self.connectingApp.scopes {
                if let scope = s as? ConnectedAppScope {
                    scope.isGranted = true
                }
            }
            
            self.title = self.connectingApp.name ?? "App"
            
            form +++ Section() {
                var header = HeaderFooterView<ConnectedAppImageView>(.class)
                header.onSetupView = { (view, section) -> () in
                    if let urlString = self.connectingApp.baseImageUrl, let url = URL(string: urlString) {
                        view.imageView.kf.setImage(with: url)
                    } else {
                        view.imageView.image = UIImage(named: "AppIcon")
                    }
                }
                $0.header = header
            }
            if let descriptionText = self.connectingApp.descriptionText {
                form +++ Section() {
                    var header = HeaderFooterView<ConnectedAppTitleView>(.class)
                    header.height = { UITableViewAutomaticDimension }
                    header.onSetupView = { (view, section) -> () in
                        view.titleView.text = descriptionText
                    }
                    $0.header = header
                }
            }

            if self.connectingApp.scopes.count > 0 {
                var scopesHeader = String(format: "Share ride data with %@", self.connectingApp.companyName ?? self.connectingApp.name ?? "App")
                if let scopesHeaderText = self.connectingApp.scopesHeaderText {
                    scopesHeader = scopesHeaderText
                }
                
                form +++ Section(scopesHeader) {
                    $0.header?.height = { 36 }
                }
                
                for scope in self.connectingApp.scopes {
                    if let scope = scope as? ConnectedAppScope {
                        form.last! <<< SwitchRow() {
                            $0.title = scope.descriptionText ?? ""
                            $0.value = scope.isGranted
                            $0.cell.switchControl.isEnabled = !scope.isRequired
                        }
                    }
                }
            }
            
            var tags: [String] = []
            
            
            
            if self.connectingApp.fields.count > 0 {
                var fieldsHeader = String(format: "Share the following with %@", self.connectingApp.companyName ?? self.connectingApp.name ?? "this App")
                if let fieldHeaderText = self.connectingApp.fieldsHeaderText {
                    fieldsHeader = fieldHeaderText
                }
                form +++ Section(fieldsHeader) {
                    $0.header?.height = { 36 }
                }
                
                for field in self.connectingApp.fields {
                    guard let field = field as? ConnectedAppField else {
                        continue
                    }
                    
                    if field.type == "email" {
                        form.last! <<< EmailRow(field.machineName) {
                            $0.title = field.descriptionText
                            $0.tag = field.machineName
                            tags.append(field.machineName)
                            $0.value = field.defaultText

                            var ruleSet = RuleSet<String>()
                            ruleSet.add(rule: RuleEmail())
                            if field.isRequired {
                                ruleSet.add(rule: RuleRequired())
                            }
                            
                            $0.add(ruleSet: ruleSet)
                            $0.validationOptions = .validatesOnChangeAfterBlurred
                            
                            $0.placeholder = field.placeholderText
                        }.cellUpdate { cell, row in
                            field.value = row.value
                            
                            if !row.isValid {
                                cell.titleLabel?.textColor = .red
                            }
                        }
                    } else {
                        form.last! <<< TextRow(field.machineName) {
                            $0.title = field.descriptionText
                            $0.tag = field.machineName
                            tags.append(field.machineName)
                            $0.value = field.defaultText
                            
                            $0.placeholder = field.placeholderText
                            if field.isRequired {
                                $0.add(rule: RuleRequired())
                                $0.validationOptions = .validatesOnChange
                            }
                        }.cellUpdate { cell, row in
                            field.value = row.value
                            
                            if !row.isValid {
                                cell.titleLabel?.textColor = .red
                            }
                        }
                    }
                }
            }

            let connectActionString = self.connectingApp.connectButtonTitleText ?? "Connect"
            form +++ Section(footer: String(format: "By tapping '%@', you are allowing Ride Report to share the above data with %@. You can revoke this access anytime.", connectActionString, self.connectingApp.companyName ?? self.connectingApp.name ?? "this App"))
            <<< ButtonRow(connectActionString) {
                $0.title = connectActionString
                $0.cell.tintColor = ColorPallete.shared.primaryDark
                $0.disabled = Condition.function(tags) { form in
                    return !form.validate().isEmpty
                }
            }.onCellSelection { (cell, row) in
                if let form = row.section?.form, form.validate().isEmpty {
                    self.connect()
                }
            }
            
            self.connectionActivityIndicatorViewText.text = String(format: "Connecting to %@…", self.connectingApp.name ?? "App")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }
    
    func connect() {
        if let superview = self.connectionActivityIndicatorView.superview {
            superview.bringSubview(toFront: self.connectionActivityIndicatorView)
        }
        self.connectionActivityIndicatorView.isHidden = false
        
        self.postConnectApplication()
    }
    
    @objc func postConnectApplication() {
        guard !self.hasCanceled else {
            return
        }
        
        RideReportAPIClient.shared.connectApplication(self.connectingApp).apiResponse {[weak self] (response) in
            guard let strongSelf = self else {
                return
            }
            
            switch response.result {
            case .success(_):
                if let httpsResponse = response.response, httpsResponse.statusCode == 200 {
                    strongSelf.dismiss(animated: true, completion: nil)
                } else {
                    // otherwise, keep polling
                    strongSelf.perform(#selector(ConnectedAppConfirmViewController.postConnectApplication), with: nil, afterDelay: 2.0)
                }
            case .failure(_):
                let alertController = UIAlertController(title:nil, message: String(format: "Your Ride Report account could not be connected to %@. Please try again later.", strongSelf.connectingApp.name ?? "App"), preferredStyle: UIAlertControllerStyle.actionSheet)
                alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.destructive, handler: { (_) in
                    strongSelf.dismiss(animated: true, completion: nil)
                }))
                strongSelf.present(alertController, animated: true, completion: nil)
                
                strongSelf.connectionActivityIndicatorView.isHidden = true
            }
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.hasCanceled = true
        RideReportAPIClient.shared.disconnectApplication(self.connectingApp)
        self.dismiss(animated: true, completion: nil)
    }
    
}
