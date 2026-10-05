#import "ArticleLoader.h"
#import "FeedParser.h"
#import "Config.h"

static NSString * const kUserAgent =
    @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/536.26.17 (KHTML, like Gecko) Version/6.0.2 Safari/536.26.17";

static NSString *Strip(NSString *s, NSString *pattern) {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern
        options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
          error:nil];
    return [re stringByReplacingMatchesInString:s options:0
                                          range:NSMakeRange(0, s.length) withTemplate:@""];
}

static NSString *FirstGroup(NSString *s, NSString *pattern) {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern
        options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
          error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:s options:0 range:NSMakeRange(0, s.length)];
    if (!m || m.numberOfRanges < 2) return nil;
    return [s substringWithRange:[m rangeAtIndex:1]];
}

// Approximate length of the visible text inside a piece of HTML.
static NSInteger TextLength(NSString *html) {
    NSInteger n = 0;
    BOOL inTag = NO;
    for (NSUInteger i = 0; i < html.length; i++) {
        unichar c = [html characterAtIndex:i];
        if (c == '<') inTag = YES;
        else if (c == '>') inTag = NO;
        else if (!inTag) n++;
    }
    return n;
}

@implementation ArticleLoader

#pragma mark - Network

+ (void)fetchData:(NSURL *)url completion:(void (^)(NSData *data))completion {
    static NSOperationQueue *q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = [NSOperationQueue new]; });

    NSMutableArray *urls = [NSMutableArray array];
    NSURL *down = [NSURL URLWithString:Downgrade(url.absoluteString)];
    if (down) [urls addObject:down];
    if (![urls containsObject:url]) [urls addObject:url];
    [self fetchFirstOf:urls index:0 queue:q completion:completion];
}

+ (void)fetchFirstOf:(NSArray *)urls index:(NSUInteger)i queue:(NSOperationQueue *)q
          completion:(void (^)(NSData *data))completion {
    if (i >= urls.count) { completion(nil); return; }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:urls[i]
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:25];
    [req setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
    [NSURLConnection sendAsynchronousRequest:req queue:q
                           completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
        NSInteger status = [r isKindOfClass:[NSHTTPURLResponse class]]
                         ? [(NSHTTPURLResponse *)r statusCode] : 0;
        if (!e && d.length && status == 200) completion(d);
        else [self fetchFirstOf:urls index:i + 1 queue:q completion:completion];
    }];
}

#pragma mark - Public

+ (void)loadFullArticle:(Article *)a completion:(void (^)(BOOL ok))completion {
    if (a.postID.length) {
        // 1) WordPress REST API: returns the clean article HTML.
        NSString *u = [NSString stringWithFormat:@"%@wp-json/wp/v2/posts/%@?_fields=content",
                       kSiteURL, a.postID];
        [self fetchData:[NSURL URLWithString:u] completion:^(NSData *data) {
            NSString *html = nil;
            if (data) {
                id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json isKindOfClass:[NSDictionary class]]) {
                    id content = json[@"content"];
                    if ([content isKindOfClass:[NSDictionary class]]) html = content[@"rendered"];
                }
            }
            if ([html isKindOfClass:[NSString class]] && TextLength(html) > 80) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    a.html = html;
                    a.full = YES;
                    completion(YES);
                });
            } else {
                [self scrape:a completion:completion];   // 2) fall back to the article page
            }
        }];
    } else {
        [self scrape:a completion:completion];
    }
}

#pragma mark - Page scraping fallback

