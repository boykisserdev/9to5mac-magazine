#import "SavedViewController.h"
#import "ArticleStore.h"

@implementation SavedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Saved";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.articles = [[[ArticleStore shared] saved] mutableCopy];
    [self.tableView reloadData];
    [self updateFooter];
}

- (void)updateFooter {
    [self setFooterMessage:self.articles.count ? nil
        : @"No saved articles yet.\nOpen an article and tap Save."];
}

- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip { return YES; }

- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)style
forRowAtIndexPath:(NSIndexPath *)ip {
    if (style != UITableViewCellEditingStyleDelete) return;
    [[ArticleStore shared] removeSaved:self.articles[ip.row]];
    [self.articles removeObjectAtIndex:ip.row];
    [t deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationFade];
    [self updateFooter];
}

@end
