//
//  BalloonMarker.swift
//  ChartsDemo
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import Charts
import SwiftyJSON

open class BalloonMarker: MarkerImage
{
    open var color: UIColor = UIColor.darkGray
    open var arrowSize = CGSize(width: 15, height: 11)
    open var strokeWidth: CGFloat = 2
    open var cornerRadius: CGFloat = 10
    open var strokeColor: UIColor = UIColor.darkGray
    open var valuesFont: UIFont = UIFont.boldSystemFont(ofSize: 18)
    open var font: UIFont = UIFont.systemFont(ofSize: 18)
    open var textColor: UIColor = UIColor.white
    open var insets = UIEdgeInsets()
    open var minimumSize = CGSize()
    
    private var dateFormatter : DateFormatter!
    private var yearDateFormatter : DateFormatter!
    
    fileprivate var labelns: NSMutableAttributedString = NSMutableAttributedString()
    fileprivate var _paragraphStyle: NSMutableParagraphStyle!
    
    public init(chartView: ChartViewBase, dateFormat: String, color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets)
    {
        super.init()
        
        self.chartView = chartView
        
        self.color = color
        self.font = font
        self.textColor = textColor
        self.insets = insets
        
        _paragraphStyle = NSMutableParagraphStyle()
        _paragraphStyle.lineHeightMultiple = 1.2
        _paragraphStyle.alignment = .center
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = dateFormat
        
        self.yearDateFormatter = DateFormatter()
        self.yearDateFormatter.locale = Locale.current
        self.yearDateFormatter.dateFormat = dateFormat + " ''yy"
    }
    
    open override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint
    {
        
        let size = self.size
        var point = point
        point.x -= size.width / 2.0
        point.y -= size.height
     
        return super.offsetForDrawing(atPoint: point)
    }
    
    open override func draw(context: CGContext, point: CGPoint)
    {
        let offset = self.offsetForDrawing(atPoint: point)
        let size = self.size
        
        var rect = CGRect(
            origin: CGPoint(
                x: point.x + offset.x,
                y: point.y + offset.y),
            size: size)
        rect.origin.x -= size.width / 2.0
        
        
        var smallerRect: CGRect!
        var arrowPoint: CGPoint!
        var tipPt: CGPoint!
        var endPt: CGPoint!
        
        if (offset.y <= 0) {
            // Arrow points towards bottom.
            rect.origin.y -= size.height
            
            smallerRect = CGRect(x: rect.origin.x + strokeWidth, y: rect.origin.y + strokeWidth, width: rect.size.width - 2*strokeWidth, height: rect.size.height - arrowSize.height - 2*strokeWidth)
            
            arrowPoint = CGPoint(x: rect.origin.x + (size.width - arrowSize.width)/2 - offset.x, y: rect.origin.y + rect.size.height - arrowSize.height - 2*strokeWidth)
            
            let halfArrowWidth = arrowSize.width / 2.0
            tipPt = CGPoint(x: arrowPoint.x + halfArrowWidth, y: arrowPoint.y + arrowSize.height + strokeWidth)
            endPt = CGPoint(x: arrowPoint.x + arrowSize.width, y: arrowPoint.y)
        } else {
            // Arrow points towards top.
            rect.origin.y = point.y
            smallerRect = CGRect(x: rect.origin.x + strokeWidth, y: rect.origin.y + strokeWidth + arrowSize.height, width: rect.size.width - 2*strokeWidth, height: rect.size.height - arrowSize.height - 2*strokeWidth)
            
            arrowPoint = CGPoint(x: rect.origin.x + (size.width - arrowSize.width)/2 - offset.x, y: rect.origin.y + arrowSize.height + 2*strokeWidth)
            
            let halfArrowWidth = arrowSize.width / 2.0
            tipPt = CGPoint(x: arrowPoint.x + halfArrowWidth, y: arrowPoint.y - arrowSize.height - strokeWidth)
            endPt = CGPoint(x: arrowPoint.x + arrowSize.width, y: arrowPoint.y)
        }
        
        let path = UIBezierPath(roundedRect: smallerRect, cornerRadius: cornerRadius)
        
        color.setFill()
        strokeColor.setStroke()
        
        path.lineWidth = strokeWidth
        path.stroke()
        
        let arrowPath = UIBezierPath()
        
        arrowPath.move(to: arrowPoint)
        arrowPath.addLine(to: tipPt)
        arrowPath.addLine(to: endPt)
        arrowPath.lineCapStyle = CGLineCap.butt
        
        arrowPath.lineWidth = strokeWidth
        arrowPath.stroke()
        
        path.fill(with: CGBlendMode.clear, alpha:1.0)
        path.fill()
        
        arrowPath.fill()
        
        smallerRect.origin.y += self.insets.top
        smallerRect.origin.x += self.insets.left
        smallerRect.size.width -= self.insets.left + self.insets.right
        smallerRect.size.height -= self.insets.top + self.insets.bottom
        
        UIGraphicsPushContext(context)
        
        labelns.draw(in: smallerRect)
        
        UIGraphicsPopContext()
    }
    
