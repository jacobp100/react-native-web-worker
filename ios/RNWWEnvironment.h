@protocol RNWWEnviromnentDelegate;

@protocol RNWWEnviromnent <NSObject>

@property (nonatomic, weak) id<RNWWEnviromnentDelegate> delegate;
@property (nonatomic, copy) NSNumber *threadId;

- (void)invalidate;

- (void)postMessage:(NSString *)message;
- (void)abortExecution;

@end

@protocol RNWWEnviromnentDelegate <NSObject>

- (void)didReceiveMessage:(id<RNWWEnviromnent>)sender
                  message:(NSString *)message;

- (void)didReceiveError:(id<RNWWEnviromnent>)sender
                message:(NSString *)message;

@end
