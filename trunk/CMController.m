/*
 * Copyright (c) 2006 KATO Kazuyoshi <kzys@8-p.info>
 * This source code is released under the MIT license.
 */

#import "CMController.h"
#import <WebKit/WebKit.h>
#import "CMUserScript.h"

@interface NSMutableString(StringPrepend)
- (void) prependString: (NSString*) s;
@end

@implementation NSMutableString(StringPrepend)
- (void) prependString: (NSString*) s
{
	[self insertString: s atIndex: 0];
}
@end

@implementation CMController
- (NSArray*) scripts
{
	return scripts_;
}

- (void) loadUserScripts
{
	NSFileManager* manager;
	manager = [NSFileManager defaultManager];
	
	NSArray* files;
	files = [manager directoryContentsAtPath: scriptDir_];
	
	if (! files) {
		[manager createDirectoryAtPath: scriptDir_
							attributes: nil];
		files = [manager directoryContentsAtPath: scriptDir_];
	}
	
	[self willChangeValueForKey: @"scripts"];
	
	int i;
	for (i = 0; i < [files count]; i++) {
		NSString* path;
		path = [NSString stringWithFormat: @"%@/%@", scriptDir_, [files objectAtIndex: i]];
		
		if (! [path hasSuffix: @".user.js"]) {
			continue;
		}
		
		CMUserScript* script;
		script = [[CMUserScript alloc] initWithContentsOfFile: path];
		
		[scripts_ addObject: script];
		[script release];
	}
	[self didChangeValueForKey: @"scripts"];
}

- (NSArray*) matchedScripts: (NSURL*) url
{
	NSMutableArray* result = [[NSMutableArray alloc] init];
	
	int i;
	for (i = 0; i < [scripts_ count]; i++) {
		CMUserScript* script = [scripts_ objectAtIndex: i];
		if ([script isMatched: url]) {
			[result addObject: [script script]];
		}
	}
	
	return [result autorelease];
}

- (void) installAlertDidEnd: (NSAlert*) alert
				 returnCode: (int) returnCode
				contextInfo: (void*) contextInfo
{
	CMUserScript* script = (CMUserScript*) contextInfo;
	if (returnCode == NSAlertFirstButtonReturn) {
		[script install: scriptDir_];
		[self reloadUserScripts: nil];
	}
	[script release];
}

- (void) showInstallAlertSheet: (CMUserScript*) script
					   webView: (WebView*) webView
{
	NSAlert* alert = [[NSAlert alloc] init];

	// Informative Text
	NSMutableString* text = [[NSMutableString alloc] init];
	
	if ([script name] && [script description]) {
		[text appendFormat: @"%@ - %@", [script name], [script description]];
	} else {
		if ([script name])
			[text appendString: [script name]];
		else if ([script description])
			[text appendString: [script description]];
	}
	
	[alert setInformativeText: text];
	[text release];
	
	// Message and Buttons
	if([script isInstalled: scriptDir_]) {
		[alert setMessageText: @"This script is installed, Override?"];	
		[alert addButtonWithTitle: @"Override"];
	} else {
		[alert setMessageText: @"Install this script?"];	
		[alert addButtonWithTitle: @"Install"];
	}
	[alert addButtonWithTitle: @"Cancel"];
	
	// Begin Sheet
	[alert beginSheetModalForWindow: [webView window]
					  modalDelegate: self
					 didEndSelector: @selector(installAlertDidEnd:returnCode:contextInfo:)
						contextInfo: script];	
}


- (void) progressStarted: (NSNotification*) n
{    
	WebView* webView = [n object];
	WebDataSource* dataSource = [[webView mainFrame] provisionalDataSource];
    if (! dataSource) {
        return;
    }
    
	NSURL* url = [[dataSource request] URL];
    
    // NSLog(@"S: webView = %@, dataSource = %@, url = %@", webView, dataSource, url);

    NSArray* ary = [self matchedScripts: url];
    if ([ary count] > 0) {
        [targetPages_ addObject: dataSource];
    }
}
    
