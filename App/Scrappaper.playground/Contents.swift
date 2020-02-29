//: Playground - noun: a place where people can play
import UIKit
import PlaygroundSupport

let rideSummaryView = RideSummaryView(frame: CGRect(x: 0, y: 200, width: 400, height: 300))

let view = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
view.backgroundColor = UIColor.green
view.addSubview(rideSummaryView)

PlaygroundPage.current.liveView = view
PlaygroundPage.current.needsIndefiniteExecution = true

var rewardDicts: [[String: Any]] = []

var rewardDict: [String: Any] = [:]
rewardDict["displaySafeEmoji"] = "💵"
rewardDict["descriptionText"] = "MMoney trophy"
rewardDicts.append(rewardDict)

var rewardDict2: [String: Any] = [:]
rewardDict2["displaySafeEmoji"] = "🎱"
rewardDict2["descriptionText"] = "Eightball trophy thing"
rewardDicts.append(rewardDict2)

rideSummaryView.setTripSummary(tripLength: 3.1, description: "8:51am to SE 12th and Clay!")
rideSummaryView.setRewards(rewardDicts, animated: true)

