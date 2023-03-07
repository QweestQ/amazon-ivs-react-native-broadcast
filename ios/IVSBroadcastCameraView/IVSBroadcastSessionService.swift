import AmazonIVSBroadcast
import AVFoundation

typealias onReceiveCameraPreviewHandler = (_: IVSImagePreviewView) -> Void

enum BuiltInCameraUrns: String {
  case backUltraWideCamera = "camera:com.apple.avfoundation.avcapturedevice.built-in_video:5"
  case backCamera = "camera:com.apple.avfoundation.avcapturedevice.built-in_video:0"
  case frontCamera = "camera:com.apple.avfoundation.avcapturedevice.built-in_video:1"
}

// Guide: https://docs.aws.amazon.com/ivs/latest/userguide//broadcast-ios.html
class IVSBroadcastSessionService: NSObject {
  private var isInitialMuted: Bool = false
  private var initialSessionLogLevel: IVSBroadcastSession.LogLevel = .error
  private var isCameraPreviewMirrored: Bool = false
  private var cameraPreviewAspectMode: IVSBroadcastConfiguration.AspectMode = .none
  private var customVideoConfig: NSDictionary?
  private var customAudioConfig: NSDictionary?
  
  private var broadcastSession: IVSBroadcastSession?
  private var config = IVSBroadcastConfiguration()
  private var cameraSlot: IVSMixerSlotConfiguration!
  private var attachedCamera: IVSDevice?
  private var overlayConfig: [NSDictionary]?
  private var slotSources: Dictionary<String, IVSCustomImageSource> = [:]
  
  private var onBroadcastError: RCTDirectEventBlock?
  private var onBroadcastAudioStats: RCTDirectEventBlock?
  private var onBroadcastStateChanged: RCTDirectEventBlock?
  @available(*, message: "@Deprecated in favor of onTransmissionStatisticsChanged method.")
  private var onBroadcastQualityChanged: RCTDirectEventBlock?
  @available(*, message: "@Deprecated in favor of onTransmissionStatisticsChanged method.")
  private var onNetworkHealthChanged: RCTDirectEventBlock?
  private var onTransmissionStatisticsChanged: RCTDirectEventBlock?
  
  private func getLogLevel(_ logLevelName: NSString) -> IVSBroadcastSession.LogLevel {
    switch logLevelName {
    case "debug":
      return .debug
    case "error":
      return .error
    case "info":
      return .info
    case "warning":
      return .warn
    default:
      assertionFailure("Does not support log level: \(logLevelName)")
      return .error
    }
  }
  
  private func getAspectMode(_ aspectModeName: NSString) -> IVSBroadcastConfiguration.AspectMode {
    switch aspectModeName {
    case "fit":
      return .fit
    case "fill":
      return .fill
    case "none":
      return .none
    default:
      assertionFailure("Does not support aspect mode: \(aspectModeName)")
      return .fill
    }
  }
  
  private func getAudioSessionStrategy(_ audioSessionStrategyName: NSString) -> IVSBroadcastSession.AudioSessionStrategy {
    switch audioSessionStrategyName {
    case "recordOnly":
      return .recordOnly
    case "playAndRecord":
      return .playAndRecord
    case "playAndRecordDefaultToSpeaker":
      return .playAndRecordDefaultToSpeaker
    case "noAction":
      return .noAction
    default:
      assertionFailure("Does not support audio session strategy: \(audioSessionStrategyName).")
      return .playAndRecord
    }
  }
  
  private func getAudioQuality(_ audioQualityName: NSString) -> IVSBroadcastConfiguration.AudioQuality {
    switch audioQualityName {
    case "minimum":
      return .minimum
    case "low":
      return .low
    case "medium":
      return .medium
    case "high":
      return .high
    case "maximum":
      return .maximum
    default:
      assertionFailure("Does not support audio quality: \(audioQualityName).")
      return .medium
    }
  }
  
  private func getAutomaticBitrateProfile(_ automaticBitrateProfileName: NSString) -> IVSVideoConfiguration.AutomaticBitrateProfile {
    switch automaticBitrateProfileName {
    case "conservative":
      return .conservative
    case "fastIncrease":
      return .fastIncrease
    default:
      assertionFailure("Does not support automatic bitrate profile: \(automaticBitrateProfileName).")
      return .conservative
    }
  }
  
