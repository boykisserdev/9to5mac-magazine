#import "SearchViewController.h"
#import "ArticleStore.h"
#import "FeedParser.h"
#import "Config.h"

@interface SearchViewController ()
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy) NSString *currentQuery;
@end

@implementation SearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Search";

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search articles";
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.tableView.tableHeaderView = self.searchBar;
    [self setFooterMessage:@"Type a query and tap Search"];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.searchBar resignFirstResponder];
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text {
    if (!text.length) {
        self.currentQuery = nil;
        [self.articles removeAllObjects];
        [self.tableView reloadData];
        [self setFooterMessage:@"Type a query and tap Search"];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)bar {
    NSString *q = [bar.text stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!q.length) return;
    [bar resignFirstResponder];

    self.currentQuery = q;
    [self.articles removeAllObjects];
    [self.tableView reloadData];
    [self setFooterMessage:@"Searching..."];

    NSString *esc = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault, (__bridge CFStringRef)q, NULL,
        CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"%@?s=%@&feed=rss2", kSiteURL, esc]];

    [FeedParser fetchURL:url completion:^(NSArray *items, NSInteger status, NSError *err) {
        if (![self.currentQuery isEqualToString:q]) return;   // reply to an outdated query
        if (items) {
            self.articles = [items mutableCopy];
            [self.tableView reloadData];
            [self setFooterMessage:items.count ? nil : @"Nothing found"];
        } else {
            [self searchLocally:q];
        }
    }];
}

- (void)searchLocally:(NSString *)q {
    NSMutableArray *res = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSMutableArray *pool = [NSMutableArray arrayWithArray:[[ArticleStore shared] cachedFeed]];
    [pool addObjectsFromArray:[[ArticleStore shared] saved]];
    for (Article *a in pool) {
        if ([seen containsObject:a.link]) continue;
        BOOL hit = [a.title rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound
                || [a.html rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound;
        if (hit) { [res addObject:a]; [seen addObject:a.link]; }
    }
    self.articles = res;
    [self.tableView reloadData];
    [self setFooterMessage:res.count ? @"No connection: showing results from loaded articles"
                                     : @"No connection and nothing found in loaded articles"];
}

@end
