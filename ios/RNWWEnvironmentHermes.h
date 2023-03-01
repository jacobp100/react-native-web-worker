#import "RNWWEnvironment.h"

@interface RNWWEnvironmentHermes : NSObject <RNWWEnviromnent>

@property (nonatomic, weak) id<RNWWEnviromnentDelegate> delegate;
@property (nonatomic, copy) NSNumber *threadId;

- (instancetype)initWithThreadId:(NSNumber *)threadId
                             url:(NSURL *)url;

@end
