#import "RNWWWebWorker.h"
#import <React/RCTDevSettings.h>
#import <React/RCTDevMenu.h>
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

#if RCT_DEV
// Calls to setHotkeysEnabled must be on the main thread
- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}
#endif

RCT_EXPORT_METHOD(startThread:(nonnull NSNumber *)threadId
                  name:(NSString *)name)
{
#if RCT_DEV
  RCTDevMenu *mainDevMenu = [_bridge moduleForClass:RCTDevMenu.class];
  // We have to read this early as the value may change when loading a new thread
  BOOL hotkeysEnabled = [mainDevMenu hotkeysEnabled];
#endif

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

  RNWWSelf *threadSelf = [threadBridge moduleForClass:RNWWSelf.class];
  threadSelf.threadId = threadId;
  threadSelf.delegate = self;

  _threads[threadId] = threadBridge;

#if RCT_DEV
  // When we start a new thread, we'll initialize a new DevMenu class, which will
  // then override the existing handlers for shake and key presses
  // We can turn some of this behaviour off; however, it gets stored in the user settings,
  // and applied to the main DevMenu class
  // Here, we do the best effort to un-initialize the key commands

  // First, disable the main keyboard shortcuts so we know re-enabling later won't no-op
  [mainDevMenu setHotkeysEnabled:NO];

  RCTDevMenu *threadDevMenu = [threadBridge moduleForClass:RCTDevMenu.class];
  // Disable the shake gesture handler
  [[NSNotificationCenter defaultCenter] removeObserver:threadDevMenu];
  // Disable thread keyboard shortcuts
  [threadDevMenu setHotkeysEnabled:NO];

  // Lastly, re-enable the main keyboard shortcuts if they were enabled
  [mainDevMenu setHotkeysEnabled:hotkeysEnabled];
#endif
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
