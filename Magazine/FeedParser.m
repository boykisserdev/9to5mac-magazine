#import "FeedParser.h"

@interface FeedParser ()
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) Article *cur;
@property (nonatomic, strong) NSMutableString *buf;
@property (nonatomic, copy) NSString *desc;
@end

@implementation FeedParser

+ (NSArray *)articlesFromData:(NSData *)data {
    FeedParser *p = [FeedParser new];
    p.items = [NSMutableArray array];
    NSXMLParser *x = [[NSXMLParser alloc] initWithData:data];
    x.delegate = p;
    [x parse];
    return p.items;
}

+ (void)fetchURL:(NSURL *)url
      completion:(void (^)(NSArray *, NSInteger, NSError *))completion {
    static NSOperationQueue *q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = [NSOperationQueue new]; });

    NSURLRequest *req = [NSURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                     timeoutInterval:20];
    [NSURLConnection sendAsynchronousRequest:req queue:q
                           completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
        NSInteger status = [r isKindOfClass:[NSHTTPURLResponse class]]
                         ? [(NSHTTPURLResponse *)r statusCode] : 0;
        NSArray *items = nil;
        if (!e && d && status == 200) items = [self articlesFromData:d];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(items, status, e); });
    }];
}

#pragma mark - Helpers

+ (NSString *)decodeEntities:(NSString *)s {
    if (!s.length) return s;
    NSMutableString *m = [s mutableCopy];
    NSRegularExpression *re = [NSRegularExpression
        regularExpressionWithPattern:@"&#(x[0-9a-fA-F]+|[0-9]+);" options:0 error:nil];
    NSArray *matches = [re matchesInString:m options:0 range:NSMakeRange(0, m.length)];
    for (NSTextCheckingResult *r in [matches reverseObjectEnumerator]) {
        NSString *num = [m substringWithRange:[r rangeAtIndex:1]];
        unsigned int code = 0;
        if ([num hasPrefix:@"x"]) {
            [[NSScanner scannerWithString:[num substringFromIndex:1]] scanHexInt:&code];
        } else {
            code = (unsigned int)[num intValue];
        }
        NSString *ch = [[NSString alloc] initWithBytes:&code length:4
                                              encoding:NSUTF32LittleEndianStringEncoding];
        if (ch) [m replaceCharactersInRange:r.range withString:ch];
    }
    [m replaceOccurrencesOfString:@"&nbsp;" withString:@" " options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"&apos;" withString:@"'" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, m.length)];
    return m;
}

static NSDate *ParseRSSDate(NSString *s) {
    static NSDateFormatter *f;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [NSDateFormatter new];
        f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        f.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss Z";
    });
    @synchronized (f) { return [f dateFromString:s]; }
}

static NSString *FirstImageInHTML(NSString *html) {
    if (!html.length) return nil;
    NSRegularExpression *re = [NSRegularExpression
        regularExpressionWithPattern:@"<img[^>]+src\\s*=\\s*[\"']([^\"']+)[\"']"
                             options:NSRegularExpressionCaseInsensitive error:nil];
    for (NSTextCheckingResult *m in [re matchesInString:html options:0
                                                  range:NSMakeRange(0, html.length)]) {
        NSString *u = [html substringWithRange:[m rangeAtIndex:1]];
        if (![u hasPrefix:@"data:"]) return [FeedParser decodeEntities:u];
    }
    return nil;
}

// The feed only contains a short excerpt that ends with a "more..." link.
// Remove that link and the hero image block (the reader draws the hero image itself).
static NSString *CleanExcerpt(NSString *html) {
    NSString *patterns[] = {
        @"<div[^>]*class=\"feat-image\"[^>]*>.*?</div>",
        @"<a[^>]*class=\"more-link\"[^>]*>.*?</a>"
    };
    NSString *out = html;
    for (int i = 0; i < 2; i++) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:patterns[i]
            options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
              error:nil];
        out = [re stringByReplacingMatchesInString:out options:0
                                             range:NSMakeRange(0, out.length) withTemplate:@""];
    }
    return out;
}

#pragma mark - NSXMLParserDelegate
// Without namespace processing NSXMLParser gives the whole name ("content:encoded")
// as elementName and nil as qualifiedName, so always compare elementName.

- (void)parser:(NSXMLParser *)p didStartElement:(NSString *)el namespaceURI:(NSString *)ns
 qualifiedName:(NSString *)qn attributes:(NSDictionary *)attrs {
    self.buf = [NSMutableString string];
    if ([el isEqualToString:@"item"]) {
        self.cur = [Article new];
        self.desc = nil;
        return;
    }
    if (!self.cur) return;

    NSString *url = attrs[@"url"];
    if (url.length && !self.cur.imageURL) {
        if ([el isEqualToString:@"media:thumbnail"]) {
            self.cur.imageURL = [FeedParser decodeEntities:url];
        } else if ([el isEqualToString:@"media:content"] || [el isEqualToString:@"enclosure"]) {
            NSString *t = attrs[@"type"] ?: attrs[@"medium"] ?: @"image";
            if ([t hasPrefix:@"image"]) self.cur.imageURL = [FeedParser decodeEntities:url];
        }
    }
}

- (void)parser:(NSXMLParser *)p foundCharacters:(NSString *)s {
    [self.buf appendString:s];
}

- (void)parser:(NSXMLParser *)p foundCDATA:(NSData *)d {
    NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    if (s) [self.buf appendString:s];
}

- (void)parser:(NSXMLParser *)p didEndElement:(NSString *)el namespaceURI:(NSString *)ns
 qualifiedName:(NSString *)qn {
    if (!self.cur) return;
    NSString *trim = [self.buf stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([el isEqualToString:@"title"]) {
        self.cur.title = [FeedParser decodeEntities:trim];
    } else if ([el isEqualToString:@"link"]) {
        if (!self.cur.link.length) self.cur.link = trim;
    } else if ([el isEqualToString:@"pubDate"]) {
        self.cur.date = ParseRSSDate(trim);
    } else if ([el isEqualToString:@"post-id"]) {
        self.cur.postID = trim;
    } else if ([el isEqualToString:@"guid"]) {
        if (!self.cur.postID.length) {
            NSRange r = [trim rangeOfString:@"?p="];
            if (r.location != NSNotFound) self.cur.postID = [trim substringFromIndex:NSMaxRange(r)];
        }
    } else if ([el isEqualToString:@"description"]) {
        self.desc = [self.buf copy];
    } else if ([el isEqualToString:@"content:encoded"]) {
        self.cur.html = [self.buf copy];
    } else if ([el isEqualToString:@"item"]) {
        NSString *html = self.cur.html.length ? self.cur.html : (self.desc ?: @"");
        if (!self.cur.imageURL) self.cur.imageURL = FirstImageInHTML(html);
        self.cur.html = CleanExcerpt(html);
        if (self.cur.title.length && self.cur.link.length) [self.items addObject:self.cur];
        self.cur = nil;
    }
}

@end
