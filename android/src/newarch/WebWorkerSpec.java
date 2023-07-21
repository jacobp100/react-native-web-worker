package com.webworker;

import com.facebook.react.bridge.ReactApplicationContext;

abstract class WebWorkerSpec extends NativeWebWorkerSpec {
  WebWorkerSpec(ReactApplicationContext context) {
    super(context);
  }
}
