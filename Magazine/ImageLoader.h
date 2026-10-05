#import <UIKit/UIKit.h>

@interface ImageLoader : NSObject
+ (UIImage *)cachedImageForURL:(NSString *)url;
+ (void)loadURL:(NSString *)url completion:(void (^)(UIImage *image))completion;
+ (void)clearCache;
@end
