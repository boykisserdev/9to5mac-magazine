#import <UIKit/UIKit.h>
#import "Article.h"

@interface ArticleViewController : UIViewController <UIWebViewDelegate, UIActionSheetDelegate>
- (id)initWithArticle:(Article *)article;
@end
