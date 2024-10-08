import { AppRegistry, NativeModules, NativeEventEmitter } from 'react-native';

// @ts-expect-error
const isTurboModuleEnabled = global.__turboModuleProxy != null;

const SelfModule = isTurboModuleEnabled
  ? require('./NativeSelf').default
  : NativeModules.Self;
const ThreadSelfManagerEvents = new NativeEventEmitter(SelfModule);

export type Self = {
  postMessage: (message: string) => void;
  onmessage: ((event: { data: string }) => void) | undefined;
};

// Force AppRegistry to be required - even after minification
// Without doing this, the UI freezes after seinding messages
AppRegistry.getRunnable('x');

const self: Self = {
  postMessage(data: string) {
    if (data != null) {
      SelfModule.postMessage(data);
    }
  },
  onmessage: undefined,
};

ThreadSelfManagerEvents.addListener('message', (data: string) => {
  if (typeof self.onmessage === 'function') {
    try {
      self.onmessage({ data });
    } catch (e: any) {
      SelfModule.postError(e.message ?? 'Unknown error', e.name);
    }
  }
});

export default self;
