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

class StatsViewController: UIViewController {
    @IBOutlet weak var seriesSegment: UISegmentedControl!
    @IBOutlet weak var barChartView: BarChartView!
    @IBOutlet weak var lineChartView: LineChartView!
    
    @IBOutlet weak var rollupsSegment: UISegmentedControl!
    @IBOutlet weak var rollupsLabel: UILabel!
    
    @IBOutlet weak var piechart1: PieChartView!
    @IBOutlet weak var piechart2: PieChartView!
    
    private var chartJson: JSON!
    
    override func viewDidLoad() {
        self.title = "Ride Statistics"
        
        lineChartView.drawBordersEnabled = false
        lineChartView.legend.enabled = false
        lineChartView.chartDescription = nil
        lineChartView.pinchZoomEnabled = false
        lineChartView.dragEnabled = true
        lineChartView.autoScaleMinMaxEnabled = true
        lineChartView.marker = BalloonMarker(color: ColorPallete.shared.darkGrey, font: UIFont.systemFont(ofSize: 18), textColor: ColorPallete.shared.almostWhite, insets: UIEdgeInsetsMake(8.0, 12.0, 14.0, 12.0))
        lineChartView.gridBackgroundColor = UIColor.white
        
        for axis in [lineChartView.xAxis, lineChartView.leftAxis, lineChartView.rightAxis, barChartView.xAxis, barChartView.leftAxis, barChartView.rightAxis] {
            axis.drawAxisLineEnabled = false
            axis.drawGridLinesEnabled = false
        }
        lineChartView.xAxis.drawLabelsEnabled = true
        lineChartView.rightAxis.drawLabelsEnabled = true
        lineChartView.leftAxis.drawLabelsEnabled = false
        
        barChartView.rightAxis.drawLabelsEnabled = true
        barChartView.xAxis.drawLabelsEnabled = true
        barChartView.leftAxis.drawLabelsEnabled = false
        
        barChartView.drawBordersEnabled = false
        barChartView.legend.enabled = false
        barChartView.chartDescription = nil
        barChartView.pinchZoomEnabled = false
        barChartView.dragEnabled = true
        barChartView.autoScaleMinMaxEnabled = true
        barChartView.marker = BalloonMarker(color: ColorPallete.shared.darkGrey, font: UIFont.systemFont(ofSize: 18), textColor: ColorPallete.shared.almostWhite, insets: UIEdgeInsetsMake(8.0, 12.0, 14.0, 12.0))
        barChartView.gridBackgroundColor = UIColor.white
        
        piechart1.legend.enabled = false
        piechart1.chartDescription = nil
        piechart1.holeRadiusPercent = 0.3
        piechart2.legend.enabled = false
        piechart2.chartDescription = nil
        piechart2.holeRadiusPercent = 0.3
        
        reloadData()
        
        APIClient.shared.getStatistics().apiResponse { (response) in
            self.reloadData()
        }
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
        switch seriesSegment.selectedSegmentIndex {
            case 0:
            seriesKey = "day"
            timePeriod = Double(30)
            case 1:
            seriesKey = "week"
            timePeriod = Double(20*7)
            case 2:
            seriesKey = "month"
            timePeriod = Double(18*30)
            default:
            seriesKey = "day"
            timePeriod = 30
        }
        
        if seriesKey == "month" {
            var entryData: [ChartDataEntry] = []
            var colors: [UIColor] = []
            
            if let seriesJson = chartJson["series"].dictionary, let period = seriesJson[seriesKey]?.array {
                for entry in period {
                    if let entryDict = entry.dictionary, let meters = entry["meters"].float,
                        let dateString = entry["date"].string, let date = Date.dateFromJSONString(dateString) {
                        colors.append(meters > 0 ? ColorPallete.shared.goodGreen : ColorPallete.shared.unknownGrey)
                        entryData.append(ChartDataEntry(x: date.timeIntervalSinceReferenceDate/(24*3600), y: Double(meters.localizedMajorUnit), data: entryDict as NSDictionary))
                    }
                }
            }

            let ds1 = LineChartDataSet(values: entryData, label: "Rides")
            ds1.colors = [ColorPallete.shared.goodGreen]
            ds1.circleColors = colors
            ds1.drawValuesEnabled = false
            ds1.drawHorizontalHighlightIndicatorEnabled = false
            ds1.highlightColor = ColorPallete.shared.goodGreen
            ds1.highlightLineWidth = 2.0
            let data = LineChartData(dataSet: ds1)
            
            lineChartView.data = data
            lineChartView.xAxis.valueFormatter = DateValueFormatter(showsDate: false)
            lineChartView.setVisibleXRange(minXRange: timePeriod, maxXRange: timePeriod)
            lineChartView.moveViewToX(entryData.last?.x ?? 0)
            lineChartView.animate(xAxisDuration: 0.5, yAxisDuration: 0.0)
            lineChartView.isHidden = false
            barChartView.isHidden = true
        } else {
            var entryData: [BarChartDataEntry] = []
            
            if let seriesJson = chartJson["series"].dictionary, let period = seriesJson[seriesKey]?.array {
                for entry in period {
                    if let entryDict = entry.dictionary, let meters = entry["meters"].float,
                        let dateString = entry["date"].string, let date = Date.dateFromJSONString(dateString) {
                        entryData.append(BarChartDataEntry(x: date.timeIntervalSinceReferenceDate/(24*3600), y: Double(meters.localizedMajorUnit), data: entryDict as NSDictionary))
                    }
                }
            }
            
            let ds1 = BarChartDataSet(values: entryData, label: "Rides")
            ds1.colors = [ColorPallete.shared.goodGreen]
            ds1.drawValuesEnabled = false
            ds1.highlightColor = ColorPallete.shared.goodGreen
            ds1.highlightLineWidth = 2.0
            let data = BarChartData(dataSet: ds1)
            
            barChartView.data = data
            barChartView.xAxis.valueFormatter = DateValueFormatter(showsDate: true)
            barChartView.setVisibleXRange(minXRange: timePeriod, maxXRange: timePeriod)
            barChartView.moveViewToX(entryData.last?.x ?? 0)
            barChartView.animate(xAxisDuration: 0.0, yAxisDuration: 0.5)
            barChartView.isHidden = false
            lineChartView.isHidden = true
        }
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
        
        let valueAttributes: [String: Any] = [NSForegroundColorAttributeName: ColorPallete.shared.darkGrey, NSFontAttributeName: font, NSParagraphStyleAttributeName: paragraphStyle]
        let unitAttributes: [String: Any] = [NSForegroundColorAttributeName: ColorPallete.shared.darkGrey, NSFontAttributeName: unitsFont, NSParagraphStyleAttributeName: paragraphStyle]
        
        if let rollupsJson = chartJson["rollups"].dictionary, let statsDict = rollupsJson[rollupsKey]?.dictionary {
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
                rollupsString.append(NSAttributedString(string: "rides", attributes: unitAttributes))
                rollupsString.append(NSAttributedString(string: "\n", attributes: unitAttributes))
            }
            
            if let meters = statsDict["meters"]?.float {
                let components = meters.distanceString.components(separatedBy: " ")
                if components.count == 2 {
                    rollupsString.append(NSAttributedString(string: components[0], attributes: valueAttributes))
                    rollupsString.append(NSAttributedString(string: " ", attributes: valueAttributes))
                    rollupsString.append(NSAttributedString(string: components[1], attributes: unitAttributes))
                    rollupsString.append(NSAttributedString(string: "\n", attributes: unitAttributes))
                }
            }
            
            if let trophiesCount = statsDict["trophies"]?.int, let trophiesString = integerFormatter.string(from: NSNumber(value: trophiesCount)) {
                rollupsString.append(NSAttributedString(string: trophiesString, attributes: valueAttributes))
                rollupsString.append(NSAttributedString(string: " ", attributes: valueAttributes))
                rollupsString.append(NSAttributedString(string: "trophies", attributes: unitAttributes))
                rollupsString.append(NSAttributedString(string: "\n", attributes: unitAttributes))

            }
            
            if let grams = statsDict["co2_saved_grams"]?.float, let co2String = integerFormatter.string(from: NSNumber(value: grams/1000.0)) {
                rollupsString.append(NSAttributedString(string: co2String, attributes: valueAttributes))
                rollupsString.append(NSAttributedString(string: " ", attributes: valueAttributes))
                rollupsString.append(NSAttributedString(string: "kg CO2 saved", attributes: unitAttributes))
            }
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
        
        let font  = UIFont.boldSystemFont(ofSize: 14)
        
        let percentFormatter = NumberFormatter()
        percentFormatter.numberStyle = .percent
        percentFormatter.maximumFractionDigits = 1
        percentFormatter.multiplier = 100.0
        percentFormatter.percentSymbol = "%"
        
        var entryData1: [PieChartDataEntry] = []
        let colors1: [UIColor] = [ColorPallete.shared.goodGreen, ColorPallete.shared.transitBlue, ColorPallete.shared.badRed, ColorPallete.shared.darkGrey]
        
        if let rollupsJson = chartJson["rollups"].dictionary, let statsDict = rollupsJson[rollupsKey]?.dictionary, let conditionsJson = statsDict["conditions"]?.array {
            for entry in conditionsJson {
                if let fraction = entry["fraction"].double, let label = entry["label"].string, fraction > 0 {
                    let data = PieChartDataEntry(value: fraction, label: label)
                    entryData1.append(data)
                }
            }
        }
        
        let dataSet1 = PieChartDataSet(values: entryData1, label: "Weather")
        dataSet1.sliceSpace = 2.0
        dataSet1.automaticallyDisableSliceSpacing = true
        dataSet1.colors = colors1
        
        let data1 = PieChartData(dataSet: dataSet1)
        data1.setValueTextColor(ColorPallete.shared.almostWhite)
        data1.setValueFont(font)
        data1.setValueFormatter(DefaultValueFormatter(formatter: percentFormatter))
        
        piechart1.data = data1
        
        var entryData2: [PieChartDataEntry] = []
        let colors2: [UIColor] = [ColorPallete.shared.autoBrown, ColorPallete.shared.goodGreen]
        
        if let rollupsJson = chartJson["rollups"].dictionary, let statsDict = rollupsJson[rollupsKey]?.dictionary, let modeJson = statsDict["mode"]?.array {
            for entry in modeJson {
                if let fraction = entry["fraction"].double, let label = entry["label"].string, fraction > 0 {
                    let data = PieChartDataEntry(value: fraction, label: label)
                    entryData2.append(data)
                }
            }
        }
        
        let dataSet2 = PieChartDataSet(values: entryData2, label: "Mode-Share")
        dataSet2.sliceSpace = 2.0
        dataSet2.automaticallyDisableSliceSpacing = true
        dataSet2.colors = colors2
        
        let data2 = PieChartData(dataSet: dataSet2)
        data2.setValueTextColor(ColorPallete.shared.almostWhite)
        data2.setValueFont(font)
        data2.setValueFormatter(DefaultValueFormatter(formatter: percentFormatter))
        
        piechart2.data = data2
        
        piechart1.animate(xAxisDuration: 0.5, easingOption: .easeOutBounce)
        piechart2.animate(xAxisDuration: 0.5, easingOption: .easeOutBounce)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        barChartView.animate(xAxisDuration: 0.0, yAxisDuration: 0.5)
        piechart1.animate(xAxisDuration: 0.5, easingOption: .easeOutBounce)
        piechart2.animate(xAxisDuration: 0.5, easingOption: .easeOutBounce)
    }
    
    @IBAction func showTrophies(sender: Any?) {
        if #available(iOS 9.0, *) {
            // ios 8 devices crash the trophy room due to a bug in sprite kit, so we disable it.
            self.performSegue(withIdentifier: "showRewardsView", sender: self)
        }
    }
}
