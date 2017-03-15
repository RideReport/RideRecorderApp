//
//  NSString+HBAdditions.swift
//  Ride
//
//  Created by William Henderson on 2/12/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

extension Character {
    func isUnsupportedEmoji() -> Bool {
        let chars = Array(String(self).utf16)
        let size = chars.count
        let font = UIFont(name: "AppleColorEmoji", size: 64)!
        var glyphs = Array<CGGlyph>(repeating: 0, count: size)
        let supported = CTFontGetGlyphsForCharacters(font, chars, &glyphs, size)
        
        return !supported
    }
}

extension String {
    func containsUnsupportEmoji()->Bool {
        for c in self.characters {
            if (c.isUnsupportedEmoji()) {
                return true
            }
        }
        
        return false
    }
    
    func stringByRemovingUnsupportedEmoji() -> String {
        return String(self.characters.filter(){ (char) -> Bool in
            return !char.isUnsupportedEmoji()
        })
    }
}
