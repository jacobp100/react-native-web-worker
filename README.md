# react-native-webworker

<a href="https://jacobdoescode.com/technicalc"><img alt="Part of the TechniCalc Project" src="https://github.com/jacobp100/technicalc-core/blob/master/banner.png" width="200" height="60"></a>

[WebWorkers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API) for React Native

Work based off [react-native-threads](https://github.com/joltup/react-native-threads)

Supports the new architecture, using either [Hermes](https://hermesengine.dev) or JavaScriptCore

Currently only supports iOS

## Usage

```
npm install @jacobp100/react-native-webworker
(cd ios; bundle exec pod install)
```

In your application code (React components, etc.):

```js
import { WebWorker } from '@jacobp100/react-native-webworker';

// Start a new react native JS process
// The worker JS file has to be at the top level (where the package.json is)
// But you can call it anything you want - and have multiple
const worker = new WebWorker('/worker.js');

// Send a message, strings only
worker.postMessage('hello');

// Listen for messages
worker.onmessage = (e) => console.log(e.data);

// Listen for errors
worker.onerror = (e) => console.log(e.message);

// Stop the JS process
worker.terminate();
```

In your thread code (dedicated file such as `worker.js`):

```js
import { self } from 'react-native-threads';

// Listen for messages
self.onmessage = (e) => {
  // Message is a string
  const message = e.data;
};

// Send a message, strings only
self.postMessage('hello');
```

## Thread Lifecycle

- Threads are paused when the app enters in the background
- Threads are resumed once the app is running in the foreground
- During development, when you reload the main JS bundle (shake device -> `Reload`) the threads are killed

## Debugging

Instantiating Threads creates multiple react native JS processes and can make debugging remotely behave unpredictably. I recommend using a third party debugging tool like [Reactotron](https://github.com/infinitered/reactotron) to aid with this. Each process, including your main application as well as your thread code can connect to Reactotron and log debugging messages.

## Building for Release

Depending on if you're using [Hermes](https://hermesengine.dev) (the default) or JavaScript Core, the commands differ. For iOS, the commands you'll need to add are:-

##### Hermes

```bash
# Bundle your worker JS
npx react-native bundle --dev false --minify false --assets-dest ./ios --entry-file worker.js --platform ios --bundle-output ./ios/worker.jsbundle
# Convert bundled JS to Hermes ByteCode
./ios/Pods/hermes-engine/destroot/bin/hermesc -emit-binary ./ios/worker.jsbundle -out ./ios/worker.jsbundle
```

#### JavaScriptCore

```bash
npx react-native bundle --dev false --assets-dest ./ios --entry-file worker.js --platform ios --bundle-output ./ios/worker.jsbundle
```

Once you have generated the bundle file in your ios folder, you will also need to add the bundle file to you project in Xcode. In Xcode's file explorer you should see a folder with the same name as your app, containing a `main.jsbundle` file as well as an `AppDelegate.m` file. Right click on that folder and select the 'Add Files to <Your App Name>' option, which will open up finder and allow you to select your `ios/worker.jsbundle` file. You will only need to do this once, and the file will be included in all future builds.

For convenience I recommend adding these thread building commands as npm scripts to your project.

## Optimisations (Experimental)

By default, you can use most of React Native and it's related infrastructure in your workers. This includes globals like `fetch`, `setTimeout` etc. However, including this makes your worker file about 800kb larger.

If your worker does not use those globals - maybe it only does heavy computation that would lock the UI thread - you can run the worker using a lighter environment, and get the benefit of a smaller bundle.

The light environment will use will use either Hermes or JavaScriptCore - depending on what's used in your app.

When using Hermes, JS exceptions are caught and reported, but the message cannot (yet) be recovered, and are always reported as _Unknown error_.

```js
import { WebWorker } from '@jacobp100/react-native-webworker';

const worker = new WebWorker('path/to/worker.js', {
  environment: 'light',
});
```

In your worker, **do not import react-native or any react-native related packages** - it'll cause a crash. The `self` variable is exposed as a global.

```js
self.onmessage = (e) => {
  self.postMessage(`Hello ${e.data}`);
};
```

## Infinite Loops

If you're using JavaScriptCore, there is no mechanism to terminate currently executing code. This means if your worker code goes into an infinite loop, calling `worker.terminate()` will not stop the execution.

Hermes does support this, and will do so automatically in development builds, but needs additional setup for release builds. In your build command, you'll need to add the `-emit-async-break-check` to the hermes compile command.

```diff
-./ios/Pods/hermes-engine/destroot/bin/hermesc -emit-binary ./ios/worker.jsbundle -out ./ios/worker.jsbundle
+./ios/Pods/hermes-engine/destroot/bin/hermesc -emit-binary -emit-async-break-check ./ios/worker.jsbundle -out ./ios/worker.jsbundle
```

Note that doing this makes the bundle ~10x bigger, and will have an impact on performance too. However, if you don't do this, infinite loops will continue to run in the background and degrade battery life.

In the case you are terminating the worker only to stop long running code, and intend on re-initializing the worker afterwards, you can skip some steps and just abort just the long running code, leaving the worker otherwise in-tact. This saves the need to re-parse the JavaScript and re-initialize the worker. Be cautious when doing this - you must be consider any global state in your worker, and if terminating half way through will cause correctness issues.

If this scenario is suitable for your use-case, you can call `worker.terminate({ mode: 'execution' })`. This will call the `onerror` handler. You can continue to call `worker.postMessage`, and you do not need to wait for the `onerror` handler to fire.
