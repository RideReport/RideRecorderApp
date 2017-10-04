//
//  StatsViewController.swift
//  Ride
//
//  Created by William Henderson on 3/17/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Charts
import SwiftyJSON
import Alamofire

class StatsViewController: UIViewController {
    @IBOutlet weak var seriesSegment: UISegmentedControl!
    @IBOutlet weak var barChartView: BarChartView!
    @IBOutlet weak var lineChartView: LineChartView!
    
    @IBOutlet weak var rollupsSegment: UISegmentedControl!
    @IBOutlet weak var rollupsLabel: UILabel!
    
    @IBOutlet weak var piechart1: PieChartView!
    @IBOutlet weak var piechart2: PieChartView!
    
    @IBOutlet weak var emptyTripsView: UIView!
    @IBOutlet weak var bobbleChickView: UIView!
    @IBOutlet weak var emptyTripsLabel: UILabel!
    
    private var reachabilityManager: NetworkReachabilityManager?
    
    private var chartJson: JSON?
    
    override func viewDidLoad() {
        self.title = "Ride Statistics"
                
        lineChartView.drawBordersEnabled = false
        lineChartView.legend.enabled = false
        lineChartView.chartDescription = nil
        lineChartView.pinchZoomEnabled = false
        lineChartView.dragEnabled = true
        lineChartView.gridBackgroundColor = UIColor.white
        lineChartView.noDataText = ""
        
        barChartView.drawBordersEnabled = false
        barChartView.legend.enabled = false
        barChartView.chartDescription = nil
        barChartView.pinchZoomEnabled = false
        barChartView.dragEnabled = true
        barChartView.gridBackgroundColor = UIColor.white
        barChartView.noDataText = ""
        
        rollupsLabel.text = ""

        for axis in [lineChartView.xAxis, barChartView.xAxis] {
            axis.drawAxisLineEnabled = false
            axis.drawGridLinesEnabled = false
            axis.drawLabelsEnabled = true
            axis.labelFont = UIFont.systemFont(ofSize: 12)
            axis.labelPosition = .bottom
            axis.labelTextColor = ColorPallete.shared.unknownGrey
        }
        for axis in [lineChartView.leftAxis, barChartView.leftAxis] {
            axis.enabled = false
            axis.drawAxisLineEnabled = false
            axis.drawGridLinesEnabled = false
            axis.drawLabelsEnabled = false
            axis.spaceBottom = 0
        }
        for axis in [lineChartView.rightAxis, barChartView.rightAxis] {
            axis.drawAxisLineEnabled = false
            axis.drawGridLinesEnabled = true
            axis.spaceBottom = 0
            
            axis.gridColor = ColorPallete.shared.unknownGrey
            axis.gridLineDashLengths = [3, 2]
            axis.drawLabelsEnabled = true
            axis.labelCount = 5
            axis.labelFont = UIFont.boldSystemFont(ofSize: 12)
            axis.labelTextColor = ColorPallete.shared.unknownGrey
        }
        
        piechart1.legend.enabled = false
        piechart1.chartDescription = nil
        piechart1.holeRadiusPercent = 0.3
        piechart1.extraLeftOffset = 12
        piechart1.extraRightOffset = 20
        piechart1.noDataText = ""
        
        piechart2.legend.enabled = false
        piechart2.chartDescription = nil
        piechart2.holeRadiusPercent = 0.3
        piechart2.extraLeftOffset = 20
        piechart2.extraRightOffset = 12
        piechart2.noDataText = ""
        
        reachabilityManager = NetworkReachabilityManager()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(StatsViewController.bobbleChick))
        self.bobbleChickView.addGestureRecognizer(tapRecognizer)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        barChartView.animate(xAxisDuration: 0.0, yAxisDuration: 0.5)
        piechart1.animate(xAxisDuration: 0.5, easingOption: .easeOutBounce)
        piechart2.animate(xAxisDuration: 0.5, easingOption: .easeOutBounce)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
            // avoid a bug that could have this called twice on app launch
            NotificationCenter.default.addObserver(self, selector: #selector(StatsViewController.updateData), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        })
        
        updateData()
    }
    
