//
//  AppDelegate.swift
//  MultiCrap
//
//  Created by Helge Heß on 1/30/15.
//  Copyright (c) 2015 Always Right Institute. All rights reserved.
//

import Cocoa
import Quartz // for ImageKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  
  
  // MARK: Dealing with the folder, all that should go someplace else

  var folderMonitor : FolderMonitor?
  
  var pixPath : String? {
    willSet {
      if let fm = folderMonitor {
        fm.cancel()
        folderMonitor = nil
      }
    }
    didSet {
      if let pixPath = self.pixPath {
        folderMonitor = FolderMonitor(pixPath) {
          [unowned self] in
          self.loadFileList()
          self.tv.reloadData()
        }
        folderMonitor!.start()
      }
      loadFileList()
    }
  }
  
  let cropPath = "/tmp/" // FIXME: make this user-settable (file selector)
  
  var pixURL : NSURL? {
    return pixPath != nil
      ? NSURL(fileURLWithPath: pixPath!, isDirectory: true)
      : nil
  }
  var cropURL : NSURL? {
    return NSURL(fileURLWithPath: cropPath, isDirectory: true)
  }

  
  // MARK: Outlets and such
  
  @IBOutlet weak var window:       NSWindow!
  @IBOutlet weak var tv:           MyDropTableView!
  @IBOutlet weak var imageView:    IKImageView!
  @IBOutlet weak var sizeField:    NSTextField!
  @IBOutlet weak var liveCheckbox: NSButton!
  
  var targetSize : NSSize {
    return NSSize(width: sizeField.integerValue, height: sizeField.integerValue)
  }
  var isLive : Bool {
    get { return liveCheckbox.state == NSOnState }
    set { liveCheckbox.state = newValue ? NSOnState : NSOffState }
  }
  
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    /* set path from drop operation */
    
    tv.onDrop { [unowned self] in
      self.pixPath = $0
    }
    
    /* configure ImageKit view */
    
    imageView.doubleClickOpensImageEditPanel = true
    imageView.currentToolMode                = IKToolModeSelectRect
    imageView.editable                       = false
    
    /* configure picture taker */
    
    for key in [
      IKPictureTakerAllowsFileChoosingKey,
      IKPictureTakerAllowsVideoCaptureKey,
      IKPictureTakerUpdateRecentPictureKey,
      IKPictureTakerShowAddressBookPictureKey
    ]
    {
      pictaker.setValue(false, forKey: key);
    }
    pictaker.setValue(NSValue(size: targetSize),
                      forKey: IKPictureTakerOutputImageMaxSizeKey)
  }
  
  
  // MARK: IKImageView stuff, not really used for operations

  let ZOOM_IN_FACTOR  : CGFloat = 1.414214
  let ZOOM_OUT_FACTOR : CGFloat = 0.7071068
  
  @IBAction func zoom(sender: NSSegmentedControl) {
    switch (sender.selectedSegment) {
    case 0: imageView.zoomFactor = imageView.zoomFactor * ZOOM_OUT_FACTOR
    case 1: imageView.zoomFactor = imageView.zoomFactor * ZOOM_IN_FACTOR
    case 2: imageView.zoomImageToActualSize(self)
    case 3: imageView.zoomImageToFit(self)
    default:
      break;
    }
  }
  
  @IBAction func tool(sender: NSSegmentedControl) {
    switch (sender.selectedSegment) {
    case 0: imageView.currentToolMode = IKToolModeMove;
    case 1: imageView.currentToolMode = IKToolModeSelect;
    case 2: imageView.currentToolMode = IKToolModeCrop;
    case 3: imageView.currentToolMode = IKToolModeRotate;
    case 4: imageView.currentToolMode = IKToolModeAnnotate;
    default: break
    }
  }
  
  
  // MARK: IKPictureTaker code
  
  @IBAction func takePicture(sender: NSButton?) {
    pictaker.setValue(NSValue(size: targetSize),
                      forKey: IKPictureTakerOutputImageMaxSizeKey)
    
    pictaker.beginPictureTakerSheetForWindow(
      window, withDelegate: self,
      didEndSelector: "pictureTakerDidEnd:returnCode:contextInfo:",
      contextInfo: nil
    )
  }
  
  func pictureTakerDidEnd(sender: IKPictureTaker, returnCode rc: Int,
                          contextInfo: UnsafeMutablePointer<Void>)
  {
    if (rc == NSCancelButton) {
      println("Cancelled ...")
      isLive = false
      return
    }
    
    let croppedImage = pictaker.outputImage()
    println("did take pic: \(croppedImage)");
    
    if isLive {
      let url     = selectedURL!
      let oldName = url.lastPathComponent!.stringByDeletingPathExtension
      
      let tiffData = croppedImage.TIFFRepresentation!
      let imageRep = NSBitmapImageRep(data: tiffData)!
      let jpegData = imageRep.representationUsingType(
        .NSJPEGFileType,
        properties:  [ NSImageCompressionFactor : 1.0 ]
      )!
      
      let suffix  = "-\(imageRep.pixelsWide)x\(imageRep.pixelsHigh)"
      let newName = oldName + suffix + ".jpeg"
      
      let newURL = NSURL(string: newName, relativeToURL: cropURL)!
      println("save image to: \(newURL.path!)")
      
      jpegData.writeToURL(newURL, atomically: false)
    }
    
    tv.selectNextRow()
    
    dispatch_async(dispatch_get_main_queue(), {
      [unowned self] in
      self.takePicture(nil)
    })
  }
  
  
  // MARK: Misc

  /* can't live in extension - crap! (no stored properties) */
  var imageFiles : [ NSURL ] = []
  
  let pictaker = IKPictureTaker()
}


extension AppDelegate { /* image handling */
  
  var excludePrefix : String? { return "." }
  var filterPrefix  : String? { return nil } // e.g. "IMG_"
  
  func loadFileList() {
    if let pixURL = self.pixURL {
      let fm    = NSFileManager.defaultManager()
      var error : NSError?
      
      let contents = fm.contentsOfDirectoryAtURL(
        pixURL,  includingPropertiesForKeys: nil,
        options: NSDirectoryEnumerationOptions(),
        error:   &error
      ) as! [ NSURL ]
      
      imageFiles = contents
        .filter {
          self.excludePrefix != nil
            ? !$0.lastPathComponent!.hasPrefix(self.excludePrefix!)
            : true
        }
        .filter { // Note: hasPrefix("") returns false?
          self.filterPrefix != nil
            ? $0.lastPathComponent!.hasPrefix(self.filterPrefix!)
            : true
        }
        .sorted { $0.path! < $1.path! }
    }
    else {
      imageFiles = []
    }
    
    tv.reloadData()
  }
  
  var selectedURL : NSURL? {
    let row = tv.selectedRow
    if row < 0 { return nil }
    return imageFiles[row]
  }
}


extension AppDelegate : NSTableViewDataSource {
  
  func numberOfRowsInTableView(tableView: NSTableView) -> Int {
    return imageFiles.count
  }
  
  func tableView(tv: NSTableView,
                 objectValueForTableColumn c: NSTableColumn?,
                 row: Int) -> AnyObject?
  {
    let url = imageFiles[row]
    return url.lastPathComponent!
  }
}


extension AppDelegate : NSTableViewDelegate {
 
  func tableViewSelectionDidChange(aNotification: NSNotification) {
    let url = selectedURL!
    
    println("selection: \(url)")
    imageView.setImageWithURL(url)
    window.setTitleWithRepresentedFilename(url.lastPathComponent!)
    
    let img = NSImage(byReferencingURL: url)
    pictaker.setInputImage(img)
  }
}
