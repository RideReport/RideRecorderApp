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
import Charts

class TrophiesViewController: UITableViewController {
    public var jsonRows: [JSON] = []
    private var reachabilityManager: NetworkReachabilityManager?
    private var trophiesPerRow: Int!
    private var trophySpacing: CGFloat = 18.0
    private var shouldShowGraphAnimation = false
    
    override func viewDidLoad() {
        self.title = "Achievements"
        
        reachabilityManager = NetworkReachabilityManager()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
            // avoid a bug that could have this called twice on app launch
            NotificationCenter.default.addObserver(self, selector: #selector(TrophiesViewController.updateData), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        })
        
        self.trophiesPerRow =  Int(floor((self.view.frame.width) / (TrophyProgressButton.defaultBadgeDimension + trophySpacing)))
        
        self.shouldShowGraphAnimation = false
        self.reloadData()
        updateData()
    }
    
    @objc fileprivate func updateData() {
        if let manager = reachabilityManager  {
            if  manager.isReachable {
                RideReportAPIClient.shared.getTrophydex().apiResponse { (response) in
                    self.shouldShowGraphAnimation = true
                    self.reloadData()
                }
            }
            else {
                shouldShowGraphAnimation = true
                self.reloadData()
            }
        } else {
            RideReportAPIClient.shared.getTrophydex().apiResponse { (response) in
                self.shouldShowGraphAnimation = true
                self.reloadData()
            }
        }
    }
    
    private func reloadData() {
        jsonRows = []
        
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
        
        if let jsonArray = json["content"].array {
            jsonRows = jsonArray
            
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
        return jsonRows.count
    }
    
    //
    // MARK: - Table View
    //
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section < jsonRows.count {
            let jsonRow = jsonRows[indexPath.row]
            if let type = jsonRow["type"].string {
                if type == "category" {
                    let tableCell = self.tableView.dequeueReusableCell(withIdentifier: "TrophyCategoryCell", for: indexPath)
                    self.configureTrophyCategoryCell(tableCell, json: jsonRow)
                    return tableCell
                } else if type == "stats_series" {
                    let tableCell = self.tableView.dequeueReusableCell(withIdentifier: "StatsSeriesCell", for: indexPath)
                    self.configureStatsSeriesCell(tableCell, json: jsonRow)
                    return tableCell
                }
            }
        }  
        
        return self.tableView.dequeueReusableCell(withIdentifier: "StatsSeriesCell", for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section < jsonRows.count {
            let jsonRow = jsonRows[indexPath.row]
            guard let type = jsonRow["type"].string else {
                return
            }
            
            if type == "category" {
                if let trophyCategory = TrophyCategory(dictionary: jsonRow) {
                    self.performSegue(withIdentifier: "showTrophyCategoryViewController", sender: trophyCategory)
                }
            } else if type == "stats_series" {
                self.performSegue(withIdentifier: "showStatsViewController", sender: self)
            }
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
    
    func configureTrophyCategoryCell(_ tableCell: UITableViewCell, json: JSON) {
        guard let trophyCategory = TrophyCategory(dictionary: json) else {
            return
        }
        
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
        button.isUserInteractionEnabled = false
        
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
    
    func configureStatsSeriesCell(_ tableCell: UITableViewCell, json: JSON) {
        let timePeriod: Double = 12
        let timeInterval: Double = 30*24*3600.0
        
        guard let lineChartView = tableCell.viewWithTag(1) as? LineChartView,
            let label = tableCell.viewWithTag(3) as? UILabel,
            let button = tableCell.viewWithTag(4) as? UIButton else {
            return
        }
        
        label.text = json["name"].string ?? ""
        
        button.backgroundColor = UIColor.clear
        if let chevronImage = getDisclosureArrow(tableCell) {
            tableCell.accessoryView = nil
            tableCell.accessoryType = .none
            button.setImage(chevronImage, for: .normal)
            button.imageView?.tintColor = ColorPallete.shared.darkGrey
            button.imageEdgeInsets = UIEdgeInsets(top: 10, left: self.view.frame.size.width - chevronImage.size.width - 14, bottom: 0, right: 0)
        }
        
        button.isUserInteractionEnabled = false
        
        lineChartView.drawBordersEnabled = false
        lineChartView.legend.enabled = false
        lineChartView.chartDescription = nil
        lineChartView.pinchZoomEnabled = false
        lineChartView.dragEnabled = false
        lineChartView.gridBackgroundColor = UIColor.white
        lineChartView.noDataText = ""
        lineChartView.xAxis.drawAxisLineEnabled = false
        lineChartView.xAxis.drawGridLinesEnabled = false
        lineChartView.xAxis.drawLabelsEnabled = true
        lineChartView.xAxis.labelFont = UIFont.systemFont(ofSize: 12)
        lineChartView.xAxis.labelPosition = .bottom
        lineChartView.xAxis.labelTextColor = ColorPallete.shared.unknownGrey
        lineChartView.leftAxis.enabled = false
        lineChartView.leftAxis.drawAxisLineEnabled = false
        lineChartView.leftAxis.drawGridLinesEnabled = false
        lineChartView.leftAxis.drawLabelsEnabled = false
        lineChartView.leftAxis.spaceBottom = 0
        lineChartView.rightAxis.drawAxisLineEnabled = false
        lineChartView.rightAxis.drawGridLinesEnabled = true
        lineChartView.rightAxis.spaceBottom = 0
        lineChartView.rightAxis.gridColor = ColorPallete.shared.unknownGrey
        lineChartView.rightAxis.gridLineDashLengths = [3, 2]
        lineChartView.rightAxis.drawLabelsEnabled = true
        lineChartView.rightAxis.labelCount = 3
        lineChartView.rightAxis.labelFont = UIFont.boldSystemFont(ofSize: 12)
        lineChartView.rightAxis.labelTextColor = ColorPallete.shared.unknownGrey
        
        guard shouldShowGraphAnimation else {
            // clear the graph so it can animate in
            lineChartView.clear()
            
            return
        }
        
        guard let period = json["content"].array else {
            lineChartView.data = nil
            
            return
        }
        
        var entryData: [ChartDataEntry] = []
        var colors: [UIColor] = []
        
        for entry in period {
            if let entryDict = entry.dictionary, let meters = entry["meters"].float,
                let dateString = entry["date"].string, let date = Date.dateFromJSONString(dateString) {
                colors.append(meters > 0 ? ColorPallete.shared.primaryLight : ColorPallete.shared.unknownGrey)
                entryData.append(ChartDataEntry(x: date.timeIntervalSinceReferenceDate/timeInterval, y: Double(meters.localizedMajorUnit), data: entryDict as NSDictionary))
            }
        }
        
        let data = LineChartData()
        
        // a dotted line to the last value
        if entryData.count >= 2 {
            if let lastEntry = entryData.popLast(), let secondToLastEntry = entryData.last {
                // include the second to last entry in both data sets
                let dsLastValue = LineChartDataSet(values: [secondToLastEntry, lastEntry], label: "Last Ride")
                dsLastValue.colors = [ColorPallete.shared.unknownGrey]
                dsLastValue.circleColors = [lastEntry.y > 0 ? ColorPallete.shared.primaryLight : ColorPallete.shared.unknownGrey]
                dsLastValue.drawValuesEnabled = false
                dsLastValue.drawVerticalHighlightIndicatorEnabled = false
                dsLastValue.highlightColor = ColorPallete.shared.primaryLight
                dsLastValue.highlightLineWidth = 2.0
                dsLastValue.lineDashLengths = [4, 3]
                data.addDataSet(dsLastValue)
            }
        }
        
        let ds1 = LineChartDataSet(values: entryData, label: "Rides")
        ds1.colors = [ColorPallete.shared.primaryLight]
        ds1.circleColors = colors
        ds1.drawValuesEnabled = false
        ds1.drawVerticalHighlightIndicatorEnabled = false
        ds1.highlightColor = ColorPallete.shared.primaryLight
        ds1.highlightLineWidth = 2.0
        data.addDataSet(ds1)
        
        
        if (entryData.count == 0 || (entryData.count == 1 && entryData.first?.y == 0)) {
            lineChartView.xAxis.axisMinimum = Date().addingTimeInterval(-1 * timeInterval*timePeriod).timeIntervalSinceReferenceDate/timeInterval
            lineChartView.xAxis.axisMaximum = Date().timeIntervalSinceReferenceDate/timeInterval
            
            lineChartView.leftAxis.axisMinimum = 0
            lineChartView.leftAxis.axisMaximum = 10
            lineChartView.rightAxis.axisMinimum = 0
            lineChartView.rightAxis.axisMaximum = 10
        }
        
        lineChartView.data = data
        lineChartView.setVisibleXRange(minXRange: timePeriod, maxXRange: timePeriod)
        lineChartView.moveViewToX(entryData.last?.x ?? 0)
        lineChartView.animate(xAxisDuration: 0.5, yAxisDuration: 0.0)
        lineChartView.isHidden = false
        
        lineChartView.xAxis.valueFormatter = DateValueFormatter(timeInterval: timeInterval, dateFormat: "MMM")
        lineChartView.xAxis.granularityEnabled = true
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
    
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            self.performSegue(withIdentifier: "showTrophySnowGlobe", sender: self)
        }
    }
}
