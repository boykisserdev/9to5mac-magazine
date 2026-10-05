#import "ArticlesViewController.h"
#import "ArticleStore.h"
#import "FeedParser.h"
#import "Config.h"

@interface ArticlesViewController ()
@property (nonatomic) NSInteger page;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL hasMore;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation ArticlesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"9to5Mac";

    self.articles = [[[ArticleStore shared] cachedFeed] mutableCopy];
    self.page = 1;
    self.hasMore = YES;

    self.spinner = [[UIActivityIndicatorView alloc]
                    initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.frame = CGRectMake(0, 0, 320, 50);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh)
                  forControlEvents:UIControlEventValueChanged];

    [self refresh];
}

- (NSURL *)URLForPage:(NSInteger)page {
    NSString *u = page <= 1 ? kFeedURL
                            : [NSString stringWithFormat:@"%@?paged=%ld", kFeedURL, (long)page];
    return [NSURL URLWithString:u];
}

- (void)showSpinner:(BOOL)show {
    if (show) { self.tableView.tableFooterView = self.spinner; [self.spinner startAnimating]; }
    else      { [self.spinner stopAnimating]; self.tableView.tableFooterView = nil; }
}

#pragma mark - Loading

- (void)refresh {
    if (self.loading) { [self.refreshControl endRefreshing]; return; }
    self.loading = YES;
    if (!self.articles.count) [self showSpinner:YES];

    [FeedParser fetchURL:[self URLForPage:1] completion:^(NSArray *items, NSInteger status, NSError *err) {
        self.loading = NO;
        [self.refreshControl endRefreshing];
        [self showSpinner:NO];
        if (items.count) {
            self.articles = [items mutableCopy];
            self.page = 1;
            self.hasMore = YES;
            [[ArticleStore shared] setCachedFeed:self.articles];
            [self.tableView reloadData];
        } else if (!self.articles.count) {
            [[[UIAlertView alloc] initWithTitle:@"Couldn't load the feed"
                                        message:@"Check your internet connection or the feed address in Config.h."
                                       delegate:nil cancelButtonTitle:@"OK"
                              otherButtonTitles:nil] show];
        }
    }];
}

- (void)loadMore {
    if (self.loading || !self.hasMore || !self.articles.count) return;
    self.loading = YES;
    [self showSpinner:YES];
    NSInteger next = self.page + 1;

    [FeedParser fetchURL:[self URLForPage:next] completion:^(NSArray *items, NSInteger status, NSError *err) {
        self.loading = NO;
        [self showSpinner:NO];
        if (!items) {
            if (status == 404) self.hasMore = NO;   // no more pages
            return;                                  // network error: try again on the next scroll
        }
        NSMutableSet *known = [NSMutableSet set];
        for (Article *a in self.articles) [known addObject:a.link];
        NSUInteger added = 0;
        for (Article *a in items) {
            if (![known containsObject:a.link]) { [self.articles addObject:a]; added++; }
        }
        if (added == 0) { self.hasMore = NO; return; }
        self.page = next;
        [self.tableView reloadData];
    }];
}

- (void)tableView:(UITableView *)t willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.row >= (NSInteger)self.articles.count - 3) [self loadMore];
}

@end
