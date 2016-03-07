//
//  ViewController.swift
//  Motion
//
//  Created by William Henderson on 3/2/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftChart

class ViewController: UIViewController {
    
    private var keepGoing: Bool = false
    private var synth: AVSpeechSynthesizer = AVSpeechSynthesizer()

    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var lineChart: Chart!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func startStop(sender: AnyObject) {
        self.keepGoing = !self.keepGoing
        
        if (self.keepGoing) {
            self.runQuery()
            self.startStopButton.setTitle("Stop", forState: UIControlState.Normal)
        } else {
            self.startStopButton.setTitle("Start", forState: UIControlState.Normal)
        }
    }
    
    private func runQuery() {
        let sample = DeviceMotionsSample()
        MotionManager.sharedManager.queryCurrentActivityType(forDeviceMotionSample: sample) {[weak self] (activityType, confidence) -> Void in
            guard let strongSelf = self else {
            return
            }
            
            var activityString = ""
            
            switch activityType {
            case .Automotive:
            activityString = "Driving"
            case .Cycling:
            activityString = "Biking"
            case .Running:
            activityString = "Running"
            case .Transit:
            activityString = "Transit"
            case .Walking:
            activityString = "Walking"
            case .Stationary:
            activityString = "Stationary"
            case .Unknown:
            activityString = "Unknown"
            }
            
            strongSelf.activityLabel.text = activityString
            
            let utterance = AVSpeechUtterance(string: activityString)
            utterance.rate = 0.6
            strongSelf.synth.speakUtterance(utterance)
            
//            let series = ChartSeries(debugData)
//            series.color = ChartColors.greenColor()
//            strongSelf.lineChart.removeSeries()
//            strongSelf.lineChart.addSeries(series)
            
            if strongSelf.keepGoing {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.runQuery()
                }
            }
        }
    }
}