+ (void)scrape:(Article *)a completion:(void (^)(BOOL ok))completion {
    NSURL *url = [NSURL URLWithString:a.link];
    if (!url) { dispatch_async(dispatch_get_main_queue(), ^{ completion(NO); }); return; }

    [self fetchData:url completion:^(NSData *data) {
        NSString *page = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        NSString *body = page ? [self extractBody:page] : nil;

        NSString *title = nil, *image = nil;
        NSDate *date = nil;
        if (body.length) {
            NSString *h1 = FirstGroup(page, @"<h1[^>]*>(.*?)</h1>");
            if (!h1.length) h1 = FirstGroup(page, @"<title[^>]*>(.*?)</title>");
            if (h1.length) {
                h1 = [FeedParser decodeEntities:Strip(h1, @"<[^>]+>")];
                h1 = [h1 stringByReplacingOccurrencesOfString:@" - 9to5Mac" withString:@""];
                title = [h1 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }
            NSString *og = FirstGroup(page, @"property=\"og:image\"[^>]*content=\"([^\"]+)\"");
            if (og.length) image = [FeedParser decodeEntities:og];

            NSString *ds = FirstGroup(page, @"article:published_time\"[^>]*content=\"([^\"]+)\"");
            if (ds.length) {
                NSRegularExpression *re = [NSRegularExpression
                    regularExpressionWithPattern:@"([+-]\\d\\d):(\\d\\d)$" options:0 error:nil];
                ds = [re stringByReplacingMatchesInString:ds options:0
                                                    range:NSMakeRange(0, ds.length)
                                             withTemplate:@"$1$2"];
                NSDateFormatter *f = [NSDateFormatter new];
                f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
                f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
                date = [f dateFromString:ds];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (body.length) {
                a.html = body;
                a.full = YES;
                if (!a.title.length && title.length) a.title = title;
                if (!a.imageURL.length && image.length) a.imageURL = image;
                if (!a.date && date) a.date = date;
                completion(YES);
            } else {
                completion(NO);
            }
        });
    }];
}

// Finds the element that holds most of the paragraph text of the page (the article body).
+ (NSString *)extractBody:(NSString *)page {
    NSString *s = page;
    s = Strip(s, @"<!--.*?-->");
    s = Strip(s, @"<script\\b.*?</script>");
    s = Strip(s, @"<style\\b.*?</style>");
    s = Strip(s, @"<noscript\\b.*?</noscript>");
    s = Strip(s, @"<svg\\b.*?</svg>");

    NSSet *voids = [NSSet setWithObjects:@"img", @"br", @"hr", @"input", @"meta", @"link",
                    @"source", @"area", @"base", @"col", @"embed", @"param", @"track", @"wbr", nil];
    NSSet *containers = [NSSet setWithObjects:@"div", @"article", @"section", @"main", nil];

    NSRegularExpression *tagRe = [NSRegularExpression
        regularExpressionWithPattern:@"<(/?)([a-zA-Z][a-zA-Z0-9]*)\\b[^>]*?(/?)>" options:0 error:nil];

    NSMutableArray *stack = [NSMutableArray array];
    NSInteger bestScore = 0;
    NSRange bestRange = NSMakeRange(NSNotFound, 0);

    for (NSTextCheckingResult *m in [tagRe matchesInString:s options:0 range:NSMakeRange(0, s.length)]) {
        BOOL closing = [m rangeAtIndex:1].length > 0;
        NSString *name = [[s substringWithRange:[m rangeAtIndex:2]] lowercaseString];
        BOOL selfClose = [m rangeAtIndex:3].length > 0;

        if (!closing) {
            if (selfClose || [voids containsObject:name]) continue;
            if ([name isEqualToString:@"p"] && stack.count &&
                [[stack.lastObject objectForKey:@"name"] isEqualToString:@"p"]) {
                [stack removeLastObject];   // <p> implicitly closes a previous <p>
            }
            NSMutableDictionary *el = [NSMutableDictionary dictionary];
            el[@"name"] = name;
            el[@"inner"] = @(NSMaxRange(m.range));
            el[@"score"] = @0;
            [stack addObject:el];
        } else {
            NSInteger idx = -1;
            for (NSInteger i = (NSInteger)stack.count - 1; i >= 0; i--) {
                if ([[stack[i] objectForKey:@"name"] isEqualToString:name]) { idx = i; break; }
            }
            if (idx < 0) continue;
            while ((NSInteger)stack.count - 1 > idx) [stack removeLastObject];

            NSMutableDictionary *el = stack.lastObject;
            [stack removeLastObject];
            NSUInteger inner = [el[@"inner"] unsignedIntegerValue];
            NSUInteger end = m.range.location;
            if (end < inner) continue;

            if ([name isEqualToString:@"p"]) {
                NSInteger len = TextLength([s substringWithRange:NSMakeRange(inner, end - inner)]);
                if (len > 25 && stack.count) {
                    NSMutableDictionary *parent = stack.lastObject;
                    parent[@"score"] = @([parent[@"score"] integerValue] + len);
                }
            } else if ([containers containsObject:name]) {
                NSInteger score = [el[@"score"] integerValue];
                if (score > bestScore) {
                    bestScore = score;
                    bestRange = NSMakeRange(inner, end - inner);
                }
            }
        }
    }
    if (bestRange.location == NSNotFound || bestScore < 120) return nil;

    NSString *body = [s substringWithRange:bestRange];

    // Cut off the site footer that follows the article text.
    NSArray *markers = @[@"google.com/preferences/source", @"FTC: We use",
                         @"You\u2019re reading 9to5Mac", @"You're reading 9to5Mac"];
    NSUInteger cut = body.length;
    for (NSString *mk in markers) {
        NSRange r = [body rangeOfString:mk];
        if (r.location != NSNotFound && r.location < cut) cut = r.location;
    }
    if (cut < body.length) {
        NSUInteger start = 0;
        for (NSString *tag in @[@"<p", @"<div", @"<a ", @"<figure"]) {
            NSRange r = [body rangeOfString:tag options:NSBackwardsSearch
                                      range:NSMakeRange(0, cut)];
            if (r.location != NSNotFound && r.location > start) start = r.location;
        }
        body = [body substringToIndex:start];
    }
    return body;
}

@end
