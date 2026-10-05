#import <Foundation/Foundation.h>
#import "Article.h"

@interface FeedParser : NSObject <NSXMLParserDelegate>
+ (NSArray *)articlesFromData:(NSData *)data;
+ (void)fetchURL:(NSURL *)url
      completion:(void (^)(NSArray *articles, NSInteger status, NSError *error))completion;
+ (NSString *)decodeEntities:(NSString *)s;
@end