  private func getConfigurationPreset(_ configurationPresetName: NSString) -> IVSBroadcastConfiguration {
    switch configurationPresetName {
    case "standardPortrait":
      return IVSPresets.configurations().standardPortrait()
    case "standardLandscape":
      return IVSPresets.configurations().standardLandscape()
    case "basicPortrait":
      return IVSPresets.configurations().basicPortrait()
    case "basicLandscape":
      return IVSPresets.configurations().basicLandscape()
    default:
      assertionFailure("Does not support configuration preset: \(configurationPresetName).")
      return IVSPresets.configurations().standardPortrait()
    }
  }
  
  private func getCameraPreview() -> IVSImagePreviewView? {
    let preview = try? self.broadcastSession?.previewView(with: self.cameraPreviewAspectMode)
    preview?.setMirrored(self.isCameraPreviewMirrored)
    return preview
  }
  
  private func setCustomVideoConfig() throws {
    guard let videoConfig = self.customVideoConfig else { return }
    
    let width = videoConfig["width"]
    let height = videoConfig["height"]
    if (width != nil || height != nil) {
      if (width != nil && height != nil) {
        try self.config.video.setSize(CGSize(width: width as! Int, height: height as! Int))
      } else {
        throw IVSBroadcastCameraViewError("[setCustomVideoConfig] The `width` and `height` are interrelated and thus can not be used separately.")
      }
    }
    
    if let bitrate = videoConfig["bitrate"] {
      try self.config.video.setInitialBitrate(bitrate as! Int)
    }
    if let targetFrameRate = videoConfig["targetFrameRate"] {
      try self.config.video.setTargetFramerate(targetFrameRate as! Int)
    }
    if let keyframeInterval = videoConfig["keyframeInterval"] {
      try self.config.video.setKeyframeInterval(Float(keyframeInterval as! Int))
    }
    if let isBFrames = videoConfig["isBFrames"] {
      self.config.video.usesBFrames = isBFrames as! Bool
    }
    if let isAutoBitrate = videoConfig["isAutoBitrate"] {
      self.config.video.useAutoBitrate = isAutoBitrate as! Bool
    }
    if let maxBitrate = videoConfig["maxBitrate"] {
      try self.config.video.setMaxBitrate(maxBitrate as! Int)
    }
    if let minBitrate = videoConfig["minBitrate"] {
      try self.config.video.setMinBitrate(minBitrate as! Int)
    }
    if let autoBitrateProfileName = videoConfig["autoBitrateProfile"] {
      let autoBitrateProfile = self.getAutomaticBitrateProfile(autoBitrateProfileName as! NSString)
      self.config.video.autoBitrateProfile = autoBitrateProfile
    }
  }
  
  private func setCustomAudioConfig() throws {
    guard let audioConfig = self.customAudioConfig else { return }
    
    if let audioBitrate = audioConfig["bitrate"] {
      try self.config.audio.setBitrate(audioBitrate as! Int)
    }
    if let channels = audioConfig["channels"] {
      try self.config.audio.setChannels(channels as! Int)
    }
    if let audioQualityName = audioConfig["quality"] {
      let audioQuality = self.getAudioQuality(audioQualityName as! NSString)
      self.config.audio.setQuality(audioQuality)
    }
    if let audioSessionStrategyName = audioConfig["audioSessionStrategy"] {
      IVSBroadcastSession.applicationAudioSessionStrategy = self.getAudioSessionStrategy(audioSessionStrategyName as! NSString)
    }
  }
  
  private func muteAsync(_ isMuted: Bool) {
    self.broadcastSession?.awaitDeviceChanges({ [weak self] in
      self?.broadcastSession?.listAttachedDevices()
        .filter({ $0.descriptor().type == .microphone || $0.descriptor().type == .userAudio })
        .forEach({
          if let microphone = $0 as? IVSAudioDevice {
            microphone.setGain(isMuted ? 0 : 1)
          }
        })
    })
  }
  
  private func attachCamera(urn: BuiltInCameraUrns) {
    IVSBroadcastSession.listAvailableDevices().forEach { print("urn: " + $0.urn) }
    guard let activeCamera = IVSBroadcastSession.listAvailableDevices().first(where: { $0.urn == urn.rawValue }) else { return }
    
    let onComplete: ((IVSDevice?, Error?) -> Void)? = { [weak self] device, error in
      if let error = error { print("❌ Error attaching/exchanging camera: \(error)") }
      self?.attachedCamera = device
    }
    
    if let attachedCamera = self.attachedCamera {
      self.broadcastSession?.exchangeOldDevice(attachedCamera, withNewDevice: activeCamera, onComplete: onComplete)
    } else {
      self.broadcastSession?.attach(activeCamera, toSlotWithName: self.cameraSlot.name, onComplete: onComplete)
    }
  }
  
