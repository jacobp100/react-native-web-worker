#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>

@protocol RNWWSelfDelegate <NSObject>
- (void)didReceiveMessage:(id)sender
                  message:(NSString *)message;
- (void)didReceiveError:(id)sender
                message:(NSString *)message;
@end

@interface RNWWSelf : RCTEventEmitter <RCTBridgeModule>
@property (nonatomic, strong) NSNumber *threadId;
@property (nonatomic, weak) id<RNWWSelfDelegate> delegate;
- (void)postMessage:(NSString *)message;
@end
