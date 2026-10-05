#import <Foundation/Foundation.h>
#import "Article.h"

// The feed only contains an excerpt. This fetches the complete article text.
@interface ArticleLoader : NSObject
+ (void)loadFullArticle:(Article *)article completion:(void (^)(BOOL ok))completion;
@end
