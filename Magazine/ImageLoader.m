#import "ImageLoader.h"
#import "Config.h"

static NSCache *MemCache(void) {
    static NSCache *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [NSCache new]; c.countLimit = 120; });
    return c;
}

static NSString *DiskDir(void) {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
            stringByAppendingPathComponent:@"imgcache"];
}

static NSString *DiskPath(NSString *url) {
    [[NSFileManager defaultManager] createDirectoryAtPath:DiskDir() withIntermediateDirectories:YES
                                               attributes:nil error:nil];
    return [DiskDir() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%lx", (unsigned long)[url hash]]];
}

@implementation ImageLoader

+ (UIImage *)cachedImageForURL:(NSString *)url {
    return url ? [MemCache() objectForKey:url] : nil;
}

+ (void)clearCache {
    [MemCache() removeAllObjects];
    [[NSFileManager defaultManager] removeItemAtPath:DiskDir() error:nil];
}

+ (void)loadURL:(NSString *)url completion:(void (^)(UIImage *))completion {
    if (!url.length) { completion(nil); return; }
    UIImage *hit = [MemCache() objectForKey:url];
    if (hit) { completion(hit); return; }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *path = DiskPath(url);
        NSData *disk = [NSData dataWithContentsOfFile:path];
        UIImage *img = disk ? [UIImage imageWithData:disk] : nil;

        if (!img) {
            // Try the http:// version first, then the original URL.
            NSMutableArray *candidates = [NSMutableArray arrayWithObject:Downgrade(url)];
            if (![candidates containsObject:url]) [candidates addObject:url];
            for (NSString *c in candidates) {
                NSURL *u = [NSURL URLWithString:c];
                if (!u) continue;
                NSURLRequest *req = [NSURLRequest requestWithURL:u
                                                     cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                 timeoutInterval:20];
                NSURLResponse *resp = nil;
                NSError *err = nil;
                NSData *data = [NSURLConnection sendSynchronousRequest:req
                                                     returningResponse:&resp error:&err];
                UIImage *net = data ? [UIImage imageWithData:data] : nil;
                if (net) {
                    img = net;
                    [data writeToFile:path atomically:YES];
                    break;
                }
            }
        }
        if (img) [MemCache() setObject:img forKey:url];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(img); });
    });
}

@end
