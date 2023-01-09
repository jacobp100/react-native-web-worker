#import "RNWWWebWorker.h"
#import <React/RCTDevSettings.h>
#include <stdlib.h>

#import <React/RCTAppSetupUtils.h>

#if RCT_NEW_ARCH_ENABLED
#import "RNWebworkerSpec.h"

#import <React/CoreModulesPlugins.h>
#import <React/RCTCxxBridgeDelegate.h>
#import <ReactCommon/RCTTurboModuleManager.h>

@interface RNWWWebWorker () <RCTCxxBridgeDelegate, RCTTurboModuleManagerDelegate>
@end
#endif

@implementation RNWWWebWorker {
  NSMutableDictionary<NSNumber *, RCTBridge *> *_threads;
}

RCT_EXPORT_MODULE(WebWorker);

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
    RCTBridge *threadBridge = _threads[threadId];
    [threadBridge invalidate];
  }

  [_threads removeAllObjects];
  _threads = nil;

  [super invalidate];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"message", @"error"];
}

RCT_EXPORT_METHOD(startThread:(nonnull NSNumber *)threadId
                  name:(NSString *)name)
{
#if DEBUG
  NSURL *threadUrl = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:name];
#else
  NSURL *threadUrl = [[NSBundle mainBundle] URLForResource:name withExtension:@"jsbundle"];
#endif

  // There's no nice way create an RCTBridge with a delegate and bundle URL
  // Just store the threadUrl in the launch options so we can access it easily
  NSDictionary *launchOptions = @{
    @"threadId": threadId,
    @"threadUrl": threadUrl,
  };
  RCTBridge *threadBridge = [[RCTBridge alloc] initWithDelegate:self
                                                  launchOptions:launchOptions];

  // Ensure shaking device doesn't open additional dev menus
  [[threadBridge moduleForClass:RCTDevSettings.class]
   setIsShakeToShowDevMenuEnabled:NO];

  RNWWSelf *threadSelf = [threadBridge moduleForClass:RNWWSelf.class];
  threadSelf.threadId = threadId;
  threadSelf.delegate = self;

  _threads[threadId] = threadBridge;
}

RCT_EXPORT_METHOD(stopThread:(nonnull NSNumber *)threadId)
{
  RCTBridge *threadBridge = _threads[threadId];
  if (threadBridge == nil) {
    return;
  }

  [threadBridge invalidate];
  [_threads removeObjectForKey:threadId];
}

RCT_EXPORT_METHOD(postThreadMessage:(nonnull NSNumber *)threadId
                  message:(NSString *)message)
{
  RCTBridge *threadBridge = _threads[threadId];
  if (threadBridge == nil) {
    NSLog(@"Thread is Nil. abort posting to thread with id %@", threadId);
    return;
  }

  RNWWSelf *threadSelf = [threadBridge moduleForClass:RNWWSelf.class];
  [threadSelf postMessage:message];
}

- (void)didReceiveMessage:(RNWWSelf *)sender
                  message:(NSString *)message
{
  id body = @{
    @"id": sender.threadId,
    @"message": message,
  };
  [self sendEventWithName:@"message"
                     body:body];
}

- (void)didReceiveError:(RNWWSelf *)sender
                message:(NSString *)message
{
  id body = @{
    @"id": sender.threadId,
    @"message": message,
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

#pragma mark - RCTCxxBridgeDelegate

- (std::unique_ptr<facebook::react::JSExecutorFactory>)jsExecutorFactoryForBridge:(RCTBridge *)bridge
{
  RCTTurboModuleManager *turboModuleManager = [[RCTTurboModuleManager alloc]
                                               initWithBridge:bridge
                                               delegate:self
                                               jsInvoker:bridge.jsCallInvoker];
  return RCTAppSetupDefaultJsExecutorFactory(bridge, turboModuleManager);
}

#pragma mark RCTTurboModuleManagerDelegate

- (Class)getModuleClassFromName:(const char *)name
{
  return RCTCoreModulesClassProvider(name);
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const std::string &)name
                                                      jsInvoker:(std::shared_ptr<facebook::react::CallInvoker>)jsInvoker
{
  return nullptr;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const std::string &)name
                                                     initParams:
                                                         (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return nullptr;
}

- (id<RCTTurboModule>)getModuleInstanceFromClass:(Class)moduleClass
{
  return RCTAppSetupDefaultModuleFromClass(moduleClass);
}

#endif

@end
