#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTBridge.h>
#import <React/RCTBridgeDelegate.h>
#import <React/RCTBundleURLProvider.h>

#import "RNWWSelf.h"

@interface RNWWWebWorker : RCTEventEmitter <RCTBridgeModule, RCTBridgeDelegate, RNWWSelfDelegate>
@end
