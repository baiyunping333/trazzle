//
//  PluginController.m
//  Logger
//
//  Created by Marc Bauer on 19.10.08.
//  Copyright 2008 nesiumdotcom. All rights reserved.
//

#import "LoggerPlugin.h"

@implementation LoggerPlugin

#pragma mark -
#pragma mark Initialization & Deallocation

+ (void)initialize
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	[dict setObject:[NSNumber numberWithInt:3456] forKey:@"LPServerPort"];
	[dict setObject:[NSNumber numberWithBool:NO] forKey:@"LPEnableFiltering"];
	[dict setObject:[NSNumber numberWithBool:YES] forKey:@"LPClearMessagesOnConnection"];
	[dict setObject:[NSNumber numberWithInt:WBMBringToTop] 
		forKey:@"LPWindowBehaviour"];
	[dict setObject:[NSNumber numberWithBool:NO] forKey:@"LPDebuggingMode"];
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:dict];
}

- (id)initWithPlugInController:(PlugInController *)aController
{
	if (self = [super init])
	{
		controller = aController;
		m_loggingViewController = [[LoggingViewController alloc] initWithNibName:@"LogWindow" 
			bundle:[NSBundle bundleForClass:[self class]]];
		[controller addTabWithIdentifier:@"Foo" title:@"Test Tab" 
			view:[m_loggingViewController view]];
		m_messageController = [[MessageController alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[m_messageController release];
	[super dealloc];
}

@end