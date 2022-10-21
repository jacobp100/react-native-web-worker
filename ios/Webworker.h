#ifdef RCT_NEW_ARCH_ENABLED
#import "RNWebworkerSpec.h"

@interface Webworker : NSObject <NativeWebworkerSpec>
#else
#import <React/RCTBridgeModule.h>

@interface Webworker : NSObject <RCTBridgeModule>
#endif

@end
