#import "RNWWEnvironmentHermes.h"

#import <React/RCTDefines.h>

#if __has_include(<hermes-engine/hermes/hermes.h>)
#import <React/RCTJavaScriptLoader.h>
#import <hermes-engine/hermes/hermes.h>

#include <utility>

using namespace facebook::jsi;
using namespace facebook::hermes;

@implementation RNWWEnvironmentHermes {
  std::shared_ptr<HermesRuntime> _runtime;
  dispatch_queue_t _queue;
  // Messages queued here until the JS has loaded (lazily created)
  NSMutableArray<NSString *> *_pendingEvents;
  BOOL _isLoading;
}

- (instancetype)initWithThreadId:(NSNumber *)threadId
                             url:(NSURL *)url
{
  self = [super init];
  if (self) {
    self.threadId = threadId;
    _isLoading = YES;


    dispatch_queue_attr_t qos = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                        QOS_CLASS_BACKGROUND,
                                                                        -1);
    _queue = dispatch_queue_create("hermes", qos);

    _runtime = makeHermesRuntime();

    __weak __typeof(self) weakSelf = self;

    _runtime->global().setProperty(*_runtime, "self", _runtime->global());

    Function postMessage =
      Function::createFromHostFunction(*_runtime,
                                       PropNameID::forAscii(*_runtime, "postMessage"),
                                       1,
                                       [weakSelf](Runtime &rt, const Value &thisVal, const Value *args, size_t count) {
        if (!args->isString()) {
          return Value::undefined();
        }

        __strong __typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
          return Value::undefined();
        }

        std::string utf8 = args->asString(rt).utf8(rt);
        NSString *message = [NSString stringWithCString:utf8.c_str()
                                               encoding:NSUTF8StringEncoding];
        [strongSelf->_delegate didReceiveMessage:strongSelf
                                         message:message];
        return Value::undefined();
    });
    _runtime->global().setProperty(*_runtime, "postMessage", postMessage);

    [RCTJavaScriptLoader loadBundleAtURL:url
                              onProgress:^(RCTLoadingProgress *progressData) {}
                              onComplete:^(NSError *error, RCTSource *source) {
      __strong __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      strongSelf->_isLoading = NO;
      NSString *contents = [[NSString alloc] initWithData:source.data
                                                 encoding:NSUTF8StringEncoding];
      std::string script([contents cStringUsingEncoding:NSUTF8StringEncoding]);
      strongSelf->_runtime->evaluateJavaScript(std::make_shared<StringBuffer>(script),
                                               url.absoluteString.UTF8String);
      [strongSelf dispatchMessagesIfNeeded];
    }];
  }
  return self;
}

- (void)dealloc
{
  if (_runtime != nil) {
    [self invalidate];
  }
}

- (void)invalidate
{
  _runtime->watchTimeLimit(0);
  _runtime = nil;
}

- (void)runAsync:(void (^)(std::shared_ptr<HermesRuntime>))block
{
  __weak __typeof(self) weakSelf = self;
  dispatch_async(_queue, ^{
    __strong __typeof(self) strongSelf = weakSelf;
    if (strongSelf != nil && strongSelf->_runtime != nil) {
      block(strongSelf->_runtime);
    }
  });
}

- (void)dispatchMessage:(NSString *)message
{
  [self runAsync:^(std::shared_ptr<HermesRuntime> rt) {
    Value onMessageValue = rt->global().getProperty(*rt, "onmessage");
    if (!onMessageValue.isObject()) {
      return;
    }

    Object onMessageObject = onMessageValue.asObject(*rt);
    if (!onMessageObject.isFunction(*rt)) {
      return;
    }

    std::string messageCString([message cStringUsingEncoding:NSUTF8StringEncoding]);
    Value data = String::createFromUtf8(*rt, messageCString);

    Object event = Object(*rt);
    event.setProperty(*rt, "data", data);

    Function onMessage = onMessageObject.getFunction(*rt);

    try {
      onMessage.call(*rt, event, 1);
    } catch (...) {
      // FIXME - can't figure out what the exception type is
      NSLog(@"DID CATCH");
    }
  }];
}

- (void)dispatchMessagesIfNeeded
{
  if (!_pendingEvents) {
    return;
  }

  for (NSString *message in _pendingEvents) {
    [self dispatchMessage:message];
  }

  [_pendingEvents removeAllObjects];
  _pendingEvents = nil;
}


- (void)postMessage:(NSString *)message
{
  _runtime->unwatchTimeLimit();

  if (!_isLoading) {
    [self dispatchMessagesIfNeeded];
    [self dispatchMessage:message];
  } else if (_pendingEvents != nil) {
    [_pendingEvents addObject:message];
  } else {
    _pendingEvents = [[NSMutableArray alloc] initWithObjects:message, nil];
  }
}

- (void)abortExecution
{
  _runtime->watchTimeLimit(0);
}

@end
#else
@implementation RNWWEnvironmentHermes

RCT_NOT_IMPLEMENTED(- (instancetype)initWithThreadId:(NSNumber *)threadId url:(NSURL *)url)

RCT_NOT_IMPLEMENTED(- (void)invalidate)

RCT_NOT_IMPLEMENTED(- (void)postMessage:(NSString *)message)

RCT_NOT_IMPLEMENTED(- (void)abortExecution)

@end
#endif
