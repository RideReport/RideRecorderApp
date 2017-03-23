//: Playground - noun: a place where people can play
import UIKit
import PlaygroundSupport
import Charts
import SwiftyJSON

class foo: ChartViewDelegate {
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        
    }
    
    // Called when nothing has been selected or an "un-select" has been made.
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        
    }
}

let url = Bundle.main.url(forResource: "stats", withExtension: "json")
let jsonData = try? Data(contentsOf: url!)
let json = JSON(data: jsonData!)

var dailyData: [BarChartDataEntry] = []

if let seriesJson = json["series"].dictionary, let days = seriesJson["week"]?.array {
    var i = 0
    for day in days {
        if let dayDict = day.dictionary, let rides = day["rides"].double {
            dailyData.append(BarChartDataEntry(x: Double(i), y: rides, data: dayDict as NSDictionary))
        }
        i += 1
    }
}

//
let barChartView = BarChartView(frame: CGRect(x: 0, y: 0, width: 600, height: 340))
let view = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
view.backgroundColor = UIColor.red
view.addSubview(barChartView)

barChartView.drawBarShadowEnabled = false
barChartView.xAxis.drawLabelsEnabled = true
barChartView.chartDescription?.enabled = false
barChartView.xAxis.drawAxisLineEnabled = false
barChartView.xAxis.drawGridLinesEnabled = false
barChartView.xAxis.labelPosition = .bottom
barChartView.rightAxis.spaceBottom = 0
barChartView.leftAxis.spaceBottom = 0
barChartView.leftAxis.enabled = false
barChartView.rightAxis.axisMinimum = 0
barChartView.rightAxis.drawAxisLineEnabled = false
barChartView.rightAxis.drawLabelsEnabled = true
barChartView.rightAxis.labelCount = 5
barChartView.rightAxis.labelFont = UIFont.systemFont(ofSize: 8)
barChartView.rightAxis.labelTextColor = UIColor.white
barChartView.leftAxis.drawLabelsEnabled = false

barChartView.drawBordersEnabled = false
barChartView.legend.enabled = false
barChartView.chartDescription = nil
barChartView.gridBackgroundColor = UIColor.white

let data = BarChartData()
let ds1 = BarChartDataSet(values: dailyData, label: "Rides")
ds1.colors = [UIColor.white]
ds1.drawValuesEnabled = false
ds1.highlightColor = UIColor.green
ds1.highlightLineWidth = 2.0
data.addDataSet(ds1)

barChartView.data = data
PlaygroundPage.current.liveView = view

//
barChartView.animate(xAxisDuration: 0.0, yAxisDuration: 1.0)
