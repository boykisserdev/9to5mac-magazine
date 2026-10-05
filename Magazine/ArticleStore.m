#import "ArticleStore.h"

static NSString *StorePath(NSSearchPathDirectory dir, NSString *name) {
    NSString *d = NSSearchPathForDirectoriesInDomains(dir, NSUserDomainMask, YES)[0];
    [[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES
                                               attributes:nil error:nil];
    return [d stringByAppendingPathComponent:name];
}

@implementation ArticleStore {
    NSMutableArray *_saved;
    NSArray *_feed;
}

+ (ArticleStore *)shared {
    static ArticleStore *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [ArticleStore new]; });
    return s;
}

- (id)init {
    if ((self = [super init])) {
        _saved = [NSMutableArray array];
        id obj = [NSKeyedUnarchiver unarchiveObjectWithFile:StorePath(NSDocumentDirectory, @"saved.archive")];
        if ([obj isKindOfClass:[NSArray class]]) [_saved addObjectsFromArray:obj];
        id feed = [NSKeyedUnarchiver unarchiveObjectWithFile:StorePath(NSCachesDirectory, @"feed.archive")];
        _feed = [feed isKindOfClass:[NSArray class]] ? feed : @[];
    }
    return self;
}

- (NSInteger)indexOf:(Article *)a {
    for (NSUInteger i = 0; i < _saved.count; i++) {
        if ([[_saved[i] link] isEqualToString:a.link]) return (NSInteger)i;
    }
    return -1;
}

- (void)persist {
    [NSKeyedArchiver archiveRootObject:_saved toFile:StorePath(NSDocumentDirectory, @"saved.archive")];
}

- (NSArray *)saved { return [_saved copy]; }

- (BOOL)isSaved:(Article *)a { return [self indexOf:a] >= 0; }

- (BOOL)toggleSaved:(Article *)a {
    NSInteger i = [self indexOf:a];
    BOOL nowSaved;
    if (i >= 0) { [_saved removeObjectAtIndex:i]; nowSaved = NO; }
    else        { [_saved insertObject:a atIndex:0]; nowSaved = YES; }
    [self persist];
    return nowSaved;
}

- (void)removeSaved:(Article *)a {
    NSInteger i = [self indexOf:a];
    if (i >= 0) { [_saved removeObjectAtIndex:i]; [self persist]; }
}

- (void)updateSaved:(Article *)a {
    NSInteger i = [self indexOf:a];
    if (i >= 0) {
        [_saved replaceObjectAtIndex:(NSUInteger)i withObject:a];
        [self persist];
    }
}

- (NSArray *)cachedFeed { return _feed; }

- (void)setCachedFeed:(NSArray *)articles {
    NSUInteger n = MIN((NSUInteger)30, articles.count);
    _feed = [articles subarrayWithRange:NSMakeRange(0, n)];
    NSArray *snapshot = _feed;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [NSKeyedArchiver archiveRootObject:snapshot toFile:StorePath(NSCachesDirectory, @"feed.archive")];
    });
}

@end
