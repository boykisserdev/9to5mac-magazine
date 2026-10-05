#import <Foundation/Foundation.h>

enum {
    LinkModeInApp  = 0,   // open in the built-in browser
    LinkModeSafari = 1,   // open in Safari
    LinkModeAsk    = 2    // ask every time
};

@interface Settings : NSObject
+ (NSInteger)linkMode;
+ (void)setLinkMode:(NSInteger)value;
+ (NSInteger)textSize;      // 0 small, 1 medium, 2 large, 3 extra large
+ (void)setTextSize:(NSInteger)value;
+ (NSInteger)theme;         // 0 light, 1 sepia, 2 dark
+ (void)setTheme:(NSInteger)value;
+ (NSInteger)fontStyle;     // 0 serif, 1 sans-serif
+ (void)setFontStyle:(NSInteger)value;
+ (NSString *)signature;    // changes whenever a reader setting changes
@end
