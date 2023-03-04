# **API**

### Reference documentation

👉 [iOS SDK](https://aws.github.io/amazon-ivs-broadcast-docs/1.7.1/ios/)

👉 [Android SDK](https://aws.github.io/amazon-ivs-broadcast-docs/1.7.2/android/reference/com/amazonaws/ivs/broadcast/package-summary.html)

## `IVSBroadcastCameraView` component

### 📌 _**Props**_

#### `style`

Style of `IVSBroadcastCameraView` component.

|          Type          | Required |   Platform   |
| :--------------------: | :------: | :----------: |
| `StyleProp<ViewStyle>` |    No    | iOS, Android |

#### `testID`

Used to locate `IVSBroadcastCameraView` component in the end-to-end tests.

|   Type   | Required |   Platform   |
| :------: | :------: | :----------: |
| `string` |    No    | iOS, Android |

#### `rtmpsUrl`

The RTMPS endpoint provided by IVS.

|   Type   | Required |   Platform   |
| :------: | :------: | :----------: |
| `string` |    No    | iOS, Android |

The RTMPS url can be also provided via [`start`](./api-documentation.md#start) method.

#### `streamKey`

The broadcaster’s stream key that has been provided by IVS.

|   Type   | Required |   Platform   |
| :------: | :------: | :----------: |
| `string` |    No    | iOS, Android |

The stream key can be also provided via [`start`](./api-documentation.md#start) method.

#### `configurationPreset`

Predefined video configuration for broadcast session. Can be overridden by providing [`videoConfig`](./api-documentation.md#videoconfig) prop.

|                          Type                           | Required |   Platform   |
| :-----------------------------------------------------: | :------: | :----------: |
| [`ConfigurationPreset`](./types.md#configurationpreset) |    No    | iOS, Android |

#### `videoConfig`

A configuration object describing the desired format of the final output Video stream.

|                   Type                    | Required |
| :---------------------------------------: | :------: |
| [`IVideoConfig`](./types.md#ivideoconfig) |    No    |

⚠️ _Changing any properties on this object after providing it to `IVSBroadcastCameraView` component will not have any effect. A copy of the configuration is made and kept internally._

_**Default video config unless [`configurationPreset`](./api-documentation.md#configurationpreset) is provided:**_

|         Key          |     Value      |   Platform   |
| :------------------: | :------------: | :----------: |
|       `width`        |     `720`      | iOS, Android |
|       `height`       |     `1280`     | iOS, Android |
|      `bitrate`       |   `2100000`    | iOS, Android |
|  `targetFrameRate`   |      `30`      | iOS, Android |
|  `keyframeInterval`  |      `2`       | iOS, Android |
|     `isBFrames`      |     `true`     | iOS, Android |
|   `isAutoBitrate`    |     `true`     | iOS, Android |
| `autoBitrateProfile` | `conservative` | iOS, Android |
|     `maxBitrate`     |   `6000000`    | iOS, Android |
|     `minBitrate`     |    `300000`    | iOS, Android |

#### `audioConfig`

A configuration object describing the desired format of the final output Audio stream.

|                   Type                    | Required |
| :---------------------------------------: | :------: |
| [`IAudioConfig`](./types.md#iaudioconfig) |    No    |

⚠️ _Changing any properties on this object after providing it to `IVSBroadcastCameraView` component will not have any effect. A copy of the configuration is made and kept internally._

⚠️ _Default sample rate is 48 Khz and can not be changed (it is best to match production audio flow)._

_**Default audio config:**_

|          Key           |      Value      |   Platform   |
| :--------------------: | :-------------: | :----------: |
|       `bitrate`        |     `96000`     | iOS, Android |
|       `channels`       |       `2`       | iOS, Android |
| `audioSessionStrategy` | `playAndRecord` |     iOS      |
|       `quality`        |    `medium`     |     iOS      |

#### `logLevel`

In order to catch logs at a more granular level than `Error` during the initialization process, use this property instead of the [`sessionLogLevel`](#sessionloglevel).

|               Type                | Required |   Platform   | Default value |
| :-------------------------------: | :------: | :----------: | :-----------: |
| [`LogLevel`](./types.md#loglevel) |    No    | iOS, Android |    `error`    |

#### `sessionLogLevel`

Logging level for the broadcast session.

|               Type                | Required |   Platform   | Default value |
| :-------------------------------: | :------: | :----------: | :-----------: |
| [`LogLevel`](./types.md#loglevel) |    No    | iOS, Android |    `error`    |

#### `cameraPreviewAspectMode`

Determines how view's aspect ratio will be maintained.

|                              Type                               | Required |   Platform   | Default value |
| :-------------------------------------------------------------: | :------: | :----------: | :-----------: |
| [`CameraPreviewAspectMode`](./types.md#camerapreviewaspectmode) |    No    | iOS, Android |    `none`     |

#### `isCameraPreviewMirrored`

Flips the camera preview horizontally.

|   Type    | Required |   Platform   | Default value |
| :-------: | :------: | :----------: | :-----------: |
| `boolean` |    No    | iOS, Android |    `false`    |

#### `isMuted`

Puts the active microphone on mute.

|   Type    | Required |   Platform   | Default value |
| :-------: | :------: | :----------: | :-----------: |
| `boolean` |    No    | iOS, Android |    `false`    |

⚠️ _Muting does not detach a microphone from session but only adjusts the gain which means that device will still receive all the real audio samples. By putting the microphone on mute - the `peak` and `rms` values of [`IAudioStats`](./types.md#iaudiostats) are equal to `-100`._

### 📌 _**Handlers**_

#### `onError`

Indicates that module' internal error occurred.

|                 Type                  | Required |   Platform   |
| :-----------------------------------: | :------: | :----------: |
| `onError(errorMessage: string): void` |    No    | iOS, Android |

#### `onBroadcastError`

Indicates that broadcast session error occurred. Errors may or may not be fatal. In the case of a fatal error the broadcast session moves into `DISCONNECTED` [state status](./types.md#statestatusunion).

|                                               Type                                               | Required |   Platform   |
| :----------------------------------------------------------------------------------------------: | :------: | :----------: |
| `onBroadcastError(error: `[`IBroadcastSessionError`](./types.md#ibroadcastsessionerror)`): void` |    No    | iOS, Android |

#### `onIsBroadcastReady`

Fires(**once**) when initialization(including adding camera preview to the view hierarchy) is done.

|                     Type                     | Required |   Platform   |
| :------------------------------------------: | :------: | :----------: |
| `onIsBroadcastReady(isReady: boolean): void` |    No    | iOS, Android |

#### `onBroadcastAudioStats`

Periodically called with audio `peak` and `rms` in `dBFS`.

|                                         Type                                         | Required |   Platform   |
| :----------------------------------------------------------------------------------: | :------: | :----------: |
| `onBroadcastAudioStats(audioStats: `[`IAudioStats`](./types.md#iaudiostats)`): void` |    No    | iOS, Android |

⚠️ _Expect this callback to be triggered quite frequently._

#### `onBroadcastStateChanged`

Indicates that the broadcast state changed.

|                                                                                   Type                                                                                    | Required |   Platform   |
| :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :------: | :----------: |
| `onBroadcastStateChanged(stateStatus: `[`StateStatusUnion`](./types.md#statestatusunion)`, metadata?: `[`StateChangedMetadata`](./types.md#statechangedmetadata)`): void` |    No    | iOS, Android |

⚠️ _As of now, the metadata is available with `CONNECTED` state status only._

#### `onTransmissionStatisticsChanged`

Periodically called with current statistics on the broadcast, such as the measured bitrate, recommended bitrate by the SDK's adaptive bitrate algorithm, average round trip time, broadcast quality (relative to configured minimum and maximum bitrates), and network health.

|                                                                Type                                                                | Required |   Platform   |
| :--------------------------------------------------------------------------------------------------------------------------------: | :------: | :----------: |
| `onTransmissionStatisticsChanged(transmissionStatistics: `[`ITransmissionStatistics`](./types.md#itransmissionstatistics)`): void` |    No    | iOS, Android |

⚠️ _Expect this callback to be triggered quite frequently (approximately twice per second) as the measured and recommended bitrates change._

#### `onBroadcastQualityChanged`

🚧 **DEPRECATED** in favor of [`onTransmissionStatisticsChanged`](./api-documentation.md#ontransmissionstatisticschanged) event handler.

Represents the quality of the stream.

|                        Type                        | Required |   Platform   |
| :------------------------------------------------: | :------: | :----------: |
| `onBroadcastQualityChanged(quality: number): void` |    No    | iOS, Android |

`quality` is a number between `0` and `1` that represents the quality of the stream based on minimum and maximum bitrate provided in the [`videoConfig`](#videoconfig). `0` means the stream is at the lowest possible quality, or streaming is not possible at all. `1` means the bitrate is near the maximum allowed.

#### `onNetworkHealthChanged`

🚧 **DEPRECATED** in favor of [`onTransmissionStatisticsChanged`](./api-documentation.md#ontransmissionstatisticschanged) event handler.

Provides updates when the instantaneous quality of the network changes. It can be used to provide feedback about when the broadcast might have temporary disruptions.

|                         Type                          | Required |   Platform   |
| :---------------------------------------------------: | :------: | :----------: |
| `onNetworkHealthChanged(networkHealth: number): void` |    No    | iOS, Android |

`networkHealth` is a number between `0` and `1` that represents the current health of the network. `0` means the network is struggling to keep up and the broadcast may be experiencing latency spikes. The SDK may also reduce the quality of the broadcast on low values in order to keep it stable, depending on the minimum allowed bitrate in the [`videoConfig`](#videoconfig). A value of `1` means the network is easily able to keep up with the current demand and the SDK will be trying to increase the broadcast quality over time, depending on the maximum allowed bitrate. Lower values like `0.5` are not necessarily bad, it just means the network is being saturated, but it is still able to keep up.

#### `onAudioSessionInterrupted`

Indicates that audio session has been interrupted.

|                Type                 | Required | Platform |
| :---------------------------------: | :------: | :------: |
| `onAudioSessionInterrupted(): void` |    No    |   iOS    |

⚠️ _There are several scenarios where the SDK may not have exclusive access to audio-input hardware. Some example scenarios that should be handled are:_

- _User receives a phone call or FaceTime call_
- _User activates Siri_

#### `onAudioSessionResumed`

Indicates that audio session has been resumed (after interrupted).

|              Type               | Required | Platform |
| :-----------------------------: | :------: | :------: |
| `onAudioSessionResumed(): void` |    No    |   iOS    |

#### `onMediaServicesWereLost`

> _In very rare cases, the entire media subsystem on an iOS device will crash. In this scenario, the SDK can no longer broadcast._

Indicates that the media server services are terminated.
Respond by stopping and completely deallocating broadcast session. All internal components used by the broadcast session will be invalidated.

|               Type                | Required | Platform |
| :-------------------------------: | :------: | :------: |
| `onMediaServicesWereLost(): void` |    No    |   iOS    |

#### `onMediaServicesWereReset`

Indicates that the media server services are reset.
Respond by notifying consumers that they can broadcast again. Depending on the case, you may be able to automatically start broadcasting again at this point.

|                Type                | Required | Platform |
| :--------------------------------: | :------: | :------: |
| `onMediaServicesWereReset(): void` |    No    |   iOS    |

### 📌 _**Methods**_

#### `start`

Start the configured broadcast session.

|                                    Type                                     | Required |   Platform   |
| :-------------------------------------------------------------------------: | :------: | :----------: |
| `(options?: `[`StartMethodOptions`](./types.md#startmethodoptions)`): void` |    No    | iOS, Android |

⚠️ _The `rtmpsUrl` and `streamKey` which are passed to the `start` method take precedence over the equivalent component props._

#### `stop`

Stop the broadcast session, but do not deallocate resources.

|    Type    | Required |   Platform   |
| :--------: | :------: | :----------: |
| `(): void` |    No    | iOS, Android |

⚠️ _Stopping the stream happens asynchronously while the SDK attempts to gracefully end the broadcast. Observe state changes to know when a new stream could be started._