    @objc fileprivate func updateData() {
        if let manager = reachabilityManager  {
            if  manager.isReachable {
                RideReportAPIClient.shared.getStatistics().apiResponse { (response) in
                    self.reloadData()
                }
            }
            else {
                self.reloadData()
            }
        } else {
            RideReportAPIClient.shared.getStatistics().apiResponse { (response) in
                self.reloadData()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func reloadData() {
        let url = CoreDataManager.shared.applicationDocumentsDirectory.appendingPathComponent("stats.json")
        guard let jsonData = try? Data(contentsOf: url) else {
            return
        }
        chartJson = JSON(data: jsonData)
        
        guard chartJson != nil else {
            return
        }
        
        self.reloadSeriesChartData()
        self.reloadRollups()
        self.reloadPieChartData()
        
        defer {
            if chartJson == nil {
                self.seriesSegment.isHidden = true
            } else {
                self.seriesSegment.isHidden = false
            }
        }
    }
    
    @IBAction func changeSeries(_ sender: Any) {
        reloadSeriesChartData()
    }
    
    @IBAction func changeRollups(_ sender: Any) {
        reloadRollups()
        reloadPieChartData()
    }
    
    func reloadSeriesChartData() {
        var seriesKey = ""
        var timePeriod: Double = 0
        var timeInterval: Double = 0
        switch seriesSegment.selectedSegmentIndex {
            case 0:
            seriesKey = "day"
            timePeriod = Double(20)
            timeInterval = Double(24*3600.0)
            case 1:
            seriesKey = "week"
            timePeriod = Double(20)
            timeInterval = Double(7*24*3600.0)
            case 2:
            seriesKey = "month"
            timePeriod = Double(12)
            timeInterval = Double(30*24*3600.0)
            default:
            seriesKey = "day"
            timePeriod = Double(30)
            timeInterval = Double(24*3600.0)
        }
        
        guard let json = chartJson, let seriesJson = json["series"].dictionary, let period = seriesJson[seriesKey]?.array else {
            barChartView.data = nil
            lineChartView.data = nil
            
            return
        }
        
        seriesSegment.setEnabled(true, forSegmentAt: 1)
        seriesSegment.setEnabled(true, forSegmentAt: 2)
        
        if seriesKey == "month" {
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
            barChartView.isHidden = true
            
            lineChartView.xAxis.valueFormatter = DateValueFormatter(timeInterval: timeInterval, dateFormat: "MMM")
            lineChartView.xAxis.granularityEnabled = true
            lineChartView.marker = BalloonMarker(chartView: lineChartView, period: .month, color: ColorPallete.shared.darkGrey, font: UIFont.systemFont(ofSize: 18), textColor: ColorPallete.shared.almostWhite, insets: UIEdgeInsetsMake(8.0, 8.0, 8.0, 8.0))
        } else {
            var entryData: [BarChartDataEntry] = []
            
            for entry in period {
                if let entryDict = entry.dictionary, let meters = entry["meters"].float,
                    let dateString = entry["date"].string, let date = Date.dateFromJSONString(dateString) {
                    entryData.append(BarChartDataEntry(x: date.timeIntervalSinceReferenceDate/timeInterval, y: Double(meters.localizedMajorUnit), data: entryDict as NSDictionary))
                }
            }
            
            let ds1 = BarChartDataSet(values: entryData, label: "Rides")
            ds1.colors = [ColorPallete.shared.primaryLight]
            ds1.drawValuesEnabled = false
            ds1.highlightColor = ColorPallete.shared.primaryLight
            ds1.highlightLineWidth = 2.0
            let data = BarChartData(dataSet: ds1)
            
            if (entryData.count == 0 || (entryData.count == 1 && entryData.first?.y == 0)) {
                barChartView.xAxis.axisMinimum = Date().addingTimeInterval(-1 * timeInterval*timePeriod).timeIntervalSinceReferenceDate/timeInterval
                barChartView.xAxis.axisMaximum = Date().timeIntervalSinceReferenceDate/timeInterval
                
                barChartView.leftAxis.axisMinimum = 0
                barChartView.leftAxis.axisMaximum = 10
                barChartView.rightAxis.axisMinimum = 0
                barChartView.rightAxis.axisMaximum = 10
                
                seriesSegment.setEnabled(false, forSegmentAt: 1)
                seriesSegment.setEnabled(false, forSegmentAt: 2)
            }
            
            barChartView.data = data
            barChartView.setVisibleXRange(minXRange: timePeriod, maxXRange: timePeriod)
            barChartView.moveViewToX(entryData.last?.x ?? 0)
            barChartView.animate(xAxisDuration: 0.0, yAxisDuration: 0.5)
            barChartView.isHidden = false
            lineChartView.isHidden = true
            if seriesKey == "week" {
                barChartView.xAxis.granularityEnabled = true
                barChartView.xAxis.granularity = 4 // at most a label every 4 weeks
                barChartView.xAxis.valueFormatter = DateValueFormatter(timeInterval: timeInterval, dateFormat: "MMM")
                barChartView.marker = BalloonMarker(chartView: barChartView, period: .week, color: ColorPallete.shared.darkGrey, font: UIFont.systemFont(ofSize: 18), textColor: ColorPallete.shared.almostWhite, insets: UIEdgeInsetsMake(8.0, 12.0, 14.0, 12.0))
            } else {
                barChartView.xAxis.granularityEnabled = true
                barChartView.xAxis.granularity = 5 // at most a label every 5 days. For some reason >5 rounds up to 10 =/.
                barChartView.xAxis.valueFormatter = DateValueFormatter(timeInterval: timeInterval, dateFormat: "MMM d")
                barChartView.marker = BalloonMarker(chartView: barChartView, period: .day, color: ColorPallete.shared.darkGrey, font: UIFont.systemFont(ofSize: 18), textColor: ColorPallete.shared.almostWhite, insets: UIEdgeInsetsMake(8.0, 8.0, 8.0, 8.0))
            }

        }
    }
    
    @objc func bobbleChick() {
        CATransaction.begin()
        
        let shakeAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        //let rotationOffsets = [CGFloat.pi, -CGFloat.pi_2, -0.2, 0.2, -0.2, 0.2, -0.2, 0.2, 0.0]
        shakeAnimation.values = [
            NSValue(caTransform3D:CATransform3DMakeRotation(10 * CGFloat(CGFloat.pi/180), 0, 0, -1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(-10 * CGFloat(CGFloat.pi/180), 0, 0, 1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(6 * CGFloat(CGFloat.pi/180), 0, 0, 1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(-6 * CGFloat(CGFloat.pi/180), 0, 0, 1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(2 * CGFloat(CGFloat.pi/180), 0, 0, 1)),
            NSValue(caTransform3D: CATransform3DMakeRotation(-2 * CGFloat(CGFloat.pi/180), 0, 0, 1))
        ]
        shakeAnimation.keyTimes = [0, 0.2, 0.4, 0.65, 0.8, 1]
        shakeAnimation.isAdditive = true
        shakeAnimation.duration = 0.6
        
        
        self.bobbleChickView.layer.add(shakeAnimation, forKey:"transform")
        
        CATransaction.commit()
    }
    
    func reloadRollups() {
        var rollupsKey = ""
        switch rollupsSegment.selectedSegmentIndex {
        case 0:
            rollupsKey = "thisyear"
        case 1:
            rollupsKey = "lastyear"
        case 2:
            rollupsKey = "lifetime"
        default:
            rollupsKey = "thisyear"
        }
        
        guard let json = chartJson, let rollupsJson = json["rollups"].dictionary, let statsDict = rollupsJson[rollupsKey]?.dictionary else {
            self.bobbleChickView.delay(0.2) {
                self.bobbleChick()
            }
            emptyTripsView.isHidden = false
            emptyTripsLabel.text = "How about this? We'll give you a baby chick trophy for your first ride."
            
            rollupsLabel.text = ""
            return
        }
        
        guard let rides = statsDict["rides"]?.int, rides > 0 else {
            rollupsLabel.text = ""
            emptyTripsView.isHidden = false
            self.bobbleChickView.delay(0.2) {
                self.bobbleChick()
            }
            
            if let lifeStatsDict = rollupsJson["lifetime"]?.dictionary, let lifetimeRides = lifeStatsDict["rides"]?.int, lifetimeRides == 0 {
                rollupsSegment.setEnabled(false, forSegmentAt: 2)
                emptyTripsLabel.text = "How about this? We'll give you a baby chick trophy for your first ride."
            } else if rollupsKey == "thisyear" {
                emptyTripsLabel.text = "You haven't taken any rides yet this year. What are you waiting for?"
            }
            
            return
        }
        
        emptyTripsView.isHidden = true
        rollupsSegment.setEnabled(true, forSegmentAt: 1)
        rollupsSegment.setEnabled(true, forSegmentAt: 2)
        
        if let lastyearStatsDict = rollupsJson["lastyear"]?.dictionary, let lastYearRides = lastyearStatsDict["rides"]?.int, lastYearRides == 0 {
            rollupsSegment.setEnabled(false, forSegmentAt: 1)
        }
        
        let rollupsString = NSMutableAttributedString(string: "")
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.2
        paragraphStyle.alignment = .left
        
        let integerFormatter = NumberFormatter()
        integerFormatter.locale = Locale.current
        integerFormatter.numberStyle = .decimal
        integerFormatter.usesGroupingSeparator = true
        integerFormatter.maximumFractionDigits = 0

        let font: UIFont = UIFont.boldSystemFont(ofSize: 18)
        let unitsFont: UIFont = UIFont.systemFont(ofSize: 18)
        
        let valueAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.foregroundColor: ColorPallete.shared.darkGrey, NSAttributedStringKey.font: font, NSAttributedStringKey.paragraphStyle: paragraphStyle]
        let unitAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.foregroundColor: ColorPallete.shared.darkGrey, NSAttributedStringKey.font: unitsFont, NSAttributedStringKey.paragraphStyle: paragraphStyle]
        
        if let impressiveArray = statsDict["impressive"]?.array, impressiveArray.count == 2 {
            if let emoji = impressiveArray[0].string, let stat = impressiveArray[1].string {
                rollupsString.append(NSAttributedString(string: emoji, attributes: unitAttributes))
                rollupsString.append(NSAttributedString(string: " ", attributes: valueAttributes))
                rollupsString.append(NSAttributedString(string: stat, attributes: unitAttributes))
                rollupsString.append(NSAttributedString(string: "\n", attributes: unitAttributes))
            }
        }
        
        if let rides = statsDict["rides"]?.int, let ridesString = integerFormatter.string(from: NSNumber(value: rides)) {
            rollupsString.append(NSAttributedString(string: ridesString, attributes: valueAttributes))
            rollupsString.append(NSAttributedString(string: " ", attributes: valueAttributes))
            rollupsString.append(NSAttributedString(string: rides == 1 ? "ride" : "rides", attributes: unitAttributes))
            rollupsString.append(NSAttributedString(string: "\n", attributes: unitAttributes))
        }
        
        if let meters = statsDict["meters"]?.float {
            let (distanceString, longUnits, _) = meters.distanceStrings(suppressFractionalUnits: true)
            rollupsString.append(NSAttributedString(string: distanceString, attributes: valueAttributes))
            rollupsString.append(NSAttributedString(string: " ", attributes: valueAttributes))
            rollupsString.append(NSAttributedString(string: longUnits, attributes: unitAttributes))
            rollupsString.append(NSAttributedString(string: "\n", attributes: unitAttributes))
        }
        
        if let trophiesCount = statsDict["trophies"]?.int, let trophiesString = integerFormatter.string(from: NSNumber(value: trophiesCount)) {
            rollupsString.append(NSAttributedString(string: trophiesString, attributes: valueAttributes))
            rollupsString.append(NSAttributedString(string: " ", attributes: valueAttributes))
            rollupsString.append(NSAttributedString(string: trophiesCount == 1 ? "trophy" : "trophies", attributes: unitAttributes))
            rollupsString.append(NSAttributedString(string: "\n", attributes: unitAttributes))
            
        }
        
        if let grams = statsDict["co2_saved_grams"]?.float, let co2String = integerFormatter.string(from: NSNumber(value: grams/1000.0)) {
            rollupsString.append(NSAttributedString(string: co2String, attributes: valueAttributes))
            rollupsString.append(NSAttributedString(string: " ", attributes: valueAttributes))
            rollupsString.append(NSAttributedString(string: "kg CO2 saved", attributes: unitAttributes))
        }
    
        rollupsLabel.attributedText = rollupsString
    }

    func reloadPieChartData() {
        var rollupsKey = ""
        switch rollupsSegment.selectedSegmentIndex {
        case 0:
            rollupsKey = "thisyear"
        case 1:
            rollupsKey = "lastyear"
        case 2:
            rollupsKey = "lifetime"
        default:
            rollupsKey = "thisyear"
        }
        
        guard let json = chartJson, let rollupsJson = json["rollups"].dictionary, let statsDict = rollupsJson[rollupsKey]?.dictionary else {
            piechart1.data = nil
            piechart2.data = nil
            return
        }
        
        let font  = UIFont.boldSystemFont(ofSize: 14)
        
        let percentFormatter = NumberFormatter()
        percentFormatter.numberStyle = .percent
        percentFormatter.maximumFractionDigits = 0
        percentFormatter.roundingMode = .up
        percentFormatter.multiplier = 100.0
        percentFormatter.percentSymbol = "%"
        
        var entryData1: [PieChartDataEntry] = []
        let colors1: [UIColor] = [ColorPallete.shared.primaryLight, ColorPallete.shared.turquoise, ColorPallete.shared.pink, ColorPallete.shared.darkGrey, ColorPallete.shared.autoBrown]
        
        var otherConditionsEntry: Double = 0
        if let conditionsJson = statsDict["conditions"]?.array {
            for entry in conditionsJson {
                if let fraction = entry["fraction"].double, let label = entry["label"].string, fraction > 0 {
                    if fraction > 0.06 {
                        let data = PieChartDataEntry(value: fraction, label: label)
                        entryData1.append(data)
                    } else {
                        otherConditionsEntry += fraction
                    }
                }
            }
        }
        
        if (otherConditionsEntry > 0) {
            let data = PieChartDataEntry(value: otherConditionsEntry, label: "")
            entryData1.append(data)
        }
        
        if (entryData1.count > 0) {
            let dataSet1 = PieChartDataSet(values: entryData1, label: "Weather")
            dataSet1.sliceSpace = 2.0
            dataSet1.automaticallyDisableSliceSpacing = true
            dataSet1.colors = colors1
            dataSet1.valueLinePart1OffsetPercentage = 0.65
            dataSet1.valueLineColor = ColorPallete.shared.darkGrey
            dataSet1.valueLinePart1Length = 0.8
            dataSet1.valueLinePart2Length = 0.4
            dataSet1.yValuePosition = .outsideSlice
            
            let data1 = PieChartData(dataSet: dataSet1)
            data1.setValueTextColor(ColorPallete.shared.darkGrey)
            data1.setValueFont(font)
            data1.setValueFormatter(DefaultValueFormatter(formatter: percentFormatter))
            
            piechart1.data = data1
        }
        
        var entryData2: [PieChartDataEntry] = []
        let colors2: [UIColor] = [ColorPallete.shared.primaryLight, ColorPallete.shared.turquoise, ColorPallete.shared.pink, ColorPallete.shared.darkGrey,  ColorPallete.shared.autoBrown]
        
        var otherModesEntry: Double = 0
        if let modeJson = statsDict["mode"]?.array {
            for entry in modeJson {
                if let fraction = entry["fraction"].double, let label = entry["label"].string, fraction > 0 {
                    if fraction > 0.06 {
                        let data = PieChartDataEntry(value: fraction, label: label)
                        entryData2.append(data)
                    } else {
                        otherModesEntry += fraction
                    }
                }
            }
        }
        
        if (otherModesEntry > 0) {
            let data = PieChartDataEntry(value: otherModesEntry, label: "")
            entryData2.append(data)
        }
        
        if (entryData2.count > 0) {
            let dataSet2 = PieChartDataSet(values: entryData2, label: "Mode-Share")
            dataSet2.sliceSpace = 2.0
            dataSet2.automaticallyDisableSliceSpacing = true
            dataSet2.colors = colors2
            dataSet2.valueLinePart1OffsetPercentage = 0.65
            dataSet2.valueLineColor = ColorPallete.shared.darkGrey
            dataSet2.valueLinePart1Length = 0.8
            dataSet2.valueLinePart2Length = 0.4
            dataSet2.yValuePosition = .outsideSlice
            
            let data2 = PieChartData(dataSet: dataSet2)
            data2.setValueTextColor(ColorPallete.shared.darkGrey)
            data2.setValueFont(font)
            data2.setValueFormatter(DefaultValueFormatter(formatter: percentFormatter))
            
            piechart2.data = data2
            
            piechart1.animate(xAxisDuration: 0.5, easingOption: .easeOutCirc)
            piechart2.animate(xAxisDuration: 0.5, easingOption: .easeOutCirc)
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            let storyBoard = UIStoryboard(name: "Main", bundle: nil)
            if let navVC = self.navigationController, let rewardsVC = storyBoard.instantiateViewController(withIdentifier: "rewardsViewController") as? RewardsViewController {
                let transition = CATransition()
                transition.duration = 0.6
                transition.type = kCATransitionFade
                navVC.view.layer.add(transition, forKey: nil)
                var newVCs = navVC.viewControllers
                _ = newVCs.popLast()
                newVCs.append(rewardsVC)
                navVC.setViewControllers(newVCs, animated: false)
            }
        }
    }
}
