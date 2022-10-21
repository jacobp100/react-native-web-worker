import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-webworker' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

// @ts-expect-error
const isTurboModuleEnabled = global.__turboModuleProxy != null;

const WebworkerModule = isTurboModuleEnabled
  ? require('./NativeWebworker').default
  : NativeModules.Webworker;

const Webworker = WebworkerModule
  ? WebworkerModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function multiply(a: number, b: number): Promise<number> {
  return Webworker.multiply(a, b);
}
