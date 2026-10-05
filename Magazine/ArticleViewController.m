#import "ArticleViewController.h"
#import "ArticleStore.h"
#import "ArticleLoader.h"
#import "BrowserViewController.h"
#import "Settings.h"
#import "Config.h"

static NSString *HTMLEscape(NSString *s) {
    s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
    return s;
}

// Only image sources are downgraded to http://; links keep their original address.
static NSString *DowngradeImages(NSString *html) {
#if kDowngradeHTTPS
    NSRegularExpression *re = [NSRegularExpression
        regularExpressionWithPattern:@"(src\\s*=\\s*[\"'])https://"
                             options:NSRegularExpressionCaseInsensitive error:nil];
    return [re stringByReplacingMatchesInString:html options:0
                                          range:NSMakeRange(0, html.length)
                                   withTemplate:@"$1http://"];
#else
    return html;
#endif
}

@interface ArticleViewController ()
@property (nonatomic, strong) Article *article;
@property (nonatomic, strong) UIWebView *web;
@property (nonatomic, strong) UIBarButtonItem *saveItem;
@property (nonatomic, strong) UIView *statusView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *statusSpinner;
@property (nonatomic, strong) NSURL *pendingURL;
@property (nonatomic, copy) NSString *loadedSignature;
@end

@implementation ArticleViewController

- (id)initWithArticle:(Article *)article {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.article = article;
    }
    return self;
}

- (void)dealloc {
    self.web.delegate = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - View

- (void)viewDidLoad {
    [super viewDidLoad];

    self.web = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.delegate = self;
    self.web.opaque = NO;
    [self.view addSubview:self.web];

    // Small status bar at the bottom ("Loading full article...")
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    self.statusView = [[UIView alloc] initWithFrame:CGRectMake(0, h - 34, w, 34)];
    self.statusView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.statusView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
    self.statusView.hidden = YES;
    self.statusSpinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.statusSpinner.frame = CGRectMake(10, 7, 20, 20);
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 0, w - 50, 34)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    [self.statusView addSubview:self.statusSpinner];
    [self.statusView addSubview:self.statusLabel];
    [self.view addSubview:self.statusView];

    self.saveItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleBordered
                                                    target:self action:@selector(toggleSave)];
    UIBarButtonItem *openItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                             target:self action:@selector(openOriginal)];
    self.navigationItem.rightBarButtonItems = @[openItem, self.saveItem];
    [self updateSaveButton];

    [self render];
    [self loadFullArticle];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateSaveButton];
    // Reader settings changed while this screen was in the background
    if (self.loadedSignature && ![self.loadedSignature isEqualToString:[Settings signature]]) {
        [self render];
    }
}

#pragma mark - Rendering

- (UIColor *)themeBackground {
    switch ([Settings theme]) {
        case 1:  return [UIColor colorWithRed:0.957 green:0.925 blue:0.847 alpha:1];
        case 2:  return [UIColor colorWithWhite:0.07 alpha:1];
        default: return [UIColor whiteColor];
    }
}

- (void)render {
    self.loadedSignature = [Settings signature];
    UIColor *bg = [self themeBackground];
    self.view.backgroundColor = bg;
    self.web.backgroundColor = bg;

    NSURL *base = self.article.link.length ? [NSURL URLWithString:self.article.link] : nil;
    [self.web loadHTMLString:[self documentHTML] baseURL:base];
}

- (NSString *)documentHTML {
    static const int sizes[4] = {16, 18, 20, 23};
    int size = sizes[MAX(0, MIN(3, (int)[Settings textSize]))];
    NSString *font = ([Settings fontStyle] == 0) ? @"Georgia,'Times New Roman',serif"
                                                 : @"Helvetica,Arial,sans-serif";
    NSString *bg, *fg, *link, *meta, *quote;
    switch ([Settings theme]) {
        case 1:  bg = @"#f4ecd8"; fg = @"#5b4636"; link = @"#8a5a2b"; meta = @"#9a8468"; quote = @"#c9b99a"; break;
        case 2:  bg = @"#121212"; fg = @"#dddddd"; link = @"#6cb2ff"; meta = @"#888888"; quote = @"#444444"; break;
        default: bg = @"#ffffff"; fg = @"#222222"; link = @"#1a6fd8"; meta = @"#888888"; quote = @"#cccccc"; break;
    }

    NSMutableString *css = [NSMutableString string];
    [css appendFormat:@"body{background:%@;color:%@;font-family:%@;font-size:%dpx;", bg, fg, font, size];
    [css appendString:@"line-height:1.5;margin:16px;word-wrap:break-word;-webkit-text-size-adjust:100%}"];
    [css appendString:@"h1{font:bold 24px/1.25 Helvetica,Arial,sans-serif;margin:0 0 6px}"];
    [css appendFormat:@".meta{font:13px Helvetica,Arial,sans-serif;color:%@;margin-bottom:16px}", meta];
    [css appendString:@"img,video,iframe,table{max-width:100%;height:auto}"];
    [css appendString:@".hero{display:block;width:100%;margin:0 0 16px}"];
    [css appendString:@"figure{margin:12px 0}figcaption,.wp-caption-text{font-size:13px;opacity:.7}"];
    [css appendFormat:@"a{color:%@}", link];
    [css appendString:@"pre,code{white-space:pre-wrap}"];
    [css appendFormat:@"blockquote{margin:12px 0;padding-left:12px;border-left:3px solid %@;opacity:.85}", quote];
    [css appendFormat:@"hr{border:0;border-top:1px solid %@}", quote];

    NSString *title = self.article.title.length ? self.article.title : @"Loading...";
    NSMutableString *h = [NSMutableString string];
    [h appendString:@"<html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"];
    [h appendFormat:@"<style>%@</style></head><body>", css];
    [h appendFormat:@"<h1>%@</h1>", HTMLEscape(title)];
    [h appendFormat:@"<div class=\"meta\">%@</div>", [self.article dateString]];

    NSString *hero = [self.article heroURL];
    if (hero.length && [hero rangeOfString:@".webp" options:NSCaseInsensitiveSearch].location == NSNotFound) {
        [h appendFormat:@"<img class=\"hero\" src=\"%@\">", HTMLEscape(Downgrade(hero))];
    }
    [h appendString:DowngradeImages(self.article.html ?: @"")];
    [h appendString:@"</body></html>"];
    return h;
}

