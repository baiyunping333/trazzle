//
//  MenuService.m
//  Logger
//
//  Created by Marc Bauer on 16.08.09.
//  Copyright 2009 nesiumdotcom. All rights reserved.
//

#import "MenuService.h"

@interface MenuService (Private)
- (NSMenu *)_menuFromSWFMenu:(SWFMenu *)aMenu;
@end


@implementation MenuService

@synthesize delegate=m_delegate;

- (id)initWithDelegate:(id)aDelegate
{
	if (self = [super init])
	{
		m_delegate = aDelegate;
	}
	return self;
}

- (oneway void)gateway:(AMFRemoteGateway *)gateway setMenu:(SWFMenu *)aMenu
{
	if ([m_delegate respondsToSelector:@selector(menuService:didReceiveMenu:fromGateway:)])
		[m_delegate menuService:self didReceiveMenu:[self _menuFromSWFMenu:aMenu] 
					fromGateway:gateway];
}



#pragma mark -
#pragma mark Private methods

- (NSMenu *)_menuFromSWFMenu:(SWFMenu *)aMenu
{
	if (aMenu == nil || (id)aMenu == [NSNull null]) return nil;
	NSMenu *menu = [[NSMenu alloc] init];
	for (SWFMenuItem *anItem in aMenu.menuItems)
	{
		NSMenuItem *item = [[NSMenuItem alloc] init];
		[item setTitle:anItem.title];
		[item setSubmenu:[self _menuFromSWFMenu:anItem.submenu]];
		[item setAction:@selector(statusMenuItemWasClicked:)];
		[item setTarget:m_delegate];
		[menu addItem:item];
		[item release];
	}
	return [menu autorelease];
}
@end



@implementation SWFMenu

@synthesize menuItems;

- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [super init])
	{
		self.menuItems = [coder decodeObject];
	}
	return self;
}

- (void)dealloc
{
	[menuItems release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08x> menuItems: %@", [self className], (long)self, 
		menuItems];
}

@end


@implementation SWFMenuItem

@synthesize title, submenu;

- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [super init])
	{
		self.title = [coder decodeObject];
		self.submenu = [coder decodeObject];
	}
	return self;
}

- (void)dealloc
{
	[title release];
	[submenu release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08x> title: %@, submenu: %@", [self className], 
			(long)self, title, submenu];
}

@end