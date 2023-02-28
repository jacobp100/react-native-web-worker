#import "RNWWEnvironmentJavaScriptCore.h"

#import <React/RCTJavaScriptLoader.h>
#import <JavaScriptCore/JavaScriptCore.h>

@implementation RNWWEnvironmentJavaScriptCore {
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
    self.url = url;

    _isLoading = YES;

    _context = [[JSContext alloc] init];

    [_context.globalObject setValue:_context.globalObject
                        forProperty:@"self"];

    __weak RNWWEnvironmentJavaScriptCore *weakSelf = self;
    id postMessage = ^(NSString *message) {
      RNWWEnvironmentJavaScriptCore *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      [strongSelf->_delegate didReceiveMessage:strongSelf
                                       message:message];
    };
    [_context.globalObject setValue:postMessage
                        forProperty:@"postMessage"];
    _context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
      RNWWEnvironmentJavaScriptCore *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      NSString *message = [[exception valueForProperty:@"message"] toString];
      [strongSelf->_delegate didReceiveError:strongSelf
                                     message:message];
    };

    [RCTJavaScriptLoader loadBundleAtURL:url
                              onProgress:^(RCTLoadingProgress *progressData) {}
                              onComplete:^(NSError *error, RCTSource *source) {
      RNWWEnvironmentJavaScriptCore *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      NSString *script = [[NSString alloc] initWithData:source.data
                                               encoding:NSUTF8StringEncoding];
      strongSelf->_isLoading = NO;
      [strongSelf->_context evaluateScript:script
                             withSourceURL:strongSelf.url];
      [strongSelf dispatchMessagesIfNeeded];
    }];
  }
  return self;
}

- (void)invalidate
{
  _context = nil;
}

- (void)dispatchMessage:(NSString *)message
{
  JSValue *onMessage = [_context.globalObject valueForProperty:@"onmessage"];
  if (onMessage.isUndefined || onMessage.isNull) {
    return;
  }

  JSValue *event = [JSValue valueWithObject:@{ @"data": message }
                                  inContext:_context];
  [onMessage callWithArguments:@[event]];
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
  } else if (_pendingEvents) {
    [_pendingEvents addObject:message];
  } else {
    _pendingEvents = [[NSMutableArray alloc] initWithObjects:message, nil];
  }
}

@end
