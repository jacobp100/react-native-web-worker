#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>

#import "RNWWEnvironment.h"

@interface RNWWWebWorker : RCTEventEmitter <RCTBridgeModule, RNWWEnviromnentDelegate>
@end
