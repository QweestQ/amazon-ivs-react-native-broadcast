package com.amazonivsreactnativebroadcast.IVSBroadcastCameraView;

import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.util.Log;
import android.view.Surface;

import com.amazonaws.ivs.broadcast.*;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraSelector;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.LifecycleOwner;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.uimanager.ThemedReactContext;
import com.google.common.util.concurrent.ListenableFuture;

import java.io.InputStream;
import java.net.URL;
import java.util.HashMap;
import java.util.Objects;
import java.util.concurrent.ExecutionException;

@FunctionalInterface
interface CameraPreviewHandler {
  void run(ImagePreviewView cameraPreview);
}

@FunctionalInterface
interface RunnableCallback {
  void run(IVSBroadcastSessionService.Events event, @Nullable WritableMap eventPayload);
}

// Guide: https://docs.aws.amazon.com/ivs/latest/userguide//broadcast-android.html
public class IVSBroadcastSessionService {
  private final ThemedReactContext mReactContext;

  private boolean isInitialMuted = false;
  private BroadcastConfiguration.LogLevel initialSessionLogLevel = BroadcastConfiguration.LogLevel.ERROR;
  private boolean isCameraPreviewMirrored = false;
  private BroadcastConfiguration.AspectMode cameraPreviewAspectMode = BroadcastConfiguration.AspectMode.NONE;
  private ReadableMap customVideoConfig;
  private ReadableMap customAudioConfig;

  private String sessionId;
  private BroadcastSession broadcastSession;
  private BroadcastConfiguration config = new BroadcastConfiguration();

  private ReadableArray overlayConfig;
  private BroadcastConfiguration.Mixer.Slot cameraSlot;
  private final HashMap<String, SurfaceSource> slotSources = new HashMap<>();
  private Device attachedCamera;

  private RunnableCallback broadcastEventHandler;
  private final BroadcastSession.Listener broadcastSessionListener = new BroadcastSession.Listener() {
    @Override
    public void onError(@NonNull BroadcastException exception) {
      int code = exception.getCode();
      String detail = exception.getDetail();
      String source = exception.getSource();
      boolean isFatal = exception.isFatal();
      String type = exception.getError().name();

      WritableMap eventPayload = Arguments.createMap();
      WritableMap broadcastException = Arguments.createMap();

      broadcastException.putInt("code", code);
      broadcastException.putString("detail", detail);
      broadcastException.putString("source", source);
      broadcastException.putBoolean("isFatal", isFatal);
      broadcastException.putString("type", type);
      broadcastException.putString("sessionId", sessionId);

      eventPayload.putMap("exception", broadcastException);

      broadcastEventHandler.run(Events.ON_ERROR, eventPayload);
    }

    @Override
    public void onStateChanged(@NonNull BroadcastSession.State state) {
      WritableMap eventPayload = Arguments.createMap();
      eventPayload.putString("stateStatus", state.toString());

      if (state == BroadcastSession.State.CONNECTED) {
        WritableMap metadata = Arguments.createMap();
        metadata.putString("sessionId", sessionId);
        eventPayload.putMap("metadata", metadata);
      }

      broadcastEventHandler.run(Events.ON_STATE_CHANGED, eventPayload);
    }

    @Override
    public void onAudioStats(double peak, double rms) {
      WritableMap eventPayload = Arguments.createMap();
      WritableMap audioStats = Arguments.createMap();

      audioStats.putDouble("peak", peak);
      audioStats.putDouble("rms", rms);

      eventPayload.putMap("audioStats", audioStats);

      broadcastEventHandler.run(Events.ON_AUDIO_STATS, eventPayload);
    }

    @Override
    public void onTransmissionStatsChanged(@NonNull TransmissionStats statistics) {
      WritableMap statisticsPayload = Arguments.createMap();
      statisticsPayload.putDouble("rtt", statistics.roundTripTime);
      statisticsPayload.putDouble("measuredBitrate", statistics.measuredBitrate);
      statisticsPayload.putDouble("recommendedBitrate", statistics.recommendedBitrate);
      statisticsPayload.putString("networkHealth", statistics.networkHealth.name());
      statisticsPayload.putString("broadcastQuality", statistics.broadcastQuality.name());

      WritableMap eventPayload = Arguments.createMap();
      eventPayload.putMap("statistics", statisticsPayload);

      broadcastEventHandler.run(Events.ON_TRANSMISSION_STATISTICS_CHANGED, eventPayload);
    }

  };

