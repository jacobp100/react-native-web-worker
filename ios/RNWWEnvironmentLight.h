#import "RNWWEnvironment.h"

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

@interface RNWWEnvironmentLight : NSObject <RNWWEnviromnent>

@property (nonatomic, weak) id<RNWWEnviromnentDelegate> delegate;
@property (nonatomic, copy) NSNumber *threadId;

- (instancetype)initWithThreadId:(NSNumber *)threadId
                             url:(NSURL *)url;

@end
