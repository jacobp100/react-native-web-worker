#import "RNWWEnvironmentLight.h"

#import <React/RCTDefines.h>
#import <React/RCTJavaScriptLoader.h>

#if __has_include(<hermes-engine/hermes/hermes.h>)
#define RNWW_USE_HERMES 1
#else
#define RNWW_USE_HERMES 0
#endif

#if RNWW_USE_HERMES
#import <hermes-engine/hermes/hermes.h>

#include <utility>

using namespace facebook::jsi;
using namespace facebook::hermes;
#else
#import <JavaScriptCore/JavaScriptCore.h>
#endif

@implementation RNWWEnvironmentLight {
#if RNWW_USE_HERMES
#define RUNTIME std::shared_ptr<HermesRuntime>
#else
#define RUNTIME JSContext *
#endif
  RUNTIME _runtime;
  dispatch_queue_t _queue;
  // Messages queued here until the JS has loaded (lazily created)
  NSMutableArray<NSString *> *_pendingEvents;
  BOOL _isLoading;
}

+ (RUNTIME)initRuntime:(void (^)(NSString *))onMessageBlock
               onError:(void (^)(NSString *))onErrorBlock
{
#if RNWW_USE_HERMES
  RUNTIME runtime = makeHermesRuntime();

  runtime->global().setProperty(*runtime, "self", runtime->global());

  Function postMessage =
  Function::createFromHostFunction(*runtime,
                                   PropNameID::forAscii(*runtime, "postMessage"),
                                   1,
                                   [onMessageBlock](Runtime &rt, const Value &thisVal, const Value *args, size_t count) {
    if (args->isString()) {
      std::string utf8 = args->asString(rt).utf8(rt);
      NSString *message = [NSString stringWithCString:utf8.c_str()
                                             encoding:NSUTF8StringEncoding];
      onMessageBlock(message);
    }

    return Value::undefined();
  });
  runtime->global().setProperty(*runtime, "postMessage", postMessage);

  return runtime;
#else
  RUNTIME runtime = [JSContext new];

  runtime[@"self"] = runtime.globalObject;
  runtime[@"postMessage"] = ^(NSString *message) {
    onMessageBlock(message);
  };
  runtime.exceptionHandler = ^(JSContext *context, JSValue *exception) {
    JSValue *messageValue = exception[@"message"];
    NSString *message = messageValue.isString
    ? messageValue.toString
    : @"Unknown error";
    onErrorBlock(message);
  };

  return runtime;
#endif
}

- (instancetype)initWithThreadId:(NSNumber *)threadId
                             url:(NSURL *)url
{
  self = [super init];
  if (self) {
    self.threadId = threadId;
    _isLoading = YES;
    dispatch_queue_attr_t qos = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                        QOS_CLASS_DEFAULT,
                                                                        -1);
    _queue = dispatch_queue_create("hermes", qos);

    __weak __typeof(self) weakSelf = self;

    _runtime = [RNWWEnvironmentLight initRuntime:^(NSString *message) {
      __strong __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      [strongSelf.delegate didReceiveMessage:strongSelf
                                     message:message];
    } onError:^(NSString *message) {
      __strong __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      [strongSelf.delegate didReceiveError:strongSelf
                                   message:message];
    }];

    [RCTJavaScriptLoader loadBundleAtURL:url
                              onProgress:^(RCTLoadingProgress *progressData) {}
                              onComplete:^(NSError *error, RCTSource *source) {
      __strong __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      if (source == nil) {
        NSLog(@"Could not load worker");
        return;
      }

      __weak __typeof(self) weakSelf = self;
      strongSelf->_isLoading = NO;
      [strongSelf runAsync:^(RUNTIME rt) {
#if RNWW_USE_HERMES
        std::string script(static_cast<const char*>(source.data.bytes),
                           source.data.length);
        rt->evaluateJavaScript(std::make_shared<StringBuffer>(script),
                               url.absoluteString.UTF8String);
#else
        NSString *script = [[NSString alloc] initWithData:source.data
                                                 encoding:NSUTF8StringEncoding];
        [rt evaluateScript:script
             withSourceURL:url];
#endif
      } onComplete:^() {
        __strong __typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
          return;
        }

        [strongSelf dispatchMessagesIfNeeded];
      }];
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
#if RNWW_USE_HERMES
  _runtime->watchTimeLimit(0);
#endif
  _runtime = nil;
}

- (void)runAsync:(void (^)(RUNTIME))block
      onComplete:(nullable void (^)())onComplete
{
  __weak __typeof(self) weakSelf = self;
  dispatch_async(_queue, ^{
    __strong __typeof(self) strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }

    NSString * _Nullable errorMessage = nil;

    try {
      RUNTIME runtime = strongSelf->_runtime;
      if (runtime != nil) {
        block(runtime);
      } else {
        errorMessage = @"Worker was terminated";
      }
    } catch (...) {
      // FIXME - can't figure out what the exception type is
      // It comes both from JS exceptions
      // And if you call abortExecution
      // NB - this is only for Hermes
      errorMessage = @"Unknown error";
    }

    if (errorMessage != nil) {
      [strongSelf.delegate didReceiveError:strongSelf
                                   message:errorMessage];
    }

    if (onComplete != nil) {
      onComplete();
    }
  });
}

- (void)runAsync:(void (^)(RUNTIME))block
{
  [self runAsync:block onComplete:nil];
}

- (void)dispatchMessage:(NSString *)message
{
  [self runAsync:^(RUNTIME rt) {
#if RNWW_USE_HERMES
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

    onMessage.call(*rt, event, 1);
#else
    JSValue *onMessage = rt[@"onmessage"];
    if (onMessage.isUndefined || onMessage.isNull) {
      return;
    }

    id event = @{ @"data": message };
    [onMessage callWithArguments:@[event]];
#endif
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
  if (!_isLoading) {
    [self dispatchMessagesIfNeeded];
    [self dispatchMessage:message];
  } else if (_pendingEvents != nil) {
    [_pendingEvents addObject:message];
  } else {
    _pendingEvents = [[NSMutableArray alloc] initWithObjects:message, nil];
  }
}

#if RNWW_USE_HERMES
- (void)abortExecution
{
  _runtime->asyncTriggerTimeout();
}
#else
RCT_NOT_IMPLEMENTED(- (void)abortExecution)
#endif

@end
