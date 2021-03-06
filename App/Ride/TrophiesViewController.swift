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
    private static let marginX: CGFloat = 18.0
    private static let minimumTrophySpacing: CGFloat = 10.0
    
    public var jsonRows: [JSON] = []
    private var reachabilityManager: NetworkReachabilityManager?
    private var trophiesPerRow: Int!
    private var trophySpacing: CGFloat = 10.0
    private var shouldHideStatSeries = false //If the user has no rides, do not show this cell
    
    enum StatsAnimationState {
        case waitingForData
        case needsAnimation
        case animated
    }
    private var statsAnimationState = StatsAnimationState.waitingForData
    
    override func viewDidLoad() {
        self.title = "Achievements"
        
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 136
        
        reachabilityManager = NetworkReachabilityManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
            // avoid a bug that could have this called twice on app launch
            NotificationCenter.default.addObserver(self, selector: #selector(TrophiesViewController.updateData), name:UIApplication.didBecomeActiveNotification, object: nil)
        })
        
        self.trophiesPerRow =  Int(floor((self.view.frame.size.width) / (TrophyProgressButton.defaultBadgeDimension + TrophiesViewController.minimumTrophySpacing)))
        self.trophySpacing = (self.view.frame.size.width - 2*TrophiesViewController.marginX - (CGFloat(trophiesPerRow) * TrophyProgressButton.defaultBadgeDimension)) / CGFloat(trophiesPerRow - 1)
        
        self.statsAnimationState = .waitingForData
        self.reloadData()
        self.updateData()
    }
    
    @objc fileprivate func updateData() {        
        self.statsAnimationState = .needsAnimation
        self.reloadData()
    }
    
    private func reloadData() {
        jsonRows = []
        self.shouldHideStatSeries = false
        
        let url = CoreDataManager.shared.applicationDocumentsDirectory.appendingPathComponent("trophydex.json")
        guard let jsonData = try? Data(contentsOf: url) else {
            return
        }
        
        let json = try? JSON(data: jsonData)
        
        guard let versionString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, let version = Int(versionString), let requiredVersion = json?["requiredIOSClientVersion"].int, version >= requiredVersion else {
            let alertController = UIAlertController(title: "Ride needs to be updated", message: "Please update your Ride app to view your trophies.", preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "Update Ride", style: UIAlertAction.Style.default) { _ in
                if let appURL = URL(string: "itms://itunes.apple.com/us/app/ride-report-automatic-gps-bike-ride-tracker/id1053230099") {
                    UIApplication.shared.openURL(appURL)
                }
            })
            alertController.addAction(UIAlertAction(title: "mm… mb later", style: UIAlertAction.Style.cancel) { _ in
                self.navigationController?.popViewController(animated: true)
            })
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        
        if let jsonArray = json?["content"].array {
            jsonRows = jsonArray
            
            for row in jsonRows {
                if let type = row["type"].string, type == "stats_series" {
                    var totalRideCount = 0
                    if let months = row["content"].array {
                        for monthStats in months {
                            if let rides = monthStats["rides"].int {
                                totalRideCount += rides
                            }
                        }
                        if totalRideCount == 0 {
                            self.shouldHideStatSeries = true
                            break
                        }
                    }
                   
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
                    var tableCell = self.tableView.dequeueReusableCell(withIdentifier: "EmptyTableViewCell", for: indexPath)
                    if !self.shouldHideStatSeries {
                        tableCell = self.tableView.dequeueReusableCell(withIdentifier: "StatsSeriesCell", for: indexPath)
                        self.configureStatsSeriesCell(tableCell, json: jsonRow)
                    }
                    return tableCell
                } else if type == "encouragements" {
                    let tableCell = self.tableView.dequeueReusableCell(withIdentifier: "EncouragementsCell", for: indexPath)
                    tableCell.selectionStyle = UITableViewCell.SelectionStyle.none
                    self.configureEncouragementsCell(tableCell, json: jsonRow)
                    return tableCell
                }
            }
        }  
        
        // if it's not a type we know about, render a 0 height cell to skip over it.
        return self.tableView.dequeueReusableCell(withIdentifier: "EmptyTableViewCell", for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section < jsonRows.count {
            let jsonRow = jsonRows[indexPath.row]
            guard let type = jsonRow["type"].string else {
                return
            }
            
            if type == "category" {
                if let trophyCategory = TrophyCategory(jsonRow) {
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
    
    func configureEncouragementsCell(_ tableCell: UITableViewCell, json: JSON) {
        guard let scrollView = tableCell.viewWithTag(1) as? UIScrollView,
            let encouragementsStackView = tableCell.viewWithTag(2) as? UIStackView else {
                return
        }
        
        guard let contentArray = json["content"].array else {
            return
        }
        
        var i = 0
        for content in contentArray {
            guard let type = content["type"].string else {
                break
            }

            if type == "trophy_encouragement" {
                let trophyProgress = TrophyProgress(content["trophy_progress"])
                var encouragementView: EncouragementView!
                if i >= encouragementsStackView.arrangedSubviews.count {
                    encouragementView = EncouragementView()
                    encouragementView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width - 30 - TrophiesViewController.marginX, height: scrollView.frame.size.height)
                    encouragementView.translatesAutoresizingMaskIntoConstraints = false
                    encouragementsStackView.addArrangedSubview(encouragementView)
                } else {
                    encouragementView = encouragementsStackView.arrangedSubviews[i] as! EncouragementView
                }
                
                encouragementView.title = content["title"].string
                encouragementView.subtitle = content["subtitle"].string
                encouragementView.header = content["header"].string
                encouragementView.trophyProgress = trophyProgress
                
                encouragementView.removeTarget(nil, action: nil, for: .touchUpInside)
                encouragementView.addAction(for: .touchUpInside) {
                    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
                    guard let trophyVC = storyBoard.instantiateViewController(withIdentifier: "trophyViewController") as? TrophyViewController, let trophyProgress = trophyProgress else {
                        return
                    }
                    
                    self.customPresentViewController(TrophyViewController.presenter(), viewController: trophyVC, animated: true, completion: nil)
                    trophyVC.trophyProgress = trophyProgress
                }
                
                i += 1
            } else {
                // skip the cell
            }
        }
        
        while i < encouragementsStackView.arrangedSubviews.count {
            let encouragementView = encouragementsStackView.arrangedSubviews[i] as! EncouragementView
            encouragementsStackView.removeArrangedSubview(encouragementView)
            encouragementView.removeFromSuperview()
            
            i += 1
        }
    }
    
    func configureTrophyCategoryCell(_ tableCell: UITableViewCell, json: JSON) {
        guard let trophyCategory = TrophyCategory(json) else {
            return
        }
        
        guard let trophiesView = tableCell.viewWithTag(1) as? UIStackView,
            let label = tableCell.viewWithTag(3) as? UILabel,
            let button = tableCell.viewWithTag(4) as? UIButton else {
            return
        }
        
        for subview in trophiesView.arrangedSubviews {
            if !(subview is TrophyProgressButton) {
                trophiesView.removeArrangedSubview(subview)
            }
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
        trophiesView.distribution = .fill
        
        var i = 0
        for trophyProgress in trophyCategory.trophyProgresses {
            var trophyButton: TrophyProgressButton!
            if i >= trophiesView.arrangedSubviews.count {
                trophyButton = TrophyProgressButton()
                trophyButton.translatesAutoresizingMaskIntoConstraints = false
                trophyButton.setContentHuggingPriority(UILayoutPriority(rawValue: 1000), for: .horizontal)
                trophiesView.addArrangedSubview(trophyButton)
            } else if let button = trophiesView.arrangedSubviews[i] as? TrophyProgressButton  {
                trophyButton = button
            }
            else {
                continue
            }
            
            trophyButton.trophyProgress = trophyProgress
            trophyButton.removeTarget(nil, action: nil, for: .touchUpInside)
            trophyButton.addAction(for: .touchUpInside) {
                let storyBoard = UIStoryboard(name: "Main", bundle: nil)
                guard let trophyVC = storyBoard.instantiateViewController(withIdentifier: "trophyViewController") as? TrophyViewController else {
                    return
                }
                
                self.customPresentViewController(TrophyViewController.presenter(), viewController: trophyVC, animated: true, completion: nil)
                trophyVC.trophyProgress = trophyProgress
            }
            
            i += 1
            if i >= self.trophiesPerRow {
                // show up to a screen and a half's width of featured trophy progresses
                break
            }
        }
        
        if trophyCategory.trophyProgresses.count < self.trophiesPerRow {
            // Sometimes when the stack view is not full of trophy buttons they get stretched, so let's add a placeholder view
            let stretchingView = UIView()
            stretchingView.setContentHuggingPriority(UILayoutPriority(rawValue: 1), for: .horizontal)
            stretchingView.backgroundColor = .clear
            stretchingView.translatesAutoresizingMaskIntoConstraints = false
            
            trophiesView.addArrangedSubview(stretchingView)
        }
//        else if trophyCategory.trophyProgresses.count >= self.trophiesPerRow {
//            for subview in trophiesView.arrangedSubviews {
//                if !(subview is TrophyProgressButton) {
//                  trophiesView.removeArrangedSubview(subview)
//                }
//            }
//        }
        
        while i < trophiesView.arrangedSubviews.count {
            if let trophyButon = trophiesView.arrangedSubviews[i] as? TrophyProgressButton {
                trophyButon.trophyProgress = nil
                trophyButon.removeTarget(nil, action: nil, for: .touchUpInside)
            }
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
        
        guard self.statsAnimationState != .waitingForData else {
            // clear the graph so it can animate in once the data comes in
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
        if self.statsAnimationState == .needsAnimation {
            self.statsAnimationState = .animated
            lineChartView.animate(xAxisDuration: 0.5, yAxisDuration: 0.0)
        }
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
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            self.performSegue(withIdentifier: "showTrophySnowGlobe", sender: self)
        }
    }
}
