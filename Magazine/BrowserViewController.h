#import <UIKit/UIKit.h>

// Simple in-app browser used for external links.
@interface BrowserViewController : UIViewController <UIWebViewDelegate>
- (id)initWithURL:(NSURL *)url;
@end
