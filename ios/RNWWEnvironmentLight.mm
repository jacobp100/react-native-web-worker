#import "RNWWEnvironmentLight.h"

#import <React/RCTDefines.h>
#import <React/RCTJavaScriptLoader.h>

#if RNWW_USE_HERMES
#define RUNTIME std::shared_ptr<HermesRuntime>
#else
#define RUNTIME JSContext *
#endif

typedef NS_ENUM(NSUInteger, QueuedEventType) {
  QueuedEventTypeMessage,
  QueuedEventTypeAbortExecution
};

@interface QueuedEvent : NSObject
@property (nonatomic, assign) QueuedEventType type;
@property (nonatomic, copy) NSString *message;
@end

@implementation QueuedEvent
@end

@implementation RNWWEnvironmentLight {
  RUNTIME _runtime;
  dispatch_queue_t _queue;
  // Messages queued here until the JS has loaded (lazily created)
  NSMutableArray<QueuedEvent *> *_pendingEvents;
  BOOL _jsInitialized;
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
    _jsInitialized = NO;
    dispatch_queue_attr_t qos = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                        QOS_CLASS_DEFAULT,
                                                                        -1);
    _queue = dispatch_queue_create("hermes", qos);

    __weak __typeof(self) weakSelf = self;

    _runtime = [RNWWEnvironmentLight initRuntime:^(NSString *data) {
      __strong __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      [strongSelf.delegate didReceiveMessage:strongSelf
                                        data:data];
    } onError:^(NSString *message) {
      __strong __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      [strongSelf.delegate didReceiveError:strongSelf
                                   message:message
                                      name:@"Error"];
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

        strongSelf->_jsInitialized = YES;
        [strongSelf dispatchEventsIfNeeded];
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

    NSString * _Nullable errorName = nil;
    NSString * _Nullable errorMessage = nil;

    RUNTIME rt = strongSelf->_runtime;
      try {
        if (rt != nil) {
          block(rt);
        } else {
            errorName = @"TimeoutError";
          errorMessage = @"Worker was terminated";
        }
    } catch (const JSError &e) {
      errorMessage = @(e.getMessage().data());

      try {
        std::string constructorName = e
          .value()
          .asObject(*rt)
          .getProperty(*rt, "constructor")
          .asObject(*rt)
          .getProperty(*rt, "name")
          .asString(*rt)
          .utf8(*rt);
        errorName = @(constructorName.data());
      } catch (...) {
      }
    } catch (const std::exception &e) {
      errorMessage = @(e.what());
    } catch (...) {
      errorMessage = @"Unknown error";
    }

    if (errorMessage != nil) {
      errorName = errorName ?: @"Error";
      [strongSelf.delegate didReceiveError:strongSelf
                                   message:errorMessage
                                      name:errorName];
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

- (void)dispatchAbortExecution
{
#if RNWW_USE_HERMES
  _runtime->asyncTriggerTimeout();
#endif
}

- (void)dispatchEventsIfNeeded
{
  if (!_pendingEvents) {
    return;
  }

  for (QueuedEvent *event in _pendingEvents) {
    switch (event.type) {
      case QueuedEventTypeMessage:
        [self dispatchMessage:event.message];
        break;
      case QueuedEventTypeAbortExecution:
        [self dispatchAbortExecution];
        break;
    }
  }

  [_pendingEvents removeAllObjects];
  _pendingEvents = nil;
}


- (void)postMessage:(NSString *)message
{
  if (_jsInitialized) {
    [self dispatchEventsIfNeeded];
    [self dispatchMessage:message];
  } else {
    _pendingEvents = _pendingEvents ?: [[NSMutableArray alloc] initWithCapacity:1];
    QueuedEvent *event = [QueuedEvent new];
    event.type = QueuedEventTypeMessage;
    event.message = message;
    [_pendingEvents addObject:event];
  }
}

#if RNWW_USE_HERMES
- (void)abortExecution
{
  if (_jsInitialized) {
    [self dispatchEventsIfNeeded];
    [self dispatchAbortExecution];
  } else {
    _pendingEvents = _pendingEvents ?: [[NSMutableArray alloc] initWithCapacity:1];
    QueuedEvent *event = [QueuedEvent new];
    event.type = QueuedEventTypeAbortExecution;
    [_pendingEvents addObject:event];
  }
}
#else
RCT_NOT_IMPLEMENTED(- (void)abortExecution)
#endif

@end
