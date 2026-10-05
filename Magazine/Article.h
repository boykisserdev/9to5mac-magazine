#import <Foundation/Foundation.h>

@interface Article : NSObject <NSCoding>
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, copy) NSString *html;       // excerpt at first, full text once loaded
@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, copy) NSString *postID;     // WordPress post id (used to fetch the full text)
@property (nonatomic) BOOL full;                  // YES once the full text has been loaded
@property (nonatomic, strong) NSDate *date;
- (NSString *)dateString;
- (NSString *)thumbnailURL;
- (NSString *)heroURL;
@end
