#import <React/RCTBridge.h>
#import <React/RCTBridgeDelegate.h>
#import <React/RCTBundleURLProvider.h>

#import "RNWWEnvironment.h"
#import "RNWWSelf.h"

@interface RNWWEnvironmentBridge : NSObject <RNWWEnvironment, RCTBridgeDelegate, RNWWSelfDelegate>

@property (nonatomic, weak) id<RNWWEnvironmentDelegate> delegate;
@property (nonatomic, copy) NSNumber *threadId;

- (instancetype)initWithBridge:(RCTBridge *)bridge
                      threadId:(NSNumber *)threadId
                           url:(NSURL *)url;

@end
