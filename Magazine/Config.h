#import <Foundation/Foundation.h>

// Feed and site. If HTTPS does not work on iOS 6, put your own proxy address here.
#define kFeedURL @"http://9to5mac.com/feed/"
#define kSiteURL @"http://9to5mac.com/"

// iOS 6 does not know modern TLS certificates, so image and feed URLs are
// rewritten from https:// to http://. Set to 0 to disable.
#define kDowngradeHTTPS 1

static inline NSString *Downgrade(NSString *s) {
#if kDowngradeHTTPS
    return [s stringByReplacingOccurrencesOfString:@"https://" withString:@"http://"];
#else
    return s;
#endif
}
