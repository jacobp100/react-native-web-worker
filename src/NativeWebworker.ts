import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  startThread: (threadId: number, name: string, environment: string) => void;
  stopThread: (threadId: number) => void;
  postMessage: (threadId: number, message: string) => void;
  // RCTEventEmitter
  addListener: (eventName: string) => void;
  removeListeners: (count: number) => void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('WebWorker');
