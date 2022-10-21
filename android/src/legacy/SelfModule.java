package com.reactnativewebworker;

import androidx.annotation.NonNull;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

public class SelfModule extends ReactContextBaseJavaModule {
  public static final String NAME = SelfModuleImpl.NAME;
  private SelfModuleImpl mImpl;

  public SelfModule(ReactApplicationContext reactContext) {
    super(context);
    mImpl = new SelfModule(reactContext);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }

  @ReactMethod
  public void postMessage(final String jsFileName) {
    mImpl.postMessage(jsFileName);
  }

  @ReactMethod
  public void postError(final String jsFileName) {
    mImpl.postError(jsFileName);
  }
}
