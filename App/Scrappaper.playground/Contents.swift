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
let chartJson = JSON(data: jsonData!)

var dailyData: [BarChartDataEntry] = []

var entryData1: [PieChartDataEntry] = []
let colors1: [UIColor] = [UIColor.red, UIColor.green, UIColor.blue, UIColor.orange]

if let statsDict = chartJson["rollups"].dictionary, let conditionsJson = statsDict["conditions"]?.array {
    for entry in conditionsJson {
        if let fraction = entry["fraction"].double, let label = entry["label"].string, fraction > 0 {
            let data = PieChartDataEntry(value: fraction, label: label)
            entryData1.append(data)
        }
    }
}

//
let piechart1 = PieChartView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
piechart1.legend.enabled = false
piechart1.chartDescription = nil
piechart1.holeRadiusPercent = 0.4
//piechart1.transparentCircleRadiusPercent = 0.5
piechart1.centerTextRadiusPercent = 80
piechart1.extraLeftOffset = 10
piechart1.centerTextRadiusPercent = 0.1
piechart1.extraRightOffset = 10
piechart1.noDataText = ""

let view = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
view.backgroundColor = UIColor.white
view.addSubview(piechart1)


let dataSet1 = PieChartDataSet(values: entryData1, label: "Weather")
dataSet1.sliceSpace = 2.0
dataSet1.automaticallyDisableSliceSpacing = true
dataSet1.colors = colors1
dataSet1.valueLinePart1OffsetPercentage = 0.65
dataSet1.valueLineColor = UIColor.black
dataSet1.valueLinePart1Length = 0.8
dataSet1.valueLinePart2Length = 0.4
dataSet1.yValuePosition = .outsideSlice

let data1 = PieChartData(dataSet: dataSet1)
data1.setValueTextColor(UIColor.blue)

piechart1.data = data1



PlaygroundPage.current.liveView = view

//
piechart1.animate(xAxisDuration: 0.0, yAxisDuration: 1.0)
