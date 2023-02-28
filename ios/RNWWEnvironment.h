@protocol RNWWEnviromnentDelegate;

@protocol RNWWEnviromnent <NSObject>

@property (nonatomic, weak) id<RNWWEnviromnentDelegate> delegate;
@property (nonatomic, copy) NSNumber *threadId;
@property (nonatomic, copy) NSURL *url;

- (void)invalidate;

- (void)postMessage:(NSString *)message;

@end

@protocol RNWWEnviromnentDelegate <NSObject>

- (void)didReceiveMessage:(id<RNWWEnviromnent>)sender
                  message:(NSString *)message;

- (void)didReceiveError:(id<RNWWEnviromnent>)sender
                message:(NSString *)message;

@end
