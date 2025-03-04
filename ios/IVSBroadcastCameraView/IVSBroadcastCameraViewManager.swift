import Foundation

@objc (RCTIVSBroadcastCameraView)
class IVSBroadcastCameraViewManager: RCTViewManager {
  
  override func view() -> UIView! {
    return IVSBroadcastCameraView()
  }
  
  override static func requiresMainQueueSetup() -> Bool {
    return true
  }
  
  // Static methods
  @objc public func START(_ node: NSNumber, options: NSDictionary) {
    DispatchQueue.main.async {
      let component = self.bridge.uiManager.view(forReactTag: node) as! IVSBroadcastCameraView
      component.start(options)
    }
  }
  
  @objc public func FOCUS(_ node: NSNumber, point: NSDictionary) {
    DispatchQueue.main.async {
      let component = self.bridge.uiManager.view(forReactTag: node) as! IVSBroadcastCameraView
      component.focus(point)
    }
  }
  
  @objc public func STOP(_ node: NSNumber) {
    DispatchQueue.main.async {
      let component = self.bridge.uiManager.view(forReactTag: node) as! IVSBroadcastCameraView
      component.stop()
    }
  }
}

