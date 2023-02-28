import { NativeModules, NativeEventEmitter } from 'react-native';

// @ts-expect-error
const isTurboModuleEnabled = global.__turboModuleProxy != null;

const WebWorkerModule = isTurboModuleEnabled
  ? require('./NativeWebWorker').default
  : NativeModules.WebWorker;
const ThreadEvents = new NativeEventEmitter(WebWorkerModule);

let currentId = 0;

type MessageEvent = { id: number; message: string };

type Options = {
  enviromnent?: 'react-native' | 'javascript-core';
};

export default class Thread {
  id: number;
  onmessage: ((event: { data: string }) => void) | undefined;
  onerror: ((event: { message: string }) => void) | undefined;

  private terminated: boolean;
  private messageListener: { remove: () => void };
  private errorListener: { remove: () => void };

  constructor(jsPath: string, { enviromnent = 'react-native' }: Options = {}) {
    if (typeof jsPath !== 'string' || !jsPath.endsWith('.js')) {
      throw new Error('Invalid path for thread. Only js files are supported');
    }

    this.id = currentId++;
    this.terminated = false;

    this.onmessage = undefined;
    this.onerror = undefined;

    this.messageListener = ThreadEvents.addListener(
      'message',
      ({ id, message }: MessageEvent) => {
        if (
          !this.terminated &&
          id === this.id &&
          typeof this.onmessage === 'function'
        ) {
          this.onmessage({ data: message });
        }
      }
    );

    this.errorListener = ThreadEvents.addListener(
      'error',
      ({ id, message }: MessageEvent) => {
        if (
          !this.terminated &&
          id === this.id &&
          typeof this.onerror === 'function'
        ) {
          this.onerror({ message });
        }
      }
    );

    const name = jsPath.slice(0, -'.js'.length);
    WebWorkerModule.startThread(this.id, name, enviromnent);
  }

  postMessage(message: string) {
    if (this.terminated) {
      if (__DEV__) {
        console.warn('Attempted to call postMessage on terminated worker');
      }
      return;
    }

    WebWorkerModule.postThreadMessage(this.id, message);
  }

  terminate() {
    if (this.terminated) {
      if (__DEV__) {
        console.warn('Attempted to call terminate on terminated worker');
      }
      return;
    }

    this.terminated = true;
    this.messageListener.remove();
    this.errorListener.remove();
    WebWorkerModule.stopThread(this.id);
  }
}