#pragma mark - Full article

- (void)showStatus:(NSString *)text spinning:(BOOL)spinning {
    self.statusLabel.text = text;
    if (spinning) [self.statusSpinner startAnimating]; else [self.statusSpinner stopAnimating];
    self.statusView.hidden = NO;
}

- (void)hideStatus {
    self.statusView.hidden = YES;
    [self.statusSpinner stopAnimating];
}

- (void)loadFullArticle {
    if (self.article.full) return;
    [self showStatus:@"Loading full article..." spinning:YES];

    __weak ArticleViewController *weakSelf = self;
    [ArticleLoader loadFullArticle:self.article completion:^(BOOL ok) {
        ArticleViewController *s = weakSelf;
        if (!s) return;
        if (ok) {
            [[ArticleStore shared] updateSaved:s.article];
            [s hideStatus];
            [s render];
        } else {
            [s showStatus:@"Could not load the full article" spinning:NO];
            [s performSelector:@selector(hideStatus) withObject:nil afterDelay:4.0];
        }
    }];
}

#pragma mark - Buttons

- (void)updateSaveButton {
    self.saveItem.title = [[ArticleStore shared] isSaved:self.article] ? @"Saved" : @"Save";
}

- (void)toggleSave {
    [[ArticleStore shared] toggleSaved:self.article];
    [self updateSaveButton];
}

// The "action" button opens the original page, using the link setting from Settings.
- (void)openOriginal {
    NSURL *u = [NSURL URLWithString:self.article.link];
    if (u) [self openExternalURL:u];
}

#pragma mark - Links

- (BOOL)isArticleURL:(NSURL *)url {
    if (![url.host hasSuffix:@"9to5mac.com"]) return NO;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^/\\d{4}/\\d{2}/\\d{2}/"
                                                                        options:0 error:nil];
    NSString *path = url.path ?: @"";
    return [re numberOfMatchesInString:path options:0 range:NSMakeRange(0, path.length)] > 0;
}

- (void)handleLinkTap:(NSURL *)url {
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        [[UIApplication sharedApplication] openURL:url];   // mailto:, tel:, itms-apps: ...
        return;
    }
    if ([url.absoluteString rangeOfString:@"#more-"].location != NSNotFound) return;

    if ([self isArticleURL:url]) {
        // 9to5Mac article links open in the reader itself
        NSString *clean = [[url.absoluteString componentsSeparatedByString:@"#"] objectAtIndex:0];
        if ([clean isEqualToString:self.article.link]) return;
        Article *a = [Article new];
        a.link = clean;
        a.title = @"";
        a.html = @"";
        [self.navigationController pushViewController:
            [[ArticleViewController alloc] initWithArticle:a] animated:YES];
        return;
    }
    [self openExternalURL:url];
}

- (void)openExternalURL:(NSURL *)url {
    switch ([Settings linkMode]) {
        case LinkModeSafari:
            [[UIApplication sharedApplication] openURL:url];
            break;
        case LinkModeAsk: {
            self.pendingURL = url;
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:url.host
                                                               delegate:self
                                                      cancelButtonTitle:@"Cancel"
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:@"Open in the reader", @"Open in Safari", nil];
            [sheet showInView:self.view];
            break;
        }
        default:
            [self openInBrowser:url];
            break;
    }
}

- (void)openInBrowser:(NSURL *)url {
    [self.navigationController pushViewController:
        [[BrowserViewController alloc] initWithURL:url] animated:YES];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (!self.pendingURL) return;
    if (index == 0) [self openInBrowser:self.pendingURL];
    else if (index == 1) [[UIApplication sharedApplication] openURL:self.pendingURL];
    self.pendingURL = nil;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)w shouldStartLoadWithRequest:(NSURLRequest *)req
 navigationType:(UIWebViewNavigationType)type {
    if (type == UIWebViewNavigationTypeLinkClicked) {
        [self handleLinkTap:req.URL];
        return NO;
    }
    return YES;
}

@end
