@protocol RNWWEnvironmentDelegate;

@protocol RNWWEnvironment <NSObject>

@property (nonatomic, weak) id<RNWWEnvironmentDelegate> delegate;
@property (nonatomic, copy) NSNumber *threadId;

- (void)invalidate;

- (void)postMessage:(NSString *)message;
- (void)abortExecution;

@end

@protocol RNWWEnvironmentDelegate <NSObject>

- (void)didReceiveMessage:(id<RNWWEnvironment>)sender
                     data:(NSString *)data;

- (void)didReceiveError:(id<RNWWEnvironment>)sender
                message:(NSString *)message
                   name:(NSString *)name;

@end
