//
//  FolderMonitor.swift
//  MultiCrap
//
//  Created by Helge Heß on 1/30/15.
//  Copyright (c) 2015 Always Right Institute. All rights reserved.
//

import Foundation

class FolderMonitor {
  
  var mq  : dispatch_queue_t?
  var fd  : CInt?
  var src : dispatch_source_t?
  
  var cb  : ( ) -> Void
  
  init(_ pixPath: String, _ cb: ( ) -> Void) {
    self.cb = cb
    
    fd  = open(pixPath.fileSystemRepresentation(), O_EVTONLY)
    
    mq  = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    
    src = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, UInt(fd!),
                                 DISPATCH_VNODE_WRITE, mq)
    
    dispatch_source_set_event_handler(src!) {
      [unowned self] in
      
      dispatch_async(dispatch_get_main_queue()) { // retain cycle?
        cb()
      }
    }
    
    dispatch_source_set_cancel_handler(src!) {
      [unowned self] in
      if let fd = self.fd {
        close(fd)
        self.fd = nil
      }
    }
  }
  deinit {
    cancel()
  }
  
  func start() {
    dispatch_resume(src!)
  }
  
  func cancel() {
    if let src = src {
      dispatch_source_cancel(src)
      self.src = nil
    }
  }
}