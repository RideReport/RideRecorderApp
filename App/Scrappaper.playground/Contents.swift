//: Playground - noun: a place where people can play
import UIKit
import PlaygroundSupport
import Charts

class foo: ChartViewDelegate {
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        
    }
    
    // Called when nothing has been selected or an "un-select" has been made.
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        
    }
}

//
let view = LineChartView(frame: CGRect(x: 0, y: 0, width: 600, height: 600))
let lineChartView = LineChartView(frame: CGRect(x: 0, y: 200, width: 600, height: 400))
view.addSubview(lineChartView)

// Do any additional setup after loading the view.
let ys1 = Array(1..<10).map { x in return sin(Double(x) / 2.0 / 3.141 * 1.5) }

let date = Date()
let dataDict: [String: Any] = ["miles": 3.0, "rides": 13, "calories": 10, "date": date]
let yse1 = ys1.enumerated().map { x, y in return ChartDataEntry(x: Double(x), y: y, data: dataDict as NSDictionary) }

let data = LineChartData()
let ds1 = LineChartDataSet(values: yse1, label: "Rides")
ds1.colors = [ColorPallete.shared.goodGreen]
ds1.circleColors = [ColorPallete.shared.goodGreen]
ds1.drawValuesEnabled = false
ds1.drawHorizontalHighlightIndicatorEnabled = false
ds1.highlightColor = ColorPallete.shared.goodGreen
ds1.highlightLineWidth = 2.0
data.addDataSet(ds1)

lineChartView.data = data

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