  private func attachMicrophone() {
    guard let microphone = IVSBroadcastSession.listAvailableDevices().first(where: { $0.type == .microphone }) else {
      print("Cannot attach microphone - no available device with type microphone found")
      return
    }
    
    self.broadcastSession?.attach(microphone, toSlotWithName: cameraSlot.name, onComplete: { (device, error)  in
      if let error = error {
        print("❌ Error attaching device microphone to session: \(error)")
      }
      
      self.muteAsync(self.isInitialMuted)
    })
  }
  
  private func updateOverlaySlots() {
    guard let broadcastSession = self.broadcastSession,
          let overlayConfig = self.overlayConfig
    else { return }
    
    do {
      try overlayConfig.forEach { config in
        guard let name = config["name"] as? String,
              let uri = config["uri"] as? String
        else { return }
        
        // Create UIImage based on type of uri: http:// or file://
        var image: UIImage
        
        if let imageByFile = UIImage(contentsOfFile: uri) {
          image = imageByFile
        } else if uri.starts(with: "http") || uri.starts(with: "file") {
          guard let url = URL(string: uri),
                let data = NSData(contentsOf: url),
                let imageByUrl = UIImage(data: data as Data)
          else { return }
          
          image = imageByUrl
        } else { return }
        
        // Assign width and height of the slot based on provided values
        // or image size if nothing was provided
        let size = config["size"] as? NSDictionary
        let width = size?["width"] as? Int ?? Int(image.size.width)
        let height = size?["height"] as? Int ?? Int(image.size.height)
        
        // Assign position from provided values or to 0
        let position = config["position"] as? NSDictionary
        let x = position?["x"] as? Int ?? 0
        let y = position?["y"] as? Int ?? 0
        
        // Create slot mixer and add it to the session
        let slot = IVSMixerSlotConfiguration()
        slot.preferredVideoInput = .userImage
        slot.preferredAudioInput = .unknown
        slot.aspect = .fit
        slot.zIndex = 2
        slot.size = CGSize(width: width, height: height)
        slot.position = CGPoint(x: x, y: y)
        try slot.setName(name)
        
        broadcastSession.mixer.addSlot(slot)
        
        // Detach previous source from session if it was already existed
        if let source = self.slotSources[slot.name] {
          broadcastSession.detach(source) {
            self.slotSources[slot.name] = nil
          }
        }
        
        // Create image source and attach it to the mixer slot of the session
        let source = broadcastSession.createImageSource(withName: slot.name)
        broadcastSession.attach(source, toSlotWithName: slot.name) { _ in
          source.onSampleBuffer(image.cmSampleBuffer)
          self.slotSources[slot.name] = source
        }
      }
    } catch {
      print("Failed to update overlay slots")
      return
    }
  }
  
  private func preInitiation() throws {
    try self.setCustomVideoConfig()
    try self.setCustomAudioConfig()
  }
  
  private func postInitiation() {
    self.broadcastSession?.logLevel = self.initialSessionLogLevel
    
    if (self.isInitialMuted) {
      self.muteAsync(self.isInitialMuted)
    }
    
    self.attachCamera(urn: BuiltInCameraUrns.backCamera)
    self.attachMicrophone()
    self.updateOverlaySlots()
  }
  
  public func initiate() throws {
    if (!self.isInitialized()) {
      try self.preInitiation()
      
      cameraSlot = IVSMixerSlotConfiguration()
      cameraSlot.preferredVideoInput = .camera
      cameraSlot.preferredAudioInput = .microphone
      cameraSlot.zIndex = 1
      try cameraSlot.setName("camera")
      
      config.mixer.slots = [cameraSlot]
      config.video.enableTransparency = true
      
      self.broadcastSession = try IVSBroadcastSession(
        configuration: self.config,
        descriptors: nil,
        delegate: self
      )
      
      self.postInitiation()
    } else {
      assertionFailure("Broadcast session has been already initialized.")
    }
  }
  
  public func deinitiate() {
    self.broadcastSession?.stop()
    self.broadcastSession = nil
  }
  
  public func isInitialized() -> Bool {
    return self.broadcastSession != nil
  }
  
  public func isReady() -> Bool {
    guard let isReady = self.broadcastSession?.isReady else {
      return false
    }
    return isReady
  }
  
  public func start(ivsRTMPSUrl: NSString, ivsStreamKey: NSString) throws {
    guard let url = URL(string: ivsRTMPSUrl as String) else {
      throw IVSBroadcastCameraViewError("[start] Can not create a URL instance for: \(ivsRTMPSUrl)")
    }
    try self.broadcastSession?.start(with: url, streamKey: ivsStreamKey as String)
  }
  
