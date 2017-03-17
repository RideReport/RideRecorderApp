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

open class BalloonMarker: MarkerImage
{
    open var color: UIColor = UIColor.darkGray
    open var arrowSize = CGSize(width: 15, height: 11)
    open var strokeWidth: CGFloat = 2
    open var cornerRadius: CGFloat = 10
    open var strokeColor: UIColor = UIColor.darkGray
    open var font: UIFont = UIFont.systemFont(ofSize: 18)
    open var unitsFont: UIFont = UIFont.boldSystemFont(ofSize: 18)
    open var textColor: UIColor = UIColor.white
    open var insets = UIEdgeInsets()
    open var minimumSize = CGSize()
    
    private var dateFormatter : DateFormatter!
    private var yearDateFormatter : DateFormatter!
    
    fileprivate var labelns: NSMutableAttributedString = NSMutableAttributedString()
    fileprivate var _paragraphStyle: NSMutableParagraphStyle!
    
    public init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets)
    {
        super.init()
        
        self.color = color
        self.font = font
        self.textColor = textColor
        self.insets = insets
        
        _paragraphStyle = NSMutableParagraphStyle()
        _paragraphStyle.lineHeightMultiple = 1.2
        _paragraphStyle.alignment = .left
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale.current
        self.dateFormatter.dateFormat = "MMM"
        
        self.yearDateFormatter = DateFormatter()
        self.yearDateFormatter.locale = Locale.current
        self.yearDateFormatter.dateFormat = "MMM ''yy"
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
        rect.origin.y -= size.height
        
        let smallerPath = CGRect(x: rect.origin.x + strokeWidth, y: rect.origin.y + strokeWidth, width: rect.size.width - 2*strokeWidth, height: rect.size.height - arrowSize.height - 2*strokeWidth)
        
        let path = UIBezierPath(roundedRect: smallerPath, cornerRadius: cornerRadius)
        
        color.setFill()
        strokeColor.setStroke()
        
        path.lineWidth = strokeWidth
        path.stroke()
        
        if arrowSize.height > 0 && arrowSize.width > 0 {
            let arrowPoint = CGPoint(x: rect.origin.x + (size.width - arrowSize.width)/2, y: rect.origin.y + rect.size.height - arrowSize.height - strokeWidth)
            let arrowPath = UIBezierPath()
            
            let halfArrowWidth = arrowSize.width / 2.0
            let tipPt = CGPoint(x: arrowPoint.x + halfArrowWidth, y: arrowPoint.y + arrowSize.height)
            let endPt = CGPoint(x: arrowPoint.x + arrowSize.width, y: arrowPoint.y)
            
            // Note: we always build the arrow path in a clockwise direction.
            // Arrow points towards top. We're starting from the left.
            
            arrowPath.move(to: arrowPoint)
            arrowPath.addLine(to: tipPt)
            arrowPath.addLine(to: endPt)
            arrowPath.lineCapStyle = CGLineCap.butt
            
            arrowPath.lineWidth = strokeWidth
            arrowPath.stroke()
            arrowPath.fill(with: CGBlendMode.clear, alpha:1.0)
            arrowPath.fill()
        }
        
        path.fill(with: CGBlendMode.clear, alpha:1.0)
        path.fill()
        
        rect.origin.y += self.insets.top
        rect.origin.x += self.insets.left
        rect.size.width -= self.insets.left + self.insets.right
        rect.size.height -= self.insets.top + self.insets.bottom
        
        UIGraphicsPushContext(context)
        
        labelns.draw(in: rect)
        
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
        
        let valueAttributes: [String: Any] = [NSForegroundColorAttributeName: self.textColor, NSFontAttributeName: self.font, NSParagraphStyleAttributeName: _paragraphStyle]
        let unitAttributes: [String: Any] = [NSForegroundColorAttributeName: self.textColor, NSFontAttributeName: self.unitsFont, NSParagraphStyleAttributeName: _paragraphStyle]
        
        var i = 0
        if let data = entry.data as? Dictionary<String, AnyObject> {
            for (key, value) in data {
                if let num = value as? NSNumber {
                    let numString = num.stringValue
                    labelns.append(NSAttributedString(string: numString, attributes: valueAttributes))
                    labelns.append(NSAttributedString(string: " ", attributes: valueAttributes))
                    labelns.append(NSAttributedString(string: key, attributes: unitAttributes))
                    if i < (data.count - 1) {
                        labelns.append(NSAttributedString(string: "\n", attributes: unitAttributes))
                    }
                } else if let date = value as? Date, key == "date" {
                    let dateString = NSAttributedString(string: dateAsString(date: date) + "\n", attributes: unitAttributes)
                    labelns.insert(dateString, at: 0)
                }
                i+=1
            }
        }
        
        let labelSize = labelns.size()
        
        var size = CGSize()
        size.width = labelSize.width + self.insets.left + self.insets.right
        size.height = labelSize.height + self.insets.top + self.insets.bottom + arrowSize.height
        size.width = max(minimumSize.width, size.width)
        size.height = max(minimumSize.height, size.height)
        self.size = size
    }
}
