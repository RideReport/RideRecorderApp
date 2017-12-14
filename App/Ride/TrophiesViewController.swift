//
//  TrophiesViewController.swift
//  Ride
//
//  Created by William Henderson on 12/11/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

class TrophiesViewController: UITableViewController {
    public var trophyCategories: [TrophyCategory] = []
    private var reachabilityManager: NetworkReachabilityManager?
    private var trophiesPerRow: Int!
    private var trophySpacing: CGFloat = 18.0
    
    override func viewDidLoad() {
        reachabilityManager = NetworkReachabilityManager()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
            // avoid a bug that could have this called twice on app launch
            NotificationCenter.default.addObserver(self, selector: #selector(TrophiesViewController.updateData), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        })
        
        self.trophiesPerRow =  Int(floor((self.view.frame.width) / (TrophyProgressButton.defaultBadgeDimension + trophySpacing)))
        
        self.reloadData()
        updateData()
    }
    
    @objc fileprivate func updateData() {
        if let manager = reachabilityManager  {
            if  manager.isReachable {
                RideReportAPIClient.shared.getTrophydex().apiResponse { (response) in
                    self.reloadData()
                }
            }
            else {
                self.reloadData()
            }
        } else {
            RideReportAPIClient.shared.getTrophydex().apiResponse { (response) in
                self.reloadData()
            }
        }
    }
    
    private func reloadData() {
        trophyCategories = []
        
        let url = CoreDataManager.shared.applicationDocumentsDirectory.appendingPathComponent("trophydex.json")
        guard let jsonData = try? Data(contentsOf: url) else {
            return
        }
        
        let json = JSON(data: jsonData)
        
        guard let versionString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, let version = Int(versionString), let requiredVersion = json["requiredIOSClientVersion"].int, version >= requiredVersion else {
            let alertController = UIAlertController(title: "Ride Report needs to be updated", message: "Please update your Ride Report app to view your trophies.", preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "Update Ride Report", style: UIAlertActionStyle.default) { _ in
                if let appURL = URL(string: "itms://itunes.apple.com/us/app/ride-report-automatic-gps-bike-ride-tracker/id1053230099") {
                    UIApplication.shared.openURL(appURL)
                }
            })
            alertController.addAction(UIAlertAction(title: "mm… mb later", style: UIAlertActionStyle.cancel) { _ in
                self.navigationController?.popViewController(animated: true)
            })
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        
        if let trophyCategoriesJson = json["trophyCategories"].array {
            for trophyCategoryJson in trophyCategoriesJson {
                if let trophyCategory = TrophyCategory(dictionary: trophyCategoryJson) {
                    trophyCategories.append(trophyCategory)
                }
            }
            
            self.tableView.reloadData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return trophyCategories.count
    }
    
    //
    // MARK: - Table View
    //
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableCell = self.tableView.dequeueReusableCell(withIdentifier: "TrophyCategoryCell", for: indexPath)
        if indexPath.section < trophyCategories.count {
            let trophyCategory = trophyCategories[indexPath.row]
            self.configureCell(tableCell, trophyCategory: trophyCategory, atIndex: indexPath.row)
        }
        return tableCell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section < trophyCategories.count {
            let trophyCategory = trophyCategories[indexPath.row]
            self.performSegue(withIdentifier: "showTrophyCategoryViewController", sender: trophyCategory)
        }
    }
    
    private var disclosureArrow: UIImage? = nil
    func getDisclosureArrow(_ tableCell: UITableViewCell)->UIImage? {
        if disclosureArrow != nil {
            return disclosureArrow
        }
        
        for case let button as UIButton in tableCell.subviews {
            let image = button.backgroundImage(for: .normal)?.withRenderingMode(.alwaysTemplate)
            disclosureArrow = image
            return image
        }
        
        return nil
    }
    
    func configureCell(_ tableCell: UITableViewCell, trophyCategory: TrophyCategory, atIndex index: Int) {
        guard let trophiesView = tableCell.viewWithTag(1) as? UIStackView,
            let label = tableCell.viewWithTag(3) as? UILabel,
            let button = tableCell.viewWithTag(4) as? UIButton else {
            return
        }
        
        button.backgroundColor = UIColor.clear
        if let chevronImage = getDisclosureArrow(tableCell) {
            tableCell.accessoryView = nil
            tableCell.accessoryType = .none
            button.setImage(chevronImage, for: .normal)
            button.imageView?.tintColor = ColorPallete.shared.darkGrey
            button.imageEdgeInsets = UIEdgeInsets(top: 10, left: self.view.frame.size.width - chevronImage.size.width - 14, bottom: 0, right: 0)
        }
        
        label.text = trophyCategory.name
        button.removeTarget(nil, action: nil, for: .touchUpInside)
        button.addAction(for: .touchUpInside) {
            self.performSegue(withIdentifier: "showTrophyCategoryViewController", sender: trophyCategory)
        }
        
        trophiesView.spacing = trophySpacing
        
        var i = 0
        for trophyProgress in trophyCategory.trophyProgresses {
            var trophyButon: TrophyProgressButton!
            if i >= trophiesView.arrangedSubviews.count {
                trophyButon = TrophyProgressButton()
                trophyButon.translatesAutoresizingMaskIntoConstraints = false
                trophiesView.addArrangedSubview(trophyButon)
            } else {
                trophyButon = trophiesView.arrangedSubviews[i] as! TrophyProgressButton
            }
            
            trophyButon.trophyProgress = trophyProgress
            trophyButon.removeTarget(nil, action: nil, for: .touchUpInside)
            trophyButon.addAction(for: .touchUpInside) {
                let storyBoard = UIStoryboard(name: "Main", bundle: nil)
                guard let trophyVC = storyBoard.instantiateViewController(withIdentifier: "trophyViewController") as? TrophyViewController else {
                    return
                }
                
                trophyVC.trophyProgress = trophyProgress
                
                self.customPresentViewController(TrophyViewController.presenter(), viewController: trophyVC, animated: true, completion: nil)
            }
            
            i += 1
            if i >= self.trophiesPerRow {
                // show up to a screen and a half's width of featured trophy progresses
                break
            }
        }
        
        while i < trophiesView.arrangedSubviews.count {
            let trophyButon = trophiesView.arrangedSubviews[i] as! TrophyProgressButton

            trophyButon.trophyProgress = nil
            trophyButon.removeTarget(nil, action: nil, for: .touchUpInside)
            
            i += 1
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showTrophyCategoryViewController") {
            guard let trophyCategory = sender as? TrophyCategory else {
                return
            }
            
            if let trophyCategoryVC = segue.destination as? TrophyCategoryViewController {
                trophyCategoryVC.trophyCategory = trophyCategory
            }
        }
    }
}
