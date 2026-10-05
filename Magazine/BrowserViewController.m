#import "BrowserViewController.h"
#import "Config.h"

@interface BrowserViewController ()
@property (nonatomic, strong) NSURL *startURL;
@property (nonatomic, strong) UIWebView *web;
@property (nonatomic, strong) UIBarButtonItem *backItem;
@property (nonatomic, strong) UIBarButtonItem *forwardItem;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic) BOOL triedHTTP;
@end

@implementation BrowserViewController

- (id)initWithURL:(NSURL *)url {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.startURL = url;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)dealloc {
    self.web.delegate = nil;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = self.startURL.host;

    self.web = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.delegate = self;
    self.web.scalesPageToFit = YES;
    [self.view addSubview:self.web];

    self.spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];

    self.backItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered
                                                    target:self.web action:@selector(goBack)];
    self.forwardItem = [[UIBarButtonItem alloc] initWithTitle:@"Forward" style:UIBarButtonItemStyleBordered
                                                       target:self.web action:@selector(goForward)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *reload = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self.web action:@selector(reload)];
    UIBarButtonItem *safari = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(openInSafari)];
    [self setToolbarItems:@[self.backItem, self.forwardItem, flex, reload, safari] animated:NO];
    [self updateButtons];

    [self.web loadRequest:[NSURLRequest requestWithURL:self.startURL]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
}

- (void)updateButtons {
    self.backItem.enabled = self.web.canGoBack;
    self.forwardItem.enabled = self.web.canGoForward;
}

- (void)openInSafari {
    NSURL *u = self.web.request.URL ?: self.startURL;
    if (u) [[UIApplication sharedApplication] openURL:u];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)w shouldStartLoadWithRequest:(NSURLRequest *)req
 navigationType:(UIWebViewNavigationType)type {
    NSString *scheme = req.URL.scheme.lowercaseString;
    BOOL web = [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] ||
               [scheme isEqualToString:@"about"] || [scheme isEqualToString:@"data"] ||
               [scheme isEqualToString:@"file"];
    if (!web) {
        [[UIApplication sharedApplication] openURL:req.URL];   // mailto:, tel:, itms-apps: ...
        return NO;
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)w {
    [self.spinner startAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)w {
    [self.spinner stopAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    NSString *t = [w stringByEvaluatingJavaScriptFromString:@"document.title"];
    if (t.length) self.title = t;
    [self updateButtons];
}

- (void)webView:(UIWebView *)w didFailLoadWithError:(NSError *)error {
    [self.spinner stopAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    if (error.code == NSURLErrorCancelled || error.code == 102) return;   // cancelled / interrupted

    // iOS 6 often cannot open modern HTTPS sites: retry once over http://
    NSURL *failed = error.userInfo[NSURLErrorFailingURLErrorKey] ?: w.request.URL;
    if (kDowngradeHTTPS && !self.triedHTTP && [failed.scheme isEqualToString:@"https"]) {
        self.triedHTTP = YES;
        NSURL *http = [NSURL URLWithString:Downgrade(failed.absoluteString)];
        if (http) { [w loadRequest:[NSURLRequest requestWithURL:http]]; return; }
    }
    self.title = @"Failed to load";
}

@end