  public func stop() {
    self.broadcastSession?.stop()
  }
  
  public func getCameraPreviewAsync(_ onReceiveCameraPreview: @escaping onReceiveCameraPreviewHandler) {
    self.broadcastSession?.awaitDeviceChanges { () -> Void in
      if let cameraPreview = self.getCameraPreview() {
        onReceiveCameraPreview(cameraPreview)
      }
    }
  }
  
  public func setCameraPreviewAspectMode(_ aspectMode: NSString?, _ onReceiveCameraPreview: @escaping onReceiveCameraPreviewHandler) {
    if let aspectModeName = aspectMode {
      self.cameraPreviewAspectMode = self.getAspectMode(aspectModeName)
      
      if (self.isInitialized()) {
        self.getCameraPreviewAsync(onReceiveCameraPreview)
      }
    }
  }
  
  public func setIsCameraPreviewMirrored(_ isMirrored: Bool, _ onReceiveCameraPreview: @escaping onReceiveCameraPreviewHandler) {
    self.isCameraPreviewMirrored = isMirrored
    
    if (self.isInitialized()) {
      self.getCameraPreviewAsync(onReceiveCameraPreview)
    }
  }
  
  public func setIsMuted(_ isMuted: Bool) {
    if (self.isInitialized()) {
      self.muteAsync(isMuted)
    } else {
      self.isInitialMuted = isMuted
    }
  }
  
  public func setZoom(_ zoom: CGFloat) {
    var camera: AVCaptureDevice?
    var zoom = zoom
    
    // Support of 0.5x...1x zoom
    if #available(iOS 13.0, *), zoom >= 0.5, zoom < 1 {
      if self.attachedCamera?.descriptor().urn == BuiltInCameraUrns.backCamera.rawValue {
        self.attachCamera(urn: BuiltInCameraUrns.backUltraWideCamera)
      }
      
      zoom += 0.5
      camera = AVCaptureDevice.default(
        .builtInUltraWideCamera,
        for: .video,
        position: .back
      )
    } else if zoom >= 1 {
      if self.attachedCamera?.descriptor().urn == BuiltInCameraUrns.backUltraWideCamera.rawValue {
        self.attachCamera(urn: BuiltInCameraUrns.backCamera)
      }
      
      camera = AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: .back
      )
    }
    
    do {
      try camera?.lockForConfiguration()
    } catch {
      return
    }
    
    camera?.ramp(toVideoZoomFactor: zoom, withRate: 5)
  }
  
  public func setSessionLogLevel(_ logLevel: NSString?) {
    if let logLevelName = logLevel {
      let sessionLogLevel = self.getLogLevel(logLevelName)
      
      if (self.isInitialized()) {
        self.broadcastSession?.logLevel = sessionLogLevel
      } else {
        self.initialSessionLogLevel = sessionLogLevel
      }
    }
  }
  
  public func setLogLevel(_ logLevel: NSString?) {
    if let logLevelName = logLevel {
      self.config.logLevel = self.getLogLevel(logLevelName)
    }
  }
  
  public func setConfigurationPreset(_ configurationPreset: NSString?) {
    if let configurationPresetName = configurationPreset {
      self.config = self.getConfigurationPreset(configurationPresetName)
    }
  }
  
  public func setVideoConfig(_ videoConfig: NSDictionary?) {
    self.customVideoConfig = videoConfig
  }
  
  public func setAudioConfig(_ audioConfig: NSDictionary?) {
    self.customAudioConfig = audioConfig
  }
  
  public func setOverlayConfig(_ overlayConfig: [NSDictionary]?) {
    self.overlayConfig = overlayConfig
    self.updateOverlaySlots()
  }
  
  public func setBroadcastStateChangedHandler(_ onBroadcastStateChangedHandler: RCTDirectEventBlock?) {
    self.onBroadcastStateChanged = onBroadcastStateChangedHandler
  }
  
  public func setBroadcastErrorHandler(_ onBroadcastErrorHandler: RCTDirectEventBlock?) {
    self.onBroadcastError = onBroadcastErrorHandler
  }
  
  public func setBroadcastAudioStatsHandler(_ onBroadcastAudioStatsHandler: RCTDirectEventBlock?) {
    self.onBroadcastAudioStats = onBroadcastAudioStatsHandler
  }
  
  @available(*, message: "@Deprecated in favor of setTransmissionStatisticsChangedHandler method.")
  public func setBroadcastQualityChangedHandler(_ onBroadcastQualityChangedHandler: RCTDirectEventBlock?) {
    self.onBroadcastQualityChanged = onBroadcastQualityChangedHandler
  }
  
  @available(*, message: "@Deprecated in favor of setTransmissionStatisticsChangedHandler method.")
  public func setNetworkHealthChangedHandler(_ onNetworkHealthChangedHandler: RCTDirectEventBlock?) {
    self.onNetworkHealthChanged = onNetworkHealthChangedHandler
  }
  
  public func setTransmissionStatisticsChangedHandler(_ onTransmissionStatisticsChangedHandler: RCTDirectEventBlock?) {
    self.onTransmissionStatisticsChanged = onTransmissionStatisticsChangedHandler
  }
}