    private func dateAsString(date: Date)->String {
        if (date.isToday()) {
            return "Today"
        } else if (date.isYesterday()) {
            return "Yesterday"
        } else if (date.isInLastWeek()) {
            return date.weekDay()
        } else if (date.isThisYear()) {
            return self.dateFormatter.string(from: date)
        } else {
            return self.yearDateFormatter.string(from: date)
        }
    }
    
    open override func refreshContent(entry: ChartDataEntry, highlight: Highlight)
    {
        labelns = NSMutableAttributedString(string: "")
        
        let valueAttributes: [String: Any] = [NSForegroundColorAttributeName: self.textColor, NSFontAttributeName: self.valuesFont, NSParagraphStyleAttributeName: _paragraphStyle]
        let unitAttributes: [String: Any] = [NSForegroundColorAttributeName: self.textColor, NSFontAttributeName: self.font, NSParagraphStyleAttributeName: _paragraphStyle]
        
        let data = JSON(entry.data as? Any)
        if let weatherEmoji = data["weather_emoji"].string{
            labelns.append(NSAttributedString(string: weatherEmoji + " ", attributes: unitAttributes))
        }
        
        if let dateString = data["date"].string, let date = Date.dateFromJSONString(dateString) {
            labelns.append(NSAttributedString(string: dateAsString(date: date), attributes: valueAttributes))
        }
        
        labelns.append(NSAttributedString(string: "\n", attributes: valueAttributes))
        
        if let num = data["rides"].int {
            let numString = num == 0 ? "no" : String(num)
            labelns.append(NSAttributedString(string: numString, attributes: valueAttributes))
            labelns.append(NSAttributedString(string: " ", attributes: valueAttributes))
            labelns.append(NSAttributedString(string: num == 1 ? "ride" : "rides", attributes: unitAttributes))
        }
        
        if let meters = data["meters"].float, meters > 0 {
            let components = meters.distanceString(suppressFractionalUnits: true).components(separatedBy: " ")
            if components.count == 2 {
                labelns.append(NSAttributedString(string: "\n", attributes: valueAttributes))
                labelns.append(NSAttributedString(string: components[0], attributes: valueAttributes))
                labelns.append(NSAttributedString(string: " ", attributes: valueAttributes))
                labelns.append(NSAttributedString(string: components[1], attributes: unitAttributes))
            }
        }
        
        let labelSize = labelns.size()
        
        var size = CGSize()
        size.width = labelSize.width + self.insets.left + self.insets.right + 2*strokeWidth
        size.height = labelSize.height + self.insets.top + self.insets.bottom + arrowSize.height + 2*strokeWidth + 4 // i don't know why the 4 is needed, but otherwise it won't draw both lines
        size.width = max(minimumSize.width, size.width)
        size.height = max(minimumSize.height, size.height)
        self.size = size
    }
}
