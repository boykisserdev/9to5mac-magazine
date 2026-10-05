#import <UIKit/UIKit.h>
#import "Article.h"

@interface ArticleCell : UITableViewCell
@property (nonatomic, strong) UIImageView *thumb;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, copy) NSString *imageURL;
- (void)configureWithArticle:(Article *)article;
@end