extension IVSBroadcastSessionService: IVSBroadcastSession.Delegate {
  func broadcastSession(_ session: IVSBroadcastSession, transmissionStatisticsChanged statistics: IVSTransmissionStatistics) {
    self.onTransmissionStatisticsChanged?([
      "statistics": [
        "rtt": statistics.rtt,
        "measuredBitrate": statistics.measuredBitrate,
        "recommendedBitrate": statistics.recommendedBitrate,
        "networkHealth": statistics.networkHealth.rawValue,
        "broadcastQuality": statistics.broadcastQuality.rawValue,
      ]
    ])
    
  }
  
  func broadcastSession(_ session: IVSBroadcastSession, didChange state: IVSBroadcastSession.State) {
    var eventPayload = ["stateStatus": state.rawValue] as [AnyHashable : Any]
    
    if (state == .connected) {
      eventPayload["metadata"] = ["sessionId": session.sessionId]
    }
    
    self.onBroadcastStateChanged?(eventPayload)
  }
  
  func broadcastSession(_ session: IVSBroadcastSession, networkHealthChanged health: Double) {
    self.onNetworkHealthChanged?(["networkHealth": health])
  }
  
  func broadcastSession(_ session: IVSBroadcastSession, broadcastQualityChanged quality: Double) {
    self.onBroadcastQualityChanged?(["quality": quality])
  }
  
  func broadcastSession(_ session: IVSBroadcastSession, audioStatsUpdatedWithPeak peak: Double, rms: Double) {
    self.onBroadcastAudioStats?([
      "audioStats": ["peak": peak, "rms": rms]
    ])
  }
  
  func broadcastSession(_ session: IVSBroadcastSession, didEmitError error: Error) {
    if let onBroadcastError = self.onBroadcastError {
      let userInfo = (error as NSError).userInfo
      let IVSBroadcastSourceDescription = userInfo["IVSBroadcastSourceDescription"]
      let IVSBroadcastErrorIsFatalKey = userInfo["IVSBroadcastErrorIsFatalKey"]
      
      onBroadcastError([
        "exception": [
          "code": (error as NSError).code,
          "type": (error as NSError).domain,
          "detail": error.localizedDescription,
          "source": IVSBroadcastSourceDescription,
          "isFatal": IVSBroadcastErrorIsFatalKey,
          "sessionId": session.sessionId,
        ]
      ])
    }
  }
}

extension UIImage {
  var cvPixelBuffer: CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer? = nil
    let options = [
      kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
      kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
      kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
    ] as CFDictionary
    
    CVPixelBufferCreate(kCFAllocatorDefault,
                        Int(size.width),
                        Int(size.height),
                        kCVPixelFormatType_32BGRA,
                        options as CFDictionary,
                        &pixelBuffer)
    
    guard let pb = pixelBuffer else {
      print("⚠️⚠️ Couldn't create pixel buffer ⚠️⚠️")
      return nil
    }
    
    let context = CIContext(options: [.workingColorSpace: NSNull()])
    
    guard let cgImage = self.cgImage else {
      print("⚠️⚠️ Couldn't load bundled image assets ⚠️⚠️")
      return nil
    }
    
    let ciImage = CIImage(cgImage: cgImage)
    context.render(ciImage, to: pb)
    
    return pb
  }
  
  var cmSampleBuffer: CMSampleBuffer {
    let pixelBuffer = cvPixelBuffer
    var sampleBuffer: CMSampleBuffer? = nil
    var formatDesc: CMFormatDescription? = nil
    var timimgInfo: CMSampleTimingInfo = CMSampleTimingInfo.invalid
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: pixelBuffer!,
                                                 formatDescriptionOut: &formatDesc)
    
    CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                             imageBuffer: cvPixelBuffer!,
                                             formatDescription: formatDesc!,
                                             sampleTiming: &timimgInfo,
                                             sampleBufferOut: &sampleBuffer)
    
    return sampleBuffer!
  }
}
