#import "GKLoader.h"
#import "CMController.h"

static NSString* APPS_PATH = @"~/Library/Application Support/GreaseKit/apps.plist";

@implementation GKLoader

+ (void) saveApplicationList: (NSArray*) apps
{
    NSString* path = [APPS_PATH stringByExpandingTildeInPath];
    [apps writeToFile: path atomically: YES];
}

+ (void) load
{
    NSString* path = [APPS_PATH stringByExpandingTildeInPath];

    // create folder on "Application Support".
    NSFileManager* manager;
    manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath: [path stringByDeletingLastPathComponent]
                        attributes: nil];

    // load application list
    NSArray* apps = [[NSArray alloc] initWithContentsOfFile: path];
    if (apps && [apps count] > 0) {
        ;
    } else {
        apps = [[NSArray alloc] initWithObjects: @"com.apple.Safari", @"com.factorycity.DietPibb", nil];
    }

    NSString* identifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([apps containsObject: identifier]) {
        [[CMController alloc] initWithApplications: apps];
    }

    [apps release];
}
@end