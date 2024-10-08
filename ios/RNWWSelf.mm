#import "RNWWSelf.h"
#include <stdlib.h>

#if RCT_NEW_ARCH_ENABLED
#import "RNWebworkerSpec.h"
#endif

@implementation RNWWSelf {
  // Messages queued here until the JS has loaded (lazily created)
  NSMutableArray<NSString *> *_pendingEvents;
}

RCT_EXPORT_MODULE(Self);

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (instancetype)init
{
  if (self = [super init]) {
    [NSNotificationCenter.defaultCenter
     addObserver:self
     selector:@selector(handleBridgeDidLoadJavaScriptNotification:)
     name:RCTJavaScriptDidLoadNotification
     object:self.bridge];
  }
  return self;
}

- (void)invalidate
{
  [NSNotificationCenter.defaultCenter removeObserver:self];

  [_pendingEvents removeAllObjects];
  _pendingEvents = nil;

  [super invalidate];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"message"];
}

- (void)dispatchMessagesIfNeeded
{
  if (!_pendingEvents || self.bridge.isLoading) {
    return;
  }

  for (NSString *message in _pendingEvents) {
    [self sendEventWithName:@"message" body:message];
  }

  [_pendingEvents removeAllObjects];
  _pendingEvents = nil;
}

- (void)handleBridgeDidLoadJavaScriptNotification:(NSNotification *)notification
{
  [self dispatchMessagesIfNeeded];
}

- (void)postMessage:(NSString *)message
{
  if (!self.bridge.isLoading) {
    [self dispatchMessagesIfNeeded];
    [self sendEventWithName:@"message" body:message];
  } else if (_pendingEvents) {
    [_pendingEvents addObject:message];
  } else {
    _pendingEvents = [[NSMutableArray alloc] initWithObjects:message, nil];
  }
}

RCT_REMAP_METHOD(postMessage,
                 didReceiveMessage:(NSString *)data)
{
  if (self.delegate == nil) {
    NSLog(@"ERROR: postMessage sent outside worker context");
    return;
  }

  [self.delegate didReceiveMessage:self
                              data:data];
}

RCT_REMAP_METHOD(postError,
                 didReceiveError:(NSString *)message
                 name:(NSString *)name)
{
  if (self.delegate == nil) {
    NSLog(@"ERROR: postMessage sent outside worker context");
    return;
  }

  [self.delegate didReceiveError:self
                         message:message
                            name:name];
}

#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeSelfSpecJSI>(params);
}
#endif

@end
