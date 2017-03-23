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

var dailyData: [ChartDataEntry] = []

if let seriesJson = json["series"].dictionary, let days = seriesJson["day"]?.array {
    var i = 0
    for day in days {
        if let dayDict = day.dictionary, let rides = day["rides"].double {
            dailyData.append(ChartDataEntry(x: Double(i), y: rides, data: dayDict as NSDictionary))
        }
        i += 1
    }
}

//
let view = LineChartView(frame: CGRect(x: 0, y: 0, width: 600, height: 600))
let lineChartView = LineChartView(frame: CGRect(x: 0, y: 200, width: 600, height: 400))
view.addSubview(lineChartView)

let data = LineChartData()
let ds1 = LineChartDataSet(values: dailyData, label: "Rides")
ds1.colors = [ColorPallete.shared.goodGreen]
ds1.circleColors = [ColorPallete.shared.goodGreen]
ds1.drawValuesEnabled = false
ds1.drawHorizontalHighlightIndicatorEnabled = false
ds1.highlightColor = ColorPallete.shared.goodGreen
ds1.highlightLineWidth = 2.0
data.addDataSet(ds1)

lineChartView.data = data
lineChartView.xAxis.axisMaximum = Double(dailyData.count)
lineChartView.xAxis.axisMaximum = Double(dailyData.count - 30) // last 30 days

for axis in [lineChartView.xAxis, lineChartView.leftAxis, lineChartView.rightAxis] {
    axis.drawLabelsEnabled = false
    axis.drawAxisLineEnabled = false
    axis.drawGridLinesEnabled = false
    axis.drawLabelsEnabled = false
    axis.drawAxisLineEnabled = false
    axis.drawGridLinesEnabled = false
}

lineChartView.drawBordersEnabled = false
lineChartView.legend.enabled = false
lineChartView.chartDescription = nil
lineChartView.marker = BalloonMarker(color: ColorPallete.shared.darkGrey, font: UIFont.systemFont(ofSize: 18), textColor: ColorPallete.shared.almostWhite, insets: UIEdgeInsetsMake(8.0, 12.0, 14.0, 12.0))
lineChartView.gridBackgroundColor = UIColor.white

//
lineChartView.backgroundColor = UIColor.white
PlaygroundPage.current.liveView = lineChartView

//
lineChartView.animate(xAxisDuration: 0.0, yAxisDuration: 1.0)
