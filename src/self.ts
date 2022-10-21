import { AppRegistry, NativeModules, NativeEventEmitter } from 'react-native';

// @ts-expect-error
const isTurboModuleEnabled = global.__turboModuleProxy != null;

const SelfModule = isTurboModuleEnabled
  ? require('./NativeSelf').default
  : NativeModules.SelfModule;
const ThreadSelfManagerEvents = new NativeEventEmitter(SelfModule);

export type Self = {
  postMessage: (message: string) => void;
  onmessage: ((event: { data: string }) => void) | undefined;
};

// Force AppRegistry to be required - even after minification
// Without doing this, the UI freezes after seinding messages
AppRegistry.getRunnable('x');

const self: Self = {
  postMessage(message: string) {
    if (message != null) {
      SelfModule.postMessage(message);
    }
  },
  onmessage: undefined,
};

ThreadSelfManagerEvents.addListener('message', (message: string) => {
  if (typeof self.onmessage === 'function') {
    try {
      self.onmessage({ data: message });
    } catch (e: any) {
      SelfModule.postError(e.message ?? 'Unknown error');
    }
  }
});

export default self;
