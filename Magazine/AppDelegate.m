#import "AppDelegate.h"
#import "ArticlesViewController.h"
#import "SearchViewController.h"
#import "SavedViewController.h"
#import "SettingsViewController.h"

@implementation AppDelegate

// Tab bar icons are drawn in code (only the alpha channel is used by the tab bar).
static UIImage *MakeIcon(void (^draw)(CGContextRef ctx)) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor);
    draw(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static UIImage *ArticlesIcon(void) {
    return MakeIcon(^(CGContextRef ctx) {
        for (int i = 0; i < 3; i++) {
            CGFloat y = 4 + i * 9;
            CGContextFillRect(ctx, CGRectMake(2, y, 7, 7));
            CGContextFillRect(ctx, CGRectMake(12, y + 1, 16, 2));
            CGContextFillRect(ctx, CGRectMake(12, y + 5, 16, 2));
        }
    });
}

static UIImage *SearchIcon(void) {
    return MakeIcon(^(CGContextRef ctx) {
        CGContextSetLineWidth(ctx, 3);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(4, 4, 16, 16));
        CGContextSetLineWidth(ctx, 4);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextMoveToPoint(ctx, 18, 18);
        CGContextAddLineToPoint(ctx, 26, 26);
        CGContextStrokePath(ctx);
    });
}

static UIImage *SavedIcon(void) {
    return MakeIcon(^(CGContextRef ctx) {
        CGContextMoveToPoint(ctx, 8, 3);
        CGContextAddLineToPoint(ctx, 22, 3);
        CGContextAddLineToPoint(ctx, 22, 27);
        CGContextAddLineToPoint(ctx, 15, 21);
        CGContextAddLineToPoint(ctx, 8, 27);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    });
}

static UIImage *SettingsIcon(void) {
    return MakeIcon(^(CGContextRef ctx) {
        CGFloat ys[3] = {7, 15, 23};
        CGFloat xs[3] = {10, 20, 12};
        CGContextSetLineWidth(ctx, 2.5);
        for (int i = 0; i < 3; i++) {
            CGContextMoveToPoint(ctx, 3, ys[i]);
            CGContextAddLineToPoint(ctx, 27, ys[i]);
            CGContextStrokePath(ctx);
            CGContextSetBlendMode(ctx, kCGBlendModeClear);
            CGContextFillEllipseInRect(ctx, CGRectMake(xs[i] - 5.5, ys[i] - 5.5, 11, 11));
            CGContextSetBlendMode(ctx, kCGBlendModeNormal);
            CGContextFillEllipseInRect(ctx, CGRectMake(xs[i] - 3.5, ys[i] - 3.5, 7, 7));
        }
    });
}

static UINavigationController *Nav(UIViewController *root, NSString *title, UIImage *icon, NSInteger tag) {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:icon tag:tag];
    return nav;
}

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[
        Nav([[ArticlesViewController alloc] initWithStyle:UITableViewStylePlain],
            @"Articles", ArticlesIcon(), 0),
        Nav([[SearchViewController alloc] initWithStyle:UITableViewStylePlain],
            @"Search", SearchIcon(), 1),
        Nav([[SavedViewController alloc] initWithStyle:UITableViewStylePlain],
            @"Saved", SavedIcon(), 2),
        Nav([[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped],
            @"Settings", SettingsIcon(), 3)
    ];

    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
