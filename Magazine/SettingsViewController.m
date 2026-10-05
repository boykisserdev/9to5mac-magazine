#import "SettingsViewController.h"
#import "Settings.h"
#import "ImageLoader.h"

enum { SectionLinks, SectionTextSize, SectionTheme, SectionFont, SectionStorage, SectionCount };

static NSArray *Options(NSInteger section) {
    switch (section) {
        case SectionLinks:    return @[@"Open in the reader", @"Open in Safari", @"Ask every time"];
        case SectionTextSize: return @[@"Small", @"Medium", @"Large", @"Extra large"];
        case SectionTheme:    return @[@"Light", @"Sepia", @"Dark"];
        case SectionFont:     return @[@"Serif", @"Sans-serif"];
        default:              return @[@"Clear image cache"];
    }
}

static NSInteger CurrentValue(NSInteger section) {
    switch (section) {
        case SectionLinks:    return [Settings linkMode];
        case SectionTextSize: return [Settings textSize];
        case SectionTheme:    return [Settings theme];
        case SectionFont:     return [Settings fontStyle];
        default:              return -1;
    }
}

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Settings";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return SectionCount; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return Options(s).count;
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    switch (s) {
        case SectionLinks:    return @"External links";
        case SectionTextSize: return @"Text size";
        case SectionTheme:    return @"Theme";
        case SectionFont:     return @"Font";
        default:              return @"Storage";
    }
}

- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s {
    if (s == SectionLinks) {
        return @"Choose what happens when you tap a link inside an article. 9to5Mac article links always open in the reader.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"opt"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"opt"];
    c.textLabel.text = Options(ip.section)[ip.row];
    if (ip.section == SectionStorage) {
        c.textLabel.textAlignment = NSTextAlignmentCenter;
        c.textLabel.textColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1];
        c.accessoryType = UITableViewCellAccessoryNone;
    } else {
        c.textLabel.textAlignment = NSTextAlignmentLeft;
        c.textLabel.textColor = [UIColor blackColor];
        c.accessoryType = (CurrentValue(ip.section) == ip.row) ? UITableViewCellAccessoryCheckmark
                                                               : UITableViewCellAccessoryNone;
    }
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    switch (ip.section) {
        case SectionLinks:    [Settings setLinkMode:ip.row]; break;
        case SectionTextSize: [Settings setTextSize:ip.row]; break;
        case SectionTheme:    [Settings setTheme:ip.row]; break;
        case SectionFont:     [Settings setFontStyle:ip.row]; break;
        default:
            [ImageLoader clearCache];
            [[[UIAlertView alloc] initWithTitle:@"Image cache cleared" message:nil delegate:nil
                              cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
    }
    [t reloadSections:[NSIndexSet indexSetWithIndex:ip.section]
     withRowAnimation:UITableViewRowAnimationNone];
}

@end
