//: Playground - noun: a place where people can play
import UIKit
import PlaygroundSupport

let rideSummaryView = RideSummaryView(frame: CGRect(x: 0, y: 0, width: 500, height: 10))

let view = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
view.backgroundColor = UIColor.white
view.addSubview(rideSummaryView)
PlaygroundPage.current.liveView = view
