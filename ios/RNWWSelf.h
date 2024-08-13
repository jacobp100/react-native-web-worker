#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>

@protocol RNWWSelfDelegate <NSObject>
- (void)didReceiveMessage:(id)sender
                     data:(NSString *)data;
- (void)didReceiveError:(id)sender
                message:(NSString *)message
                   name:(NSString *)name;
@end

@interface RNWWSelf : RCTEventEmitter <RCTBridgeModule>
@property (nonatomic, weak) id<RNWWSelfDelegate> delegate;
- (void)postMessage:(NSString *)message;
@end
