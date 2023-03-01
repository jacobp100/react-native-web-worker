#import "RNWWEnvironmentJavaScriptCore.h"

#import <React/RCTJavaScriptLoader.h>
#import <JavaScriptCore/JavaScriptCore.h>

@implementation RNWWEnvironmentJavaScriptCore {
  dispatch_queue_t _queue;
  JSContext *_context;
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
    _queue = dispatch_queue_create("javascript-core", qos);
    _context = [JSContext new];

    __weak typeof(self) weakSelf = self;

    _context[@"self"] = _context.globalObject;
    _context[@"postMessage"] = ^(NSString *message) {
      __strong typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      [strongSelf->_delegate didReceiveMessage:strongSelf
                                       message:message];
    };
    _context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
      __strong typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      JSValue *messageValue = exception[@"message"];
      NSString *message = messageValue.isString
      ? messageValue.toString
      : @"Unknown error";
      [strongSelf->_delegate didReceiveError:strongSelf
                                     message:message];
    };

    [RCTJavaScriptLoader loadBundleAtURL:url
                              onProgress:^(RCTLoadingProgress *progressData) {}
                              onComplete:^(NSError *error, RCTSource *source) {
      __strong typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      strongSelf->_isLoading = NO;
      [strongSelf runAsync:^(JSContext *context) {
        NSString *script = [[NSString alloc] initWithData:source.data
                                                 encoding:NSUTF8StringEncoding];
        [context evaluateScript:script
                  withSourceURL:url];
      }];
      [strongSelf dispatchMessagesIfNeeded];
    }];
  }
  return self;
}

- (void)invalidate
{
  _context = nil;
}

- (void)runAsync:(void (^)(JSContext *))block
{
  __weak typeof(self) weakSelf = self;
  dispatch_async(_queue, ^{
    __strong typeof(self) strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }

    JSContext *context = strongSelf->_context;
    if (context == nil) {
      return;
    }

    block(context);
  });
}

- (void)dispatchMessage:(NSString *)message
{
  [self runAsync:^(JSContext *context) {
    JSValue *onMessage = context[@"onmessage"];
    if (onMessage.isUndefined || onMessage.isNull) {
      return;
    }

    id event = @{ @"data": message };
    [onMessage callWithArguments:@[event]];
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

@end
