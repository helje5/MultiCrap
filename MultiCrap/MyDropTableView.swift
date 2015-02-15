//
//  MyDropTableView.swift
//  MultiCrap
//
//  Created by Helge Heß on 1/30/15.
//  Copyright (c) 2015 Always Right Institute. All rights reserved.
//

import Cocoa

class MyDropTableView: NSTableView {
  
  let fm = NSFileManager.defaultManager()
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    
    registerForDraggedTypes([ NSFilenamesPboardType ])
  }
  
  var highlightColor : NSColor? {
    didSet {
      if highlightColor != oldValue {
        needsDisplay = true
      }
    }
  }
  
  
  // MARK: Callback
  
  var onDropCB : (( String ) -> Void)?
  
  func onDrop(cb: ( String ) -> Void) {
    onDropCB = cb
  }
  
  
  // MARK: Drag operations
  
  override func performDragOperation(sender: NSDraggingInfo) -> Bool {
    println("perform called: \(sender)")
    
    if let cb = onDropCB, path = dirPathFromDraggingData(sender) {
      cb(path)
    }
    return true
  }
  
  override func prepareForDragOperation(sender: NSDraggingInfo) -> Bool {
    return hasAcceptableDraggingData(sender)
  }
  
  
  // MARK: Dragging Data

  func hasAcceptableDraggingData(draggingInfo: NSDraggingInfo) -> Bool {
    return dirPathFromDraggingData(draggingInfo) != nil
  }
  
  func dirPathFromDraggingData(draggingInfo: NSDraggingInfo) -> String? {
    let fn    = filenameFromDraggingInfo(draggingInfo)
    var isDir : ObjCBool = false
    
    if fn == nil {
      return nil
    }
    
    if !fm.fileExistsAtPath(fn!, isDirectory: &isDir) {
      return nil
    }
    if !isDir { // Note: fails on directory aliases.
      return nil
    }
    
    return fn
  }
  
  func filenameFromDraggingInfo(draggingInfo: NSDraggingInfo) -> String? {
    let pb        = draggingInfo.draggingPasteboard()
    var filenames = pb.propertyListForType(NSFilenamesPboardType) as! [ String ]
    
    if filenames.count < 1 {
      return nil
    }
    
    return filenames[0]
  }

  
  // MARK: Handle Highlighting
  
  override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
    let dataOK = hasAcceptableDraggingData(sender)
    highlightColor = dataOK ? NSColor.greenColor() : NSColor.redColor()
    return NSDragOperation.Copy
  }
  override func draggingExited(sender: NSDraggingInfo?) {
    highlightColor = nil
  }
  
  override func draggingUpdated(sender: NSDraggingInfo) -> NSDragOperation {
    return self.draggingEntered(sender)
  }
  
  override func draggingEnded(sender: NSDraggingInfo?) {
    draggingExited(sender)
  }
  
  
  // MARK: Draw Highlighting
  
  override func drawRect(dirtyRect: NSRect) {
    super.drawRect(dirtyRect)
    
    if highlightColor != nil { // weird, replace me ;-)
      highlightColor!.set()
      NSBezierPath.setDefaultLineWidth(18)
      NSBezierPath.strokeRect(bounds)
    }
  }
}
