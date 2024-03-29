package com.reactnativewebworker;

import androidx.annotation.NonNull;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

public class WebWorkerModule extends ReactContextBaseJavaModule {
  public static final String NAME = "WebWorker";

  private ReactApplicationContext mReactContext;
  private ReactNativeHost mReactNativeHost;
  private ReactPackage mAadditionalThreadPackages[];

  private HashMap<Integer, SelfModule> mThreads;

  public WebWorkerModule(final ReactApplicationContext reactContext, ReactNativeHost reactNativeHost, ReactPackage additionalThreadPackages[]) {
    super(reactContext);
    mReactContext = reactContext;
    mThreads = new HashMap<>();
    mReactNativeHost = reactNativeHost;
    mAadditionalThreadPackages = additionalThreadPackages;
    reactContext.addLifecycleEventListener(this);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }

  @ReactMethod
  public void startThread(int threadId, final String jsFileName) {
    Log.d(TAG, "Starting web thread - " + jsFileName);

    // When we create the absolute file path later, a "./" will break it.
    // Remove the leading "./" if it exists.
    String jsFileSlug = jsFileName.contains("./")
            ? jsFileName.replace("./", "")
            : jsFileName;

    JSBundleLoader bundleLoader = getDevSupportManager().getDevSupportEnabled()
            ? createDevBundleLoader(jsFileName, jsFileSlug)
            : createReleaseBundleLoader(jsFileName, jsFileSlug);

    try {
      ArrayList<ReactPackage> threadPackages = new ArrayList<ReactPackage>(Arrays.asList(mAadditionalThreadPackages));
      threadPackages.add(0, new WorkerBaseReactPackage(getReactInstanceManager()));

      ReactApplicationContext threadContext = new ReactContextBuilder(getReactApplicationContext())
              .setJSBundleLoader(bundleLoader)
              .setDevSupportManager(getDevSupportManager())
              .setReactInstanceManager(getReactInstanceManager())
              .setReactPackages(threadPackages)
              .build();

      SelfModule thread = threadContext.getNativeModule(SelfModule.class);
      thread.setThreadId(threadId);
      thread.setMessageListener(new SelfModule.MessageListener() {
        @Override
        public void onMessage(SelfModule thread, String message) {
          WritableMap params = Arguments.createMap();
          params.putInt("id", thread.getThreadId());
          params.putString("message", message);

          mReactContext
                  .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                  .emit("message", params);
        }

        @Override
        public void onError(SelfModule thread, String message) {
          WritableMap params = Arguments.createMap();
          params.putInt("id", thread.getThreadId());
          params.putString("message", message);

          mReactContext
                  .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                  .emit("error", params);
        }
      });

      mThreads.put(threadId, thread);
    } catch (Exception e) {
      getDevSupportManager().handleException(e);
    }
  }

  @ReactMethod
  public void stopThread(final int threadId) {
    final SelfModule thread = mThreads.get(threadId);
    if (thread == null) {
      Log.d(TAG, "Cannot stop thread - thread is null for id " + threadId);
      return;
    }

    new Handler(Looper.getMainLooper()).post(new Runnable() {
      @Override
      public void run() {
        thread.terminate();
        mThreads.remove(threadId);
      }
    });
  }

  @ReactMethod
  public void postThreadMessage(int threadId, String message) {
    SelfModule thread = mThreads.get(threadId);
    if (thread == null) {
      Log.d(TAG, "Cannot post message to thread - thread is null for id " + threadId);
      return;
    }

    thread.sendMessage(message);
  }

  // @Override
  // public void onHostResume() {
  //   new Handler(Looper.getMainLooper()).post(new Runnable() {
  //     @Override
  //     public void run() {
  //       for (int threadId : mThreads.keySet()) {
  //         mThreads.get(threadId).onHostResume();
  //       }
  //     }
  //   });
  // }

  // @Override
  // public void onHostPause() {
  //   new Handler(Looper.getMainLooper()).post(new Runnable() {
  //     @Override
  //     public void run() {
  //       for (int threadId : mThreads.keySet()) {
  //         mThreads.get(threadId).onHostPause();
  //       }
  //     }
  //   });
  // }

  // @Override
  // public void onHostDestroy() {
  //   Log.d(TAG, "onHostDestroy - Clean JS Threads");

  //   new Handler(Looper.getMainLooper()).post(new Runnable() {
  //     @Override
  //     public void run() {
  //       for (int threadId : mThreads.keySet()) {
  //         mThreads.get(threadId).terminate();
  //       }
  //     }
  //   });
  // }

  // @Override
  // public void onCatalystInstanceDestroy() {
  //   super.onCatalystInstanceDestroy();
  //   onHostDestroy();
  // }

  /* Helper methods */

  private JSBundleLoader createDevBundleLoader(String jsFileName, String jsFileSlug) {
    String bundleUrl = bundleUrlForFile(jsFileName);
    // nested file directory will not exist in the files dir during development,
    // so remove any leading directory paths to simply download a flat file into
    // the root of the files directory.
    String[] splitFileSlug = jsFileSlug.split("/");
    String bundleOut = getReactApplicationContext().getFilesDir().getAbsolutePath() + "/" + splitFileSlug[splitFileSlug.length - 1];

    Log.d(TAG, "createDevBundleLoader - download web thread to - " + bundleOut);
    downloadScriptToFileSync(bundleUrl, bundleOut);

    return JSBundleLoader.createCachedBundleFromNetworkLoader(bundleUrl, bundleOut);
  }

  private JSBundleLoader createReleaseBundleLoader(String jsFileName, String jsFileSlug) {
    Log.d(TAG, "createReleaseBundleLoader - reading file from assets");
    return JSBundleLoader.createAssetLoader(mReactContext, "assets://mThreads/" + jsFileSlug + ".bundle", false);
  }

  private ReactInstanceManager getReactInstanceManager() {
    return mReactNativeHost.getReactInstanceManager();
  }

  private DevSupportManager getDevSupportManager() {
    return getReactInstanceManager().getDevSupportManager();
  }

  private String bundleUrlForFile(final String fileName) {
    // http://localhost:8081/index.android.bundle?platform=android&dev=true&hot=false&minify=false
    String sourceUrl = getDevSupportManager().getSourceUrl().replace("http://", "");
    return  "http://"
            + sourceUrl.split("/")[0]
            + "/"
            + fileName
            + ".bundle?platform=android&dev=true&hot=false&minify=false";
  }

  private void downloadScriptToFileSync(String bundleUrl, String bundleOut) {
    OkHttpClient client = new OkHttpClient();
    final File out = new File(bundleOut);

    Request request = new Request.Builder()
            .url(bundleUrl)
            .build();

    try {
      Response response = client.newCall(request).execute();
      if (!response.isSuccessful()) {
        throw new RuntimeException("Error downloading thread script - " + response.toString());
      }

      Sink output = Okio.sink(out);
      Okio.buffer(response.body().source()).readAll(output);
    } catch (IOException e) {
      throw new RuntimeException("Exception downloading thread script to file", e);
    }
  }
}