  private BroadcastConfiguration.LogLevel getLogLevel(String logLevelName) {
    switch (logLevelName) {
      case "debug": {
        return BroadcastConfiguration.LogLevel.DEBUG;
      }
      case "error": {
        return BroadcastConfiguration.LogLevel.ERROR;
      }
      case "info": {
        return BroadcastConfiguration.LogLevel.INFO;
      }
      case "warning": {
        return BroadcastConfiguration.LogLevel.WARNING;
      }
      default: {
        throw new RuntimeException("Does not support log level: " + logLevelName);
      }
    }
  }

  private BroadcastConfiguration.AspectMode getAspectMode(String aspectModeName) {
    switch (aspectModeName) {
      case "fit": {
        return BroadcastConfiguration.AspectMode.FIT;
      }
      case "fill": {
        return BroadcastConfiguration.AspectMode.FILL;
      }
      case "none": {
        return BroadcastConfiguration.AspectMode.NONE;
      }
      default: {
        throw new RuntimeException("Does not support aspect mode: " + aspectModeName);
      }
    }
  }

  private BroadcastConfiguration getConfigurationPreset(String configurationPresetName) {
    switch (configurationPresetName) {
      case "standardPortrait": {
        return Presets.Configuration.STANDARD_PORTRAIT;
      }
      case "standardLandscape": {
        return Presets.Configuration.STANDARD_LANDSCAPE;
      }
      case "basicPortrait": {
        return Presets.Configuration.BASIC_PORTRAIT;
      }
      case "basicLandscape": {
        return Presets.Configuration.BASIC_LANDSCAPE;
      }
      default: {
        throw new RuntimeException("Does not support configuration preset: " + configurationPresetName);
      }
    }
  }

  private BroadcastConfiguration.AutomaticBitrateProfile getAutomaticBitrateProfile(String automaticBitrateProfileName) {
    switch (automaticBitrateProfileName) {
      case "conservative": {
        return BroadcastConfiguration.AutomaticBitrateProfile.CONSERVATIVE;
      }
      case "fastIncrease": {
        return BroadcastConfiguration.AutomaticBitrateProfile.FAST_INCREASE;
      }
      default: {
        throw new RuntimeException("Does not support automatic bitrate profile: " + automaticBitrateProfileName);
      }
    }
  }

  private ImagePreviewView getCameraPreview() {
    ImagePreviewView preview = broadcastSession.getPreviewView(cameraPreviewAspectMode);
    preview.setMirrored(isCameraPreviewMirrored);
    return preview;
  }

