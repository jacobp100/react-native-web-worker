package com.reactnativewebworker;

import androidx.annotation.Nullable;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.modules.core.DeviceEventManagerModule;

public class SelfModule extends NativeSelfSpec {
  public static final String NAME = "Self";

  public interface MessageListener {
    void onMessage(SelfModule selfModule, String message);
    void onError(SelfModule selfModule, String message);
  }

  private ReactApplicationContext mReactContext;
  private double mThreadId;
  private @Nullable
  MessageListener mMessageListener;

  public SelfModule(ReactApplicationContext reactContext) {
    super(reactContext);
    mReactContext = reactContext;
  }

  public void setThreadId(double threadId) {
    mThreadId = threadId;
  }

  public double getThreadId() {
    return mThreadId;
  }

  public void setMessageListener(MessageListener messageListener) {
    mMessageListener = messageListener;
  }

  public @Nullable MessageListener getMessageListener() {
    return mMessageListener;
  }

  @Override
  public String getName() {
    return NAME;
  }

  public void postMessage(String message) {
    if (mMessageListener != null) {
      mMessageListener.onMessage(this, message);
    }
  }

  public void postError(String message) {
    if (mMessageListener != null) {
        mMessageListener.onError(this, message);
    }
  }

  public void addListener(String eventName) {
    // Set up any upstream listeners or background tasks as necessary
  }

  public void removeListeners(double count) {
    // Remove upstream listeners, stop unnecessary background tasks
  }

  public void sendMessage(String message) {
    mReactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
      .emit("message", message);
  }

  public void onHostResume() {
    mReactContext.onHostResume(null);
  }

  public void onHostPause() {
    mReactContext.onHostPause();
  }

  public void terminate() {
    mReactContext.onHostPause();
    mReactContext.destroy();
    mReactContext = null;
  }
}
