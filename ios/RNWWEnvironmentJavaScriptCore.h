#import "RNWWEnvironment.h"
#import "RNWWSelf.h"

#import <JavaScriptCore/JavaScriptCore.h>

@interface RNWWEnvironmentJavaScriptCore : NSObject <RNWWEnviromnent>

@property (nonatomic, weak) id<RNWWEnviromnentDelegate> delegate;
@property (nonatomic, copy) NSNumber *threadId;
@property (nonatomic, copy) NSURL *url;

- (instancetype)initWithThreadId:(NSNumber *)threadId
                             url:(NSURL *)url;

@end