  private void setCustomVideoConfig() {
    if (customVideoConfig != null) {
      config = config.changing($ -> {
        boolean isWidth = customVideoConfig.hasKey("width");
        boolean isHeight = customVideoConfig.hasKey("height");
        if (isWidth || isHeight) {
          if (isWidth && isHeight) {
            $.video.setSize(
              customVideoConfig.getInt("width"),
              customVideoConfig.getInt("height")
            );
          } else {
            throw new RuntimeException("The `width` and `height` are interrelated and thus can not be used separately.");
          }
        }

        if (customVideoConfig.hasKey("bitrate")) {
          $.video.setInitialBitrate(customVideoConfig.getInt("bitrate"));
        }
        if (customVideoConfig.hasKey("targetFrameRate")) {
          $.video.setTargetFramerate(customVideoConfig.getInt("targetFrameRate"));
        }
        if (customVideoConfig.hasKey("keyframeInterval")) {
          $.video.setKeyframeInterval(customVideoConfig.getInt("keyframeInterval"));
        }
        if (customVideoConfig.hasKey("isBFrames")) {
          $.video.setUseBFrames(customVideoConfig.getBoolean("isBFrames"));
        }
        if (customVideoConfig.hasKey("isAutoBitrate")) {
          $.video.setUseAutoBitrate(customVideoConfig.getBoolean("isAutoBitrate"));
        }
        if (customVideoConfig.hasKey("maxBitrate")) {
          $.video.setMaxBitrate(customVideoConfig.getInt("maxBitrate"));
        }
        if (customVideoConfig.hasKey("minBitrate")) {
          $.video.setMinBitrate(customVideoConfig.getInt("minBitrate"));
        }
        if (customVideoConfig.hasKey("autoBitrateProfile")) {
          String autoBitrateProfileName = customVideoConfig.getString("autoBitrateProfile");
          BroadcastConfiguration.AutomaticBitrateProfile autoBitrateProfile = getAutomaticBitrateProfile(autoBitrateProfileName);
          $.video.setAutoBitrateProfile(autoBitrateProfile);
        }

        return $;
      });
    }
  }

  private void setCustomAudioConfig() {
    if (customAudioConfig != null) {
      config = config.changing($ -> {
        if (customAudioConfig.hasKey("bitrate")) {
          $.audio.setBitrate(customAudioConfig.getInt("bitrate"));
        }
        if (customAudioConfig.hasKey("channels")) {
          $.audio.setChannels(customAudioConfig.getInt("channels"));
        }
        return $;
      });
    }
  }

  private void muteAsync(boolean isMuted) {
    broadcastSession.awaitDeviceChanges(() -> {
      for (Device device : broadcastSession.listAttachedDevices()) {

        Device.Descriptor deviceDescriptor = device.getDescriptor();

        if (deviceDescriptor.type == Device.Descriptor.DeviceType.MICROPHONE) {
          Float gain = isMuted ? 0.0F : 1.0F;
          ((AudioDevice) device).setGain(gain);
          break;
        }
      }
    });
  }

  private void attachCamera() {
    if (!isInitialized()) {
      return;
    }

    for(Device.Descriptor desc: BroadcastSession.listAvailableDevices(mReactContext)) {
      if(desc.type == Device.Descriptor.DeviceType.CAMERA &&
        desc.position == Device.Descriptor.Position.BACK) {

        TypedLambda<Device> onComplete = device -> {
          // Bind the camera device to the camera mixer slot.
          if (broadcastSession != null) {
            broadcastSession.getMixer().bind(device, cameraSlot.getName());
            attachedCamera = device;
          }
        };

        if (attachedCamera != null) {
          broadcastSession.exchangeDevices(attachedCamera, desc, onComplete);
        } else {
          broadcastSession.attachDevice(desc, onComplete);
        }

        break;
      }
    }
  }

  private void attachMicrophone() {
    if (!isInitialized()) {
      return;
    }

    for(Device.Descriptor desc: BroadcastSession.listAvailableDevices(mReactContext)) {
      if(desc.type == Device.Descriptor.DeviceType.MICROPHONE) {

        TypedLambda<Device> onComplete = device -> {
          // Bind the microphone device to the camera mixer slot.
          if (broadcastSession != null) {
            broadcastSession.getMixer().bind(device, cameraSlot.getName());
            muteAsync(isInitialMuted);
          }
        };

        broadcastSession.attachDevice(desc, onComplete);

        break;
      }
    }
  }

