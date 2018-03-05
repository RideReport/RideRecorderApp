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
import SafariServices

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
    public var moreInfoButton: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let stackview = UIStackView()
        stackview.translatesAutoresizingMaskIntoConstraints = false
        stackview.axis = .vertical
        stackview.alignment = .fill
        stackview.distribution = .fill
        stackview.spacing = 2.0
        addSubview(stackview)
        
        titleView = UILabel()
        titleView.font = UIFont.boldSystemFont(ofSize: 16)
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.textAlignment = .center
        titleView.numberOfLines = 0
        titleView.lineBreakMode = .byTruncatingTail
        titleView.setContentCompressionResistancePriority(UILayoutPriority.required, for: .vertical)
        
        moreInfoButton = UIButton()
        moreInfoButton.translatesAutoresizingMaskIntoConstraints = false
        moreInfoButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        moreInfoButton.setTitleColor(ColorPallete.shared.primaryDark, for: UIControlState())

        stackview.addArrangedSubview(titleView)
        stackview.addArrangedSubview(moreInfoButton)
        
        let xConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-16-[stackview]-16-|", options: [], metrics: nil, views: ["stackview": stackview])
        NSLayoutConstraint.activate(xConstraints)
        
        let yConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[stackview]-16-|", options: [.alignAllCenterX], metrics: nil, views: ["stackview": stackview])
        NSLayoutConstraint.activate(yConstraints)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ConnectedAppConfirmViewController : FormViewController, SFSafariViewControllerDelegate {
    var connectingApp: ConnectedApp!
    
    @IBOutlet weak var connectionActivityContainerView: UIView!
    @IBOutlet weak var connectionActivityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var connectionActivityIndicatorViewText: UILabel!
    @IBOutlet weak var connectionActivityCompleteView: UIView!
    
    private var safariViewController: UIViewController? = nil
    private var safariViewControllerActivityIndicator: UIActivityIndicatorView? = nil
    
    private var hasCanceled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.connectionActivityContainerView.isHidden = true
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
                        if let _ = self.connectingApp.moreInfoUrl {
                            view.moreInfoButton.setTitle(self.connectingApp.moreInfoText ?? "Learn More", for: UIControlState())
                            view.moreInfoButton.addTarget(self, action: #selector(ConnectedAppConfirmViewController.moreInfo), for: .touchUpInside)
                        } else {
                            view.moreInfoButton.isHidden = true
                        }
                    }
                    $0.header = header
                }
            }

            if self.connectingApp.scopes.count > 0 {
                var scopesHeader = String(format: "Share ride data with %@", self.connectingApp.companyName ?? self.connectingApp.name ?? "this App")
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
                            
                            if let placeholderText = field.placeholderText {
                                $0.placeholder = placeholderText + (field.isRequired ? " (required)" : "")
                            }
                        }.cellUpdate { cell, row in
                            field.value = row.value
                            
                            if let value = row.value, !value.isEmpty && !row.isValid {
                                cell.titleLabel?.textColor = ColorPallete.shared.badRed
                            }
                        }
                    } else {
                        form.last! <<< TextRow(field.machineName) {
                            $0.title = field.descriptionText
                            $0.tag = field.machineName
                            tags.append(field.machineName)
                            $0.value = field.defaultText
                            
                            if let placeholderText = field.placeholderText {
                                $0.placeholder = placeholderText + (field.isRequired ? " (required)" : "")
                            }
                            if field.isRequired {
                                $0.add(rule: RuleRequired())
                                $0.validationOptions = .validatesOnChange
                            }
                        }.cellUpdate { cell, row in
                            field.value = row.value
                            
                            if let value = row.value, !value.isEmpty && !row.isValid {
                                cell.titleLabel?.textColor = ColorPallete.shared.badRed
                            }
                        }
                    }
                }
            }

            let connectActionString = self.connectingApp.connectButtonTitleText ?? "Connect"
            form +++ Section(footer: String(format: "By tapping '%@', you are allowing Ride Report to share the above data with %@.", connectActionString, self.connectingApp.companyName ?? self.connectingApp.name ?? "this App"))
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
    
    @objc func moreInfo() {
        if let urlString = self.connectingApp.moreInfoUrl, let url = URL(string: urlString) {
            if #available(iOS 9.0, *) {
                let sfvc = SFSafariViewController(url: url)
                self.safariViewController = sfvc
                sfvc.delegate = self
                self.navigationController?.present(sfvc, animated: true, completion: nil)
                if let coordinator = transitionCoordinator {
                    coordinator.animate(alongsideTransition: nil, completion: { (context) in
                        let targetSubview = sfvc.view
                        let loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
                        loadingIndicator.color = ColorPallete.shared.darkGrey
                        self.safariViewControllerActivityIndicator = loadingIndicator
                        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
                        targetSubview?.addSubview(loadingIndicator)
                        NSLayoutConstraint(item: loadingIndicator, attribute: .centerY, relatedBy: NSLayoutRelation.equal, toItem: targetSubview, attribute: .centerY, multiplier: 1, constant: 0).isActive = true
                        NSLayoutConstraint(item: loadingIndicator, attribute: .centerX, relatedBy: NSLayoutRelation.equal, toItem: targetSubview, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
                        loadingIndicator.startAnimating()
                    })
                }
            } else {
                UIApplication.shared.openURL(url)
            }
        }
    }
    
    func connect() {
        if let superview = self.connectionActivityContainerView.superview {
            superview.bringSubview(toFront: self.connectionActivityContainerView)
        }
        self.connectionActivityContainerView.isHidden = false
        
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
                    strongSelf.connectionActivityIndicatorView.isHidden = true
                    strongSelf.connectionActivityCompleteView.popIn()
                    strongSelf.connectionActivityIndicatorViewText.text = "Connected!"
                    strongSelf.connectionActivityIndicatorViewText.delay(1.2, completionHandler: { [weak self] in
                        guard let reallyStrongSelf = self else {
                            return
                        }
                        
                        reallyStrongSelf.dismiss(animated: true, completion: nil)
                    })
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
                
                strongSelf.connectionActivityContainerView.isHidden = true
            }
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        self.hasCanceled = true
        RideReportAPIClient.shared.disconnectApplication(self.connectingApp)
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func showPageLoadError() {
        let alertController = UIAlertController(title:nil, message: String(format: "Ride Report cannot connect to %@. Please try again later.", self.connectingApp?.name ?? "App"), preferredStyle: UIAlertControllerStyle.actionSheet)
        alertController.addAction(UIAlertAction(title: "Shucks", style: UIAlertActionStyle.destructive, handler: { (_) in
            _ = self.navigationController?.popViewController(animated: true)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    @available(iOS 9.0, *)
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        if let loadingIndicator = self.safariViewControllerActivityIndicator {
            loadingIndicator.removeFromSuperview()
            self.safariViewControllerActivityIndicator = nil
        }
        
        if !didLoadSuccessfully {
            self.perform(#selector(ConnectedAppConfirmViewController.showPageLoadError), with: nil, afterDelay: 1.0)
        }
    }
    
}
