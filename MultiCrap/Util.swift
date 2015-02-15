//
//  Util.swift
//  MultiCrap
//
//  Created by Helge Heß on 1/30/15.
//  Copyright (c) 2015 Always Right Institute. All rights reserved.
//

import Cocoa

extension NSTableView {
  
  func selectNextRow() -> Bool {
    let row     = self.selectedRow
    var nextRow : Int
    
    if row < 0 {
      nextRow = 0
    }
    else if row + 1 >= self.numberOfRows {
      return false
    }
    else {
      nextRow = row + 1
    }
    
    self.selectRowIndexes(NSIndexSet(index: nextRow),
                          byExtendingSelection: false);
    return true
  }
  
}