  private Bitmap getBitmapFromURL(String src) {
    try {
      InputStream stream = new URL(src).openStream();
      return BitmapFactory.decodeStream(stream);
    } catch (Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  private void removeOverlaySlot(String name) {
    Device slotSource = slotSources.get(name);
    if (slotSource == null) {
      return;
    }

    broadcastSession.getMixer().unbind(slotSource);
    broadcastSession.detachDevice(slotSource);
    broadcastSession.getMixer().removeSlot(name);
    slotSources.remove(name);
  }

  private void updateOverlaySlots() {
    if (!isInitialized() || overlayConfig == null) {
      return;
    }

    for (String sourceName : slotSources.keySet()) {
      removeOverlaySlot(sourceName);
    }

    for (int i = 0; i < overlayConfig.size(); i++) {
      ReadableMap config = overlayConfig.getMap(i);

      // Skip this config map if the name or image uri were not provided
      if (!config.hasKey("name") || !config.hasKey("uri")) {
        continue;
      }

      // Create slot based on config values in a separate thread
      try {
        String name = config.getString("name");
        String uri = config.getString("uri");

        // Get bitmap image from provided uri - http:// or file://
        Bitmap image = getBitmapFromURL(uri);

        if (image == null) {
          return;
        }

        // Assign width and height of the slot based on provided values
        // or image size if nothing was provided
        ReadableMap size = config.getMap("size");
        int width = size == null ? image.getWidth() : (int)size.getDouble("width");
        int height = size == null ? image.getHeight() : (int)size.getDouble("height");

        // Assign position from provided values or 0
        ReadableMap position = config.getMap("position");
        float x = position == null ? 0 : (float)position.getDouble("x");
        float y = position == null ? 0 : (float)position.getDouble("y");

        // Create and add slot from config values
        BroadcastConfiguration.Mixer.Slot slot = BroadcastConfiguration.Mixer.Slot.with(it -> {
          it.setPreferredVideoInput(Device.Descriptor.DeviceType.USER_IMAGE);
          it.setPreferredAudioInput(Device.Descriptor.DeviceType.UNKNOWN);
          it.setAspect(BroadcastConfiguration.AspectMode.FIT);
          it.setzIndex(2);
          it.setSize(width, height);
          it.setPosition(new BroadcastConfiguration.Vec2(x, y));
          it.setName(name);

          return it;
        });
        broadcastSession.getMixer().addSlot(slot);

        // Create SurfaceSource source with computed size
        SurfaceSource surfaceSource = broadcastSession.createImageInputSource();
        surfaceSource.setSize(image.getWidth(), image.getHeight());

        // Get Surface from SurfaceSource and draw bitmap image to it
        Surface surface = surfaceSource.getInputSurface();
        Canvas canvas = surface.lockCanvas(null);
        canvas.drawBitmap(image, 0f, 0f, null);
        surface.unlockCanvasAndPost(canvas);

        // Bind SurfaceSource to the slot
        broadcastSession.awaitDeviceChanges(() -> {
          broadcastSession.getMixer().bind(surfaceSource, slot.getName());
          slotSources.put(name, surfaceSource);
        });
      } catch (Exception e) {
        Log.e("updateOverlaySlots", e.toString());
        e.printStackTrace();
      }
    }
  }

  private void preInitialization() {
    setCustomVideoConfig();
    setCustomAudioConfig();
  }

  private void postInitialization() {
    broadcastSession.setLogLevel(initialSessionLogLevel);
    attachCamera();
    attachMicrophone();
    updateOverlaySlots();
  }

  public enum Events {
    ON_ERROR("onError"),
    ON_STATE_CHANGED("onStateChanged"),
    ON_AUDIO_STATS("onAudioStats"),
    ON_TRANSMISSION_STATISTICS_CHANGED("onTransmissionStatisticsChanged"),
    @Deprecated
    ON_QUALITY_CHANGED("onQualityChanged"),
    @Deprecated
    ON_NETWORK_HEALTH_CHANGED("onNetworkHealthChanged");

    private String title;

    Events(String title) {
      this.title = title;
    }

    @Override
    public String toString() {
      return title;
    }
  }

  public IVSBroadcastSessionService(ThemedReactContext reactContext) {
    mReactContext = reactContext;
  }

  public void init() {
    if (isInitialized()) {
      throw new RuntimeException("Broadcast session has been already initialized.");
    } else {
      preInitialization();

      cameraSlot = BroadcastConfiguration.Mixer.Slot.with(it -> {
        it.setzIndex(1);
        it.setPreferredVideoInput(Device.Descriptor.DeviceType.CAMERA);
        it.setPreferredAudioInput(Device.Descriptor.DeviceType.MICROPHONE);
        it.setName("camera");

        return it;
      });

      config.mixer.slots = new BroadcastConfiguration.Mixer.Slot[] { cameraSlot };
      config.video.enableTransparency(true);

      broadcastSession = new BroadcastSession(
        mReactContext,
        broadcastSessionListener,
        config,
        null
      );

      postInitialization();
    }
  }

  public void deinit() {
    if (isInitialized()) {
      broadcastSession.release();
      broadcastSession = null;
    }
  }

  public boolean isInitialized() {
    return broadcastSession != null;
  }

  public boolean isReady() {
    return broadcastSession.isReady();
  }

  public void start(@Nullable String ivsRTMPSUrl, @Nullable String ivsStreamKey) {
    broadcastSession.start(ivsRTMPSUrl, ivsStreamKey);
    sessionId = broadcastSession.getSessionId();
  }

  public void stop() {
    broadcastSession.stop();
  }

  public void getCameraPreviewAsync(CameraPreviewHandler callback) {
    broadcastSession.awaitDeviceChanges(() -> {
      callback.run(getCameraPreview());
    });
  }

  public void setCameraPreviewAspectMode(String cameraPreviewAspectModeName, CameraPreviewHandler callback) {
    cameraPreviewAspectMode = getAspectMode(cameraPreviewAspectModeName);
    if (isInitialized()) {
      getCameraPreviewAsync(callback);
    }
  }

  public void setIsCameraPreviewMirrored(boolean isPreviewMirrored, CameraPreviewHandler callback) {
    isCameraPreviewMirrored = isPreviewMirrored;
    if (isInitialized()) {
      getCameraPreviewAsync(callback);
    }
  }

  public void setIsMuted(boolean isMuted) {
    if (isInitialized()) {
      muteAsync(isMuted);
    } else {
      isInitialMuted = isMuted;
    }
  }

  public void setZoom(float zoom) {
    if (!isInitialized() || zoom < 1) {
      return;
    }

    CameraSource cameraSource = (CameraSource) attachedCamera;

    if (cameraSource == null) {
      return;
    }

    CameraSource.Capabilities capabilities = cameraSource.getCapabilities();
    if (!capabilities.isZoomSupported()) {
      return;
    }

    CameraSource.Options options = new CameraSource.Options.Builder()
      .setZoomFactor(zoom)
      .build();

    cameraSource.setOptions(options);
  }

  public void setSessionLogLevel(String sessionLogLevelName) {
    BroadcastConfiguration.LogLevel sessionLogLevel = getLogLevel(sessionLogLevelName);
    if (isInitialized()) {
      broadcastSession.setLogLevel(sessionLogLevel);
    } else {
      initialSessionLogLevel = sessionLogLevel;
    }
  }

  public void setLogLevel(String logLevel) {
    config = config.changing($ -> {
      $.logLevel = getLogLevel(logLevel);
      return $;
    });
  }

  public void setConfigurationPreset(String configurationPreset) {
    config = getConfigurationPreset(configurationPreset);
  }

  public void setVideoConfig(ReadableMap videoConfig) {
    customVideoConfig = videoConfig;
  }

  public void setAudioConfig(ReadableMap audioConfig) {
    customAudioConfig = audioConfig;
  }

  public void setOverlayConfig(ReadableArray overlayConfig) {
    this.overlayConfig = overlayConfig;
    updateOverlaySlots();
  }

  public void setEventHandler(RunnableCallback handler) {
    broadcastEventHandler = handler;
  }
}
