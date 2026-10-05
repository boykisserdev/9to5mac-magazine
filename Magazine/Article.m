#import "Article.h"
#import "FeedParser.h"

@implementation Article

- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:self.title forKey:@"title"];
    [c encodeObject:self.link forKey:@"link"];
    [c encodeObject:self.html forKey:@"html"];
    [c encodeObject:self.imageURL forKey:@"imageURL"];
    [c encodeObject:self.postID forKey:@"postID"];
    [c encodeBool:self.full forKey:@"full"];
    [c encodeObject:self.date forKey:@"date"];
}

- (id)initWithCoder:(NSCoder *)d {
    if ((self = [super init])) {
        self.title = [d decodeObjectForKey:@"title"];
        self.link = [d decodeObjectForKey:@"link"];
        self.html = [d decodeObjectForKey:@"html"];
        self.imageURL = [d decodeObjectForKey:@"imageURL"];
        self.postID = [d decodeObjectForKey:@"postID"];
        self.full = [d decodeBoolForKey:@"full"];
        self.date = [d decodeObjectForKey:@"date"];
    }
    return self;
}

- (NSString *)dateString {
    if (!self.date) return @"";
    static NSDateFormatter *f;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [NSDateFormatter new];
        f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        f.dateStyle = NSDateFormatterMediumStyle;
        f.timeStyle = NSDateFormatterShortStyle;
    });
    return [f stringFromDate:self.date];
}

// Image URLs in the feed contain HTML entities (&#038;). If they are not decoded,
// everything after the first "&#" becomes a URL fragment and the server returns the
// huge original image, which is why some previews never loaded.
- (NSString *)resizedImageURLWithWidth:(int)w {
    if (!self.imageURL.length) return nil;
    NSString *u = [FeedParser decodeEntities:self.imageURL];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"([?&])w=\\d+"
                                                                        options:0 error:nil];
    if ([re numberOfMatchesInString:u options:0 range:NSMakeRange(0, u.length)] > 0) {
        return [re stringByReplacingMatchesInString:u options:0 range:NSMakeRange(0, u.length)
                                       withTemplate:[NSString stringWithFormat:@"$1w=%d", w]];
    }
    if ([u rangeOfString:@"9to5mac.com"].location != NSNotFound ||
        [u rangeOfString:@"wp.com"].location != NSNotFound) {
        NSString *sep = [u rangeOfString:@"?"].location == NSNotFound ? @"?" : @"&";
        return [u stringByAppendingFormat:@"%@w=%d", sep, w];
    }
    return u;
}

- (NSString *)thumbnailURL { return [self resizedImageURLWithWidth:300]; }
- (NSString *)heroURL      { return [self resizedImageURLWithWidth:900]; }

@end
