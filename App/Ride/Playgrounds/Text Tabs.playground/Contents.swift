//: Playground - noun: a place where people can play

import UIKit
import SpriteKit
import XCPlayground


let emojis = "👍 👎 🙌 🌂 🍄 🌤 🌧 ⛄️ 💧 🚴 🚲 🚀 🌈 🌠 🎉 ❤️ 💙 💜 💚 💛 📢 🎖 🏅 🏆 🎗 💫 🍁 🎩 👻 👒".componentsSeparatedByString(" ")

var rewardString = ""

let paragraphStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
paragraphStyle.lineHeightMultiple = 1.2

let text1  = UILabel(frame: CGRectMake(0,0,720,88))
text1.font = UIFont.systemFontOfSize(14)
text1.backgroundColor = UIColor.whiteColor()
text1.numberOfLines = 9
text1.lineBreakMode = NSLineBreakMode.ByWordWrapping

let emojiWidth = ("👍" as NSString).sizeWithAttributes([NSFontAttributeName: text1.font]).width
let crossWidth = ("x" as NSString).sizeWithAttributes([NSFontAttributeName: text1.font]).width
let countWidth = ("99" as NSString).sizeWithAttributes([NSFontAttributeName: text1.font]).width
let columnSeperatorWidth : CGFloat = 10
let totalWidth = emojiWidth + crossWidth + countWidth + columnSeperatorWidth

var tabStops : [NSTextTab] = []
var totalLineWidth : CGFloat = 0
var columnCount = 0
while totalLineWidth + totalWidth < text1.frame.size.width {
    tabStops.append(NSTextTab(textAlignment: NSTextAlignment.Center, location: totalLineWidth + emojiWidth , options: [NSTabColumnTerminatorsAttributeName:NSCharacterSet(charactersInString:"x")]))
    tabStops.append(NSTextTab(textAlignment: NSTextAlignment.Right, location: totalLineWidth + emojiWidth + crossWidth + countWidth, options: [:]))
    tabStops.append(NSTextTab(textAlignment: NSTextAlignment.Left, location: totalLineWidth + emojiWidth + crossWidth + countWidth + columnSeperatorWidth, options: [:]))
    totalLineWidth += totalWidth
    columnCount++
    print(String(totalLineWidth))
}

paragraphStyle.tabStops = tabStops

var i = 0
for emoji in emojis {
    rewardString += emoji + "×\t" + String(arc4random_uniform(200) + 1)  + "\t"
    i++
    if i>=columnCount {
        i = 0
        rewardString += "\n"
    }
}

let attrString = NSMutableAttributedString(string: rewardString)
attrString.addAttribute(NSParagraphStyleAttributeName, value:paragraphStyle, range:NSMakeRange(0, attrString.length))

text1.attributedText = attrString


XCPlaygroundPage.currentPage.liveView = text1


