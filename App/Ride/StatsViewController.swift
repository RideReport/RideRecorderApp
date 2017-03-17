//
//  StatsViewController.swift
//  Ride
//
//  Created by William Henderson on 3/17/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import Charts

class StatsViewController: UIViewController {
    
    @IBOutlet weak var lineChartView: LineChartView!
    
    override func viewDidLoad() {
        
        // Do any additional setup after loading the view.
        let ys1 = Array(1..<10).map { x in return sin(Double(x) / 2.0 / 3.141 * 1.5) }
        
        let yse1 = ys1.enumerated().map { x, y in return ChartDataEntry(x: Double(x), y: y) }
        
        let data = LineChartData()
        let ds1 = LineChartDataSet(values: yse1, label: "Rides")
        ds1.colors = [ColorPallete.shared.goodGreen]
        ds1.circleColors = [ColorPallete.shared.goodGreen]
        ds1.drawValuesEnabled = false
        ds1.drawHorizontalHighlightIndicatorEnabled = false
        ds1.highlightColor = ColorPallete.shared.goodGreen
        ds1.highlightLineWidth = 2
        data.addDataSet(ds1)
        
        self.lineChartView.data = data
        
        for axis in [self.lineChartView.xAxis, self.lineChartView.leftAxis, self.lineChartView.rightAxis] {
            axis.drawLabelsEnabled = false
            axis.drawAxisLineEnabled = false
            axis.drawGridLinesEnabled = false
            axis.drawLabelsEnabled = false
            axis.drawAxisLineEnabled = false
            axis.drawGridLinesEnabled = false
            
        }
        self.lineChartView.drawBordersEnabled = false
        self.lineChartView.legend.enabled = false
        self.lineChartView.chartDescription = nil
        self.lineChartView.marker = MarkerView()
        self.lineChartView.gridBackgroundColor = NSUIColor.white
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.lineChartView.animate(xAxisDuration: 0.0, yAxisDuration: 1.0)
    }
    
    @IBAction func showTrophies(sender: Any?) {
        if #available(iOS 9.0, *) {
            // ios 8 devices crash the trophy room due to a bug in sprite kit, so we disable it.
            self.performSegue(withIdentifier: "showRewardsView", sender: self)
        }
    }
}
