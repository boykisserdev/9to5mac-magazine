#import <UIKit/UIKit.h>
#import "Article.h"

// Shared base for the three lists: Articles, Search, Saved.
@interface ArticleListViewController : UITableViewController
@property (nonatomic, strong) NSMutableArray *articles;
- (void)setFooterMessage:(NSString *)text;
@end
