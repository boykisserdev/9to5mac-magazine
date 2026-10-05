#import "Settings.h"

static NSInteger Get(NSString *key, NSInteger max) {
    NSInteger v = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    return MAX(0, MIN(max, v));
}

static void Put(NSString *key, NSInteger v) {
    [[NSUserDefaults standardUserDefaults] setInteger:v forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@implementation Settings

+ (void)initialize {
    if (self == [Settings class]) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            @"linkMode": @(LinkModeInApp),
            @"textSize": @1,
            @"theme": @0,
            @"fontStyle": @0
        }];
    }
}

+ (NSInteger)linkMode  { return Get(@"linkMode", 2); }
+ (void)setLinkMode:(NSInteger)v { Put(@"linkMode", v); }
+ (NSInteger)textSize  { return Get(@"textSize", 3); }
+ (void)setTextSize:(NSInteger)v { Put(@"textSize", v); }
+ (NSInteger)theme     { return Get(@"theme", 2); }
+ (void)setTheme:(NSInteger)v { Put(@"theme", v); }
+ (NSInteger)fontStyle { return Get(@"fontStyle", 1); }
+ (void)setFontStyle:(NSInteger)v { Put(@"fontStyle", v); }

+ (NSString *)signature {
    return [NSString stringWithFormat:@"%ld-%ld-%ld",
            (long)[self textSize], (long)[self theme], (long)[self fontStyle]];
}

@end
