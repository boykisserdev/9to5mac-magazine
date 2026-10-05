#import "ArticleListViewController.h"
#import "ArticleCell.h"
#import "ArticleViewController.h"

@implementation ArticleListViewController

- (id)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        self.articles = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 100;
    self.navigationItem.backBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered
                                        target:nil action:nil];
}

- (void)setFooterMessage:(NSString *)text {
    if (!text.length) { self.tableView.tableFooterView = nil; return; }
    UILabel *l = [[UILabel alloc] initWithFrame:
                  CGRectMake(0, 0, self.tableView.bounds.size.width, 90)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.textAlignment = NSTextAlignmentCenter;
    l.numberOfLines = 0;
    l.font = [UIFont systemFontOfSize:15];
    l.textColor = [UIColor grayColor];
    l.backgroundColor = [UIColor clearColor];
    l.text = text;
    self.tableView.tableFooterView = l;
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return self.articles.count;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    ArticleCell *c = [t dequeueReusableCellWithIdentifier:@"article"];
    if (!c) c = [[ArticleCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:@"article"];
    [c configureWithArticle:self.articles[ip.row]];
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    [self.navigationController pushViewController:
        [[ArticleViewController alloc] initWithArticle:self.articles[ip.row]] animated:YES];
}

@end
