//
//  NSImage.swift
//  SwiftOCR Training
//
//  Created by Omer Emre Aslan on 10.07.2018.
//  Copyright © 2018 Nicolas Camenisch. All rights reserved.
//

import Cocoa

extension NSImage {
    var PNGRepresentation: Data? {
        if let tiff = self.tiffRepresentation, let tiffData = NSBitmapImageRep(data: tiff) {
            return tiffData.representation(using: .png, properties: [:])
        }
        
        return nil
    }
    
    func resizeImage(width: CGFloat, _ height: CGFloat) -> NSImage {
        let destSize = NSMakeSize(width, height)
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        NSColor.white.drawSwatch(in: NSMakeRect(0, 0, destSize.width, destSize.height))
        self.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height),
                  from: NSMakeRect(0, 0, self.size.width, self.size.height),
                  operation: NSCompositingOperation.sourceOver,
                  fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = destSize
        return NSImage(data: newImage.tiffRepresentation!)!
    }
    
    func addPadding(_ padding: CGFloat, withColor color: NSColor) -> NSImage {
        var maximumDimension: CGFloat
        var minimumDimension: CGFloat
        var topPadding: CGFloat
        var leftPadding: CGFloat
        
        if size.height > size.width {
            maximumDimension = size.height
            minimumDimension = size.width
            topPadding = padding
            leftPadding = (maximumDimension - minimumDimension) / 2 + padding
        } else {
            maximumDimension = size.width
            minimumDimension = size.height
            leftPadding = padding
            topPadding = (maximumDimension - minimumDimension) / 2 + padding
        }
        
        
        let destSize = NSMakeSize(maximumDimension + padding * 2,
                                  maximumDimension + padding * 2)
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        color.drawSwatch(in: NSMakeRect(0, 0, destSize.width, destSize.height))
        self.draw(in: NSMakeRect(leftPadding, topPadding, destSize.width, destSize.height),
                  from: NSMakeRect(0, 0, destSize.width, destSize.width),
                  operation: NSCompositingOperation.sourceOver,
                  fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = destSize
        return NSImage(data: newImage.tiffRepresentation!)!
    }
    
    func savePngTo(url: URL) throws {
        if let png = self.PNGRepresentation {
            do {
                try png.write(to: url, options: .atomicWrite)
            } catch {
                print("File save error")
            }
        }
    }
}