- (void) progressFinished: (NSNotification*) n
{    
	WebView* webView = [n object];
	WebDataSource* dataSource = [[webView mainFrame] dataSource];
	NSURL* url = [[dataSource request] URL];

    // NSLog(@"F: url = %@", url);
	
	if ([[url absoluteString] hasSuffix: @".user.js"]) {
		CMUserScript* script;
		script = [[CMUserScript alloc] initWithContentsOfURL: url];
		
		if (script) {
			[self showInstallAlertSheet: script webView: webView];
		}
		return;
	}
    
    if ([targetPages_ containsObject: dataSource]) {
        [targetPages_ removeObject: dataSource];
    } else {
        return;
    }
	
	if (! [[webView mainFrame] DOMDocument]) {
		return;
	}
	
	// Build Script
	NSMutableString* script = [[NSMutableString alloc] init];

	NSArray* ary = [self matchedScripts: url];
	int i;
	for (i = 0; i < [ary count]; i++) {
		[script appendString: [ary objectAtIndex: i]];
	}
	
	if ([script length] > 0) {
		// Eval
		[webView stringByEvaluatingJavaScriptFromString: script];
	}
	
	[script release];
}

#pragma mark Action
- (IBAction) uninstallSelected: (id) sender
{
	CMUserScript* script = [[scriptsController selectedObjects] objectAtIndex: 0];
	[script uninstall];
	
	[self reloadUserScripts: sender];
}

- (IBAction) orderFrontAboutPanel: (id) sender
{
	NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFileType: @"bundle"];
	[icon setSize: NSMakeSize(128, 128)];
	
	NSDictionary* options;
	options = [NSDictionary dictionaryWithObjectsAndKeys: 
		@"Creammonkey",  @"ApplicationName",
		icon,  @"ApplicationIcon",
		@"",  @"Version",
		@"Version 0.5",  @"ApplicationVersion",
		@"Copyright (c) 2006 KATO Kazuyoshi",  @"Copyright",
		nil];
	[NSApp orderFrontStandardAboutPanelWithOptions: options];
}


- (IBAction) reloadUserScripts: (id) sender
{
	[scripts_ release];
	
	scripts_ = [[NSMutableArray alloc] init];
	[self loadUserScripts];
}

#pragma mark Override
- (id) init
{
	// Safari?
	NSString* identifier = [[NSBundle mainBundle] bundleIdentifier];
	if (! [identifier isEqual: @"com.apple.Safari"]) {
		return nil;
	}

	NSLog(@"CMController - init");
	
	self = [super init];
	if (! self) {
		return nil;
	}
	
	scriptDir_ = [@"~/Library/Application Support/Creammonkey/" stringByExpandingTildeInPath];
	[scriptDir_ retain];
	
	scripts_ = nil;
	[self reloadUserScripts: nil];
    
    targetPages_ = [[NSMutableSet alloc] init];
	
	[NSBundle loadNibNamed: @"Menu.nib" owner: self];
	
	return self;
}

- (void) dealloc
{
	NSLog(@"CMController - dealloc");
	
	[scripts_ release];
    [targetPages_ release];
    
	[super dealloc];
}

- (void) awakeFromNib
{
	// Menu
	NSMenuItem* item;
	
	item = [[NSMenuItem alloc] init];
	[item setSubmenu: menu];
	
	root_ = item;
	[menu setTitle: @":)"];
	
	[[NSApp mainMenu] addItem: item];
	[item release];
	
	// Notification
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];    
	[center addObserver: self
			   selector: @selector(progressStarted:)
				   name: WebViewProgressStartedNotification
				 object: nil];
	[center addObserver: self
			   selector: @selector(progressFinished:)
				   name: WebViewProgressFinishedNotification
				 object: nil];
}


@end
