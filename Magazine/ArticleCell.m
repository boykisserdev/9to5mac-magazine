#import "ArticleCell.h"
#import "ImageLoader.h"

@implementation ArticleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid])) {
        self.thumb = [[UIImageView alloc] init];
        self.thumb.contentMode = UIViewContentModeScaleAspectFill;
        self.thumb.clipsToBounds = YES;
        self.thumb.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        self.titleLabel.numberOfLines = 3;
        self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        self.titleLabel.backgroundColor = [UIColor clearColor];

        self.dateLabel = [[UILabel alloc] init];
        self.dateLabel.font = [UIFont systemFontOfSize:12];
        self.dateLabel.textColor = [UIColor grayColor];
        self.dateLabel.backgroundColor = [UIColor clearColor];

        [self.contentView addSubview:self.thumb];
        [self.contentView addSubview:self.titleLabel];
        [self.contentView addSubview:self.dateLabel];
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    self.thumb.frame = CGRectMake(10, 10, 110, 80);
    self.titleLabel.frame = CGRectMake(130, 8, w - 140, 60);
    self.dateLabel.frame = CGRectMake(130, 72, w - 140, 18);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.thumb.image = nil;
    self.imageURL = nil;
}

- (void)configureWithArticle:(Article *)a {
    self.titleLabel.text = a.title;
    self.dateLabel.text = [a dateString];
    NSString *url = [a thumbnailURL];
    self.imageURL = url;
    self.thumb.image = nil;
    if (!url) return;

    UIImage *cached = [ImageLoader cachedImageForURL:url];
    if (cached) { self.thumb.image = cached; return; }

    __weak ArticleCell *weakSelf = self;
    [ImageLoader loadURL:url completion:^(UIImage *img) {
        ArticleCell *s = weakSelf;
        if (img && s && [s.imageURL isEqualToString:url]) s.thumb.image = img;
    }];
}

@end
