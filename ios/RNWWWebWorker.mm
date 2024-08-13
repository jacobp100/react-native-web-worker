#import "RNWWWebWorker.h"
#import <React/RCTDevSettings.h>
#import <React/RCTDevMenu.h>
#include <stdlib.h>

#import "RNWWEnvironment.h"
#import "RNWWEnvironmentBridge.h"
#import "RNWWEnvironmentLight.h"

#if RCT_NEW_ARCH_ENABLED
#import "RNWebworkerSpec.h"
#endif

@implementation RNWWWebWorker {
  NSMutableDictionary<NSNumber *, id<RNWWEnviromnent>> *_threads;
}

RCT_EXPORT_MODULE(WebWorker);

@synthesize bridge = _bridge;

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (instancetype)init
{
  if (self = [super init]) {
    _threads = [NSMutableDictionary new];
  }
  return self;
}

- (void)invalidate {
  for (NSNumber *threadId in _threads) {
    id<RNWWEnviromnent> enviromnent = _threads[threadId];
    [enviromnent invalidate];
  }

  [_threads removeAllObjects];
  _threads = nil;

  [super invalidate];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"message", @"error"];
}

#if RCT_DEV
// Calls to setHotkeysEnabled must be on the main thread
- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}
#endif

RCT_EXPORT_METHOD(startThread:(nonnull NSNumber *)threadId
                  name:(NSString *)name
                  environment:(NSString *)environment)
{
#if DEBUG
  NSURL *url = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:name];
#else
  NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"jsbundle"];
#endif

  id<RNWWEnviromnent> thread;
  if ([environment isEqualToString:@"light"]) {
    thread = [[RNWWEnvironmentLight alloc] initWithThreadId:threadId
                                                        url:url];
  } else {
    thread = [[RNWWEnvironmentBridge alloc] initWithBridge:_bridge
                                                  threadId:threadId
                                                       url:url];
  }

  thread.delegate = self;
  [_threads setObject:thread
               forKey:threadId];
}

RCT_EXPORT_METHOD(stopThread:(nonnull NSNumber *)threadId
                  mode:(NSString *)mode)
{
  id<RNWWEnviromnent> thread = _threads[threadId];
  if (thread == nil) {
    return;
  }

  if ([mode isEqualToString:@"execution"]) {
    [thread abortExecution];
  } else {
    [thread invalidate];
    [_threads removeObjectForKey:threadId];
  }
}

RCT_EXPORT_METHOD(postThreadMessage:(nonnull NSNumber *)threadId
                  message:(NSString *)message)
{
  id<RNWWEnviromnent> thread = _threads[threadId];
  if (thread == nil) {
    NSLog(@"Could not post to thread with id %@", threadId);
    return;
  }

  [thread postMessage:message];
}

- (void)didReceiveMessage:(id<RNWWEnviromnent>)sender
                  message:(NSString *)message
{
  id body = @{
    @"id": sender.threadId,
    @"message": message,
  };
  [self sendEventWithName:@"message"
                     body:body];
}

- (void)didReceiveError:(id<RNWWEnviromnent>)sender
                message:(NSString *)message
                   name:(NSString *)name
{
  id body = @{
    @"id": sender.threadId,
    @"message": message,
    @"name": name,
  };
  [self sendEventWithName:@"error"
                     body:body];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return bridge.launchOptions[@"threadUrl"];
}

#if RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeWebWorkerSpecJSI>(params);
}
#endif

@end
