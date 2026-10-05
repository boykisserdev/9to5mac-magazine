#import <Foundation/Foundation.h>
#import "Article.h"

@interface ArticleStore : NSObject
+ (ArticleStore *)shared;

// Saved articles (readable offline)
- (NSArray *)saved;
- (BOOL)isSaved:(Article *)a;
- (BOOL)toggleSaved:(Article *)a;   // YES if the article is now saved
- (void)removeSaved:(Article *)a;
- (void)updateSaved:(Article *)a;   // store the latest (e.g. full) text of a saved article

// Cache of the last loaded feed (for launching offline and offline search)
- (NSArray *)cachedFeed;
- (void)setCachedFeed:(NSArray *)articles;
@end
