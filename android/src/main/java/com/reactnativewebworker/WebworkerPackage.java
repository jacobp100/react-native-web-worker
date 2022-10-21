package com.reactnativewebworker;

import androidx.annotation.Nullable;

import com.facebook.react.ReactNativeHost;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.module.model.ReactModuleInfo;
import com.facebook.react.module.model.ReactModuleInfoProvider;
import com.facebook.react.TurboReactPackage;

import java.util.HashMap;
import java.util.Map;

public class WebworkerPackage extends TurboReactPackage {

  private ReactNativeHost mReactNativeHost;

  public WebworkerPackage(ReactNativeHost reactNativeHost) {
    mReactNativeHost = reactNativeHost;
  }

  @Nullable
  @Override
  public NativeModule getModule(String name, ReactApplicationContext reactContext) {
    if (name.equals(WebWorkerModule.NAME)) {
      return new WebWorkerModule(reactContext, mReactNativeHost);
    } else if (name.equals(SelfModule.NAME)) {
      return new SelfModule(reactContext);
    } else {
      return null;
    }
  }

  @Override
  public ReactModuleInfoProvider getReactModuleInfoProvider() {
    return () -> {
      final Map<String, ReactModuleInfo> moduleInfos = new HashMap<>();
      boolean isTurboModule = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED;
      moduleInfos.put(
        WebWorkerModule.NAME,
        new ReactModuleInfo(
          WebWorkerModule.NAME,
          WebWorkerModule.NAME,
          false, // canOverrideExistingModule
          false, // needsEagerInit
          true, // hasConstants
          false, // isCxxModule
          isTurboModule // isTurboModule
        )
      );
      moduleInfos.put(
        SelfModule.NAME,
        new ReactModuleInfo(
          SelfModule.NAME,
          SelfModule.NAME,
          false, // canOverrideExistingModule
          false, // needsEagerInit
          true, // hasConstants
          false, // isCxxModule
          isTurboModule // isTurboModule
        )
      );
      return moduleInfos;
    };
  }
}
