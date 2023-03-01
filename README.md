# react-native-webworker

<a href="https://jacobdoescode.com/technicalc"><img alt="Part of the TechniCalc Project" src="https://github.com/jacobp100/technicalc-core/blob/master/banner.png" width="200" height="60"></a>

[WebWorkers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API) for React Native

Work based off [react-native-threads](https://github.com/joltup/react-native-threads)

Supports the new architecture. Currently only supports iOS.

## Usage

```
npm install @jacobp100/react-native-webworker
(cd ios; bundle exec pod install)
```

In your application code (React components, etc.):

```js
import { WebWorker } from '@jacobp100/react-native-webworker';

// Start a new react native JS process
const worker = new WebWorker('path/to/worker.js');

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

Instantiating Threads creates multiple react native JS processes and can make debugging
remotely behave unpredictably. I recommend using a third party debugging tool like
[Reactotron](https://github.com/infinitered/reactotron) to aid with this. Each process,
including your main application as well as your thread code can connect to Reactotron
and log debugging messages.

## Building for Release

For iOS you can use the following command:

`node node_modules/react-native/local-cli/cli.js bundle --dev false --assets-dest ./ios --entry-file index.worker.js --platform ios --bundle-output ./ios/index.worker.jsbundle`

Once you have generated the bundle file in your ios folder, you will also need to add
the bundle file to you project in Xcode. In Xcode's file explorer you should see
a folder with the same name as your app, containing a `main.jsbundle` file as well
as an `AppDelegate.m` file. Right click on that folder and select the 'Add Files to <Your App Name>'
option, which will open up finder and allow you to select your `ios/index.worker.jsbundle`
file. You will only need to do this once, and the file will be included in all future
builds.

For convenience I recommend adding these thread building commands as npm scripts
to your project.

## Optimisations

By default, you can use most of React Native and it's related infrastructure in your workers. This includes globals like `fetch`, `setTimeout` etc. However, including this makes your worker file about 800kb larger.

If your worker does not use those globals - maybe it only does heavy computation that would lock the UI thread - you can run the worker using a lighter environment.

```js
import { WebWorker } from '@jacobp100/react-native-webworker';

const worker = new WebWorker('path/to/worker.js', {
  environment: 'javascript-core',
});
```

In your worker, **do not import react-native or any react-native related packages**. The `self` variable is exposed as a global.

```js
self.onmessage = (e) => {
  self.postMessage(`Hello ${e.data}`);
};
```

The `javascript-core` environment uses [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore), and not Hermes. As this is bundled into iOS itself, you can use Hermes for your main application and won't pay the cost of including two JavaScript engines.
