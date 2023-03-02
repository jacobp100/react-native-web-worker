#import "RNWWEnvironmentBridge.h"
#import <React/RCTDevSettings.h>
#import <React/RCTDevMenu.h>
#import <React/RCTAppSetupUtils.h>
#include <stdlib.h>

#if RCT_NEW_ARCH_ENABLED
#import <React/CoreModulesPlugins.h>
#import <React/RCTCxxBridgeDelegate.h>
#import <ReactCommon/RCTTurboModuleManager.h>

@interface RNWWEnvironmentBridge () <RCTCxxBridgeDelegate, RCTTurboModuleManagerDelegate>
@end
#endif

@implementation RNWWEnvironmentBridge {
  NSURL *_url;
  RCTBridge *_threadBridge;
}

- (instancetype)initWithBridge:(RCTBridge *)bridge
                      threadId:(NSNumber *)threadId
                           url:(NSURL *)url
{
  self = [super init];
  if (self) {
    self.threadId = threadId;
    _url = url;

#if RCT_DEV
    RCTDevMenu *mainDevMenu = [bridge moduleForClass:RCTDevMenu.class];
    // We have to read this early as the value may change when loading a new thread
    BOOL hotkeysEnabled = [mainDevMenu hotkeysEnabled];
#endif

    _threadBridge = [[RCTBridge alloc] initWithDelegate:self
                                          launchOptions:nil];

    RNWWSelf *threadSelf = [_threadBridge moduleForClass:RNWWSelf.class];
    threadSelf.delegate = self;

#if RCT_DEV
    // When we start a new thread, we'll initialize a new DevMenu class, which will
    // then override the existing handlers for shake and key presses
    // We can turn some of this behaviour off; however, it gets stored in the user settings,
    // and applied to the main DevMenu class
    // Here, we do the best effort to un-initialize the key commands

    // First, disable the main keyboard shortcuts so we know re-enabling later won't no-op
    [mainDevMenu setHotkeysEnabled:NO];

    RCTDevMenu *threadDevMenu = [_threadBridge moduleForClass:RCTDevMenu.class];
    // Disable the shake gesture handler
    [[NSNotificationCenter defaultCenter] removeObserver:threadDevMenu];
    // Disable thread keyboard shortcuts
    [threadDevMenu setHotkeysEnabled:NO];

    // Lastly, re-enable the main keyboard shortcuts if they were enabled
    [mainDevMenu setHotkeysEnabled:hotkeysEnabled];
#endif
  }
  return self;
}

- (void)invalidate
{
  [_threadBridge invalidate];
}

- (void)postMessage:(NSString *)message
{
  RNWWSelf *threadSelf = [_threadBridge moduleForClass:RNWWSelf.class];
  [threadSelf postMessage:message];
}

RCT_NOT_IMPLEMENTED(- (void)abortExecution)

- (void)didReceiveMessage:(RNWWSelf *)sender
                  message:(NSString *)message
{
  [self.delegate didReceiveMessage:self
                           message:message];
}

- (void)didReceiveError:(RNWWSelf *)sender
                message:(NSString *)message
{
  [self.delegate didReceiveError:self
                         message:message];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return _url;
}

#if RCT_NEW_ARCH_ENABLED

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
