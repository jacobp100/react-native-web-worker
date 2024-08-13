#import "RNWWEnvironment.h"

#if __has_include(<hermes/hermes.h>)
#define RNWW_USE_HERMES 1
#else
#define RNWW_USE_HERMES 0
#endif

@interface RNWWEnvironmentLight : NSObject <RNWWEnvironment>

@property (nonatomic, weak) id<RNWWEnvironmentDelegate> delegate;
@property (nonatomic, copy) NSNumber *threadId;

- (instancetype)initWithThreadId:(NSNumber *)threadId
                             url:(NSURL *)url;

@end
