//
//  PluginController.m
//  Logger
//
//  Created by Marc Bauer on 19.10.08.
//  Copyright 2008 nesiumdotcom. All rights reserved.
//

#import "LoggerPlugin.h"

#define kMMCFG_GlobalPath @"/Library/Application Support/Macromedia/mm.cfg"
#define kMMCFG_LocalPath @"~/mm.cfg"

#define kUserDefaultsObservationContext 1
#define kSessionObservationContext 2

@interface LoggerPlugin (Private)
- (void)_checkMMCfgs;
- (NSMutableDictionary *)_readMMCfgAtPath:(NSString *)path;
- (BOOL)_validateMMCfg:(NSMutableDictionary *)settings;
- (BOOL)_writeMMCfg:(NSDictionary *)settings toPath:(NSString *)path;
- (void)_cleanupAfterConnection:(ZZConnection *)conn;
- (LPSession *)_createNewSession;
- (void)_destroySession:(LPSession *)session;
- (LPSession *)_sessionForSwfURL:(NSURL *)swfURL;
- (LPSession *)_sessionForConnection:(ZZConnection *)conn;
- (void)_updateWindowLevel:(BOOL)justConnected;
- (BOOL)_hasActiveSession;
- (void)_handleMessage:(AbstractMessage *)message fromConnection:(ZZConnection *)connection;
@end


@implementation LoggerPlugin

#pragma mark -
#pragma mark Initialization & Deallocation

+ (void)initialize
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	[dict setObject:[NSNumber numberWithBool:NO] forKey:kFilteringEnabledKey];
	[dict setObject:[NSNumber numberWithBool:YES] forKey:kShowFlashLogMessages];
	[dict setObject:[NSNumber numberWithBool:NO] forKey:kKeepAlwaysOnTop];
	[dict setObject:[NSNumber numberWithInt:kTabBehaviourOneForSameURL] forKey:kTabBehaviour];
	[dict setObject:[NSNumber numberWithBool:YES] forKey:kReuseTabs];
	[dict setObject:[NSNumber numberWithInt:WBMBringToTop] forKey:kWindowBehaviour];
	[dict setObject:[NSNumber numberWithBool:NO] forKey:kKeepWindowOnTopWhileConnected];
	[dict setObject:[NSNumber numberWithBool:YES] forKey:kClearMessagesOnNewConnection];
	[dict setObject:[NSNumber numberWithBool:YES] forKey:kAutoSelectNewTab];
	[dict setObject:[NSNumber numberWithBool:YES] forKey:kShowTextMateLinks];
	[dict setObject:[NSNumber numberWithBool:NO] forKey:@"LPDebuggingMode"];
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:dict];
}

- (id)initWithPlugInController:(PlugInController *)aController
{
	if (self = [super init])
	{
		m_controller = aController;
		
		m_filterController = [[LPFilterController alloc] init];
		[m_filterController window];
		
		[aController.sharedGateway registerService:[[[LoggingService alloc] initWithDelegate:self] 
			autorelease] withName:@"LoggingService"];
		[aController.sharedGateway registerService:[[[MenuService alloc] initWithDelegate:self] 
			autorelease] withName:@"MenuService"];
		
		// tail flashlog
		m_tailTask = [[NSTask alloc] init];
		m_logPipe = [[NSPipe alloc] init];
		[m_tailTask setLaunchPath:@"/usr/bin/tail"];
		[m_tailTask setArguments:[NSArray arrayWithObjects:@"-F", @"-n", @"0", 
			[@"~/Library/Preferences/Macromedia/Flash Player/Logs/flashlog.txt" 
				stringByExpandingTildeInPath], nil]];
		[m_tailTask setStandardOutput:m_logPipe];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataAvailable:) 
			name:NSFileHandleReadCompletionNotification object:[m_logPipe fileHandleForReading]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskTerminated:) 
			name:NSTaskDidTerminateNotification object:m_tailTask];
			
		[m_tailTask launch];
		[[m_logPipe fileHandleForReading] readInBackgroundAndNotify];
		
		[self _checkMMCfgs];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(applicationWillTerminate:)
			name:NSApplicationWillTerminateNotification object:nil];
			
		m_sessions = [[NSMutableArray alloc] init];
		[self _createNewSession];
		
		NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
		[defaults addObserver:self 
			forKeyPath:[NSString stringWithFormat:@"values.%@", kKeepAlwaysOnTop] 
			options:0 context:(void *)kUserDefaultsObservationContext];
		[defaults addObserver:self 
			forKeyPath:[NSString stringWithFormat:@"values.%@", kKeepWindowOnTopWhileConnected] 
			options:0 context:(void *)kUserDefaultsObservationContext];
			
		[self _updateWindowLevel:NO];
	}
	return self;
}

- (void)dealloc
{
	[m_filterController release];
	[super dealloc];
}


- (void)tabViewDelegateDidBecomeActive:(id)aDelegate
{
	if (![aDelegate isKindOfClass:[LPSession class]])
		return;
	LPSession *session = (LPSession *)aDelegate;
	m_filterController.model = session.filterModel;
}

- (void)tabViewDelegateWasClosed:(id)aDelegate
{
	if (![aDelegate isKindOfClass:[LPSession class]])
		return;
	LPSession *session = (LPSession *)aDelegate;
	[self _destroySession:session];
}

- (void)trazzleDidOpenConnection:(ZZConnection *)conn
{
}

- (void)trazzleDidCloseConnection:(ZZConnection *)conn
{
	[self _cleanupAfterConnection:conn];
	for (LPSession *session in m_sessions)
	{
		if ([session containsConnection:conn])
			[session removeConnection:conn];
	}
	[self _updateWindowLevel:NO];
}

- (void)trazzleDidReceiveSignatureForConnection:(ZZConnection *)conn
{
	LPSession *session = [self _sessionForSwfURL:conn.swfURL];
	[session addConnection:conn];
}

- (void)trazzleDidReceiveMessage:(NSString *)message forConnection:(ZZConnection *)conn
{
	MessageParser *parser = [[MessageParser alloc] initWithXMLString:message delegate:self];
	AbstractMessage *msg = (AbstractMessage *)[[parser data] objectAtIndex:0];
	
	if (conn.applicationName == nil && msg.messageType != kLPMessageTypeConnectionSignature)
	{
		[conn disconnect];
		goto bailout;
	}
	
	if (msg.messageType == kLPMessageTypeConnectionSignature)
	{
		ConnectionSignature *sig = (ConnectionSignature *)msg;
		[conn setConnectionParams:[NSDictionary dictionaryWithObjectsAndKeys:
			sig.applicationName, @"applicationName", 
			[NSURL URLWithString:sig.swfURL], @"swfURL", nil]];
		goto bailout;
	}
	
	if (msg.messageType == kLPMessageTypeCommand)
		NSLog(@"Command message are temporarly disabled!");
	else
		[self _handleMessage:msg fromConnection:conn];
	
	bailout:
		[parser release];
}

- (void)prefPane:(NSViewController **)viewController icon:(NSImage **)icon
{
	*viewController = [[[LPPreferencesViewController alloc] initWithNibName:@"Preferences" 
		bundle:[NSBundle bundleForClass:[self class]]] autorelease];
	*icon = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] 
		pathForResource:@"LoggingIcon" ofType:@"png"]] autorelease];
}

//
//- (void)_handleCommandMessage:(CommandMessage *)msg fromClient:(LoggingClient *)client
//{
//	if (msg.type == kCommandActionTypeStartFileMonitoring)
//	{
//		[[FileMonitor sharedMonitor] addObserver:client 
//			forFileAtPath:[msg.attributes objectForKey:@"path"]];
//	}
//	else if (msg.type == kCommandActionTypeStopFileMonitoring)
//	{
//		[[FileMonitor sharedMonitor] removeObserver:client 
//			forFileAtPath:[msg.attributes objectForKey:@"path"]];
//	}
//}



#pragma mark -
#pragma mark Notifications

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[m_tailTask terminate];
	for (ZZConnection *conn in m_controller.connectedClients)
		[self _cleanupAfterConnection:conn];
}



#pragma mark -
#pragma mark Bindings notifications

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
	change:(NSDictionary *)change context:(void *)context
{
	if ((int)context == kUserDefaultsObservationContext)
	{
		if ([keyPath isEqualToString:[NSString stringWithFormat:@"values.%@", kKeepAlwaysOnTop]] || 
			[keyPath isEqualToString:[NSString stringWithFormat:@"values.%@", 
				kKeepWindowOnTopWhileConnected]])
		{
			[self _updateWindowLevel:NO];
		}
	}
	else if ((int)context == kSessionObservationContext)
	{
		if ([keyPath isEqualToString:@"isReady"])
		{
			BOOL autoSelectTab = [[[[NSUserDefaultsController sharedUserDefaultsController] values] 
				valueForKey:kAutoSelectNewTab] boolValue];
			if (autoSelectTab)
				[m_controller selectTabItemWithDelegate:(LPSession *)object];
		}
	}
}



#pragma mark -
#pragma mark Private methods

- (LPSession *)_createNewSession
{
	LPSession *session = [[LPSession alloc] initWithPlugInController:m_controller];
	session.delegate = self;
	[session addObserver:self forKeyPath:@"isReady" options:0 
		context:(void *)kSessionObservationContext];
	[m_sessions addObject:session];
	m_filterController.model = session.filterModel;
	return [session autorelease];
}

- (void)_destroySession:(LPSession *)session
{
	[session removeObserver:self forKeyPath:@"isReady"];
	[m_sessions removeObject:session];
	for (ZZConnection *conn in [session representedObjects])
		[conn disconnect];
}

- (LPSession *)_sessionForSwfURL:(NSURL *)swfURL
{
	TabBehaviourMode tmode = [[[[NSUserDefaultsController sharedUserDefaultsController] values] 
		valueForKey:kTabBehaviour] intValue];

	if (tmode == kTabBehaviourOneForAll && [m_sessions count])
		return [m_sessions objectAtIndex:0];

	for (LPSession *session in m_sessions)
	{
		if (session.isPristine || 
			([session.swfURL isEqual:swfURL] && 
			(session.isDisconnected || tmode == kTabBehaviourOneForSameURL)))
		{
			return session;
		}
	}
	
	return [self _createNewSession];
}

- (LPSession *)_sessionForConnection:(ZZConnection *)conn
{
	for (LPSession *session in m_sessions)
		if ([session.representedObjects aa_containsPointer:conn])
			return session;
	return nil;
}

- (BOOL)_hasActiveSession
{
	for (LPSession *session in m_sessions)
		if (!session.isDisconnected)
			return YES;
	return NO;
}

- (void)_checkMMCfgs
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableDictionary *globalMMCfgContents = nil;
	NSMutableDictionary *localMMCfgContents = nil;
	
	if ([fm fileExistsAtPath:kMMCFG_GlobalPath])
		globalMMCfgContents = [self _readMMCfgAtPath:kMMCFG_GlobalPath];
	
	if (globalMMCfgContents == nil)
		globalMMCfgContents = [NSMutableDictionary dictionary];
	
	if ([fm fileExistsAtPath:[kMMCFG_LocalPath stringByExpandingTildeInPath]])
		localMMCfgContents = [self _readMMCfgAtPath:kMMCFG_LocalPath];
	
	if (localMMCfgContents == nil)
		localMMCfgContents = [NSMutableDictionary dictionary];
	
	if (![self _validateMMCfg:globalMMCfgContents])
		[self _writeMMCfg:globalMMCfgContents toPath:kMMCFG_GlobalPath];

	if (![self _validateMMCfg:localMMCfgContents])
		[self _writeMMCfg:localMMCfgContents toPath:kMMCFG_LocalPath];
}

- (BOOL)_validateMMCfg:(NSMutableDictionary *)settings
{
	NSDictionary *defaultSettings = [NSDictionary dictionaryWithObjectsAndKeys: 
		@"1", @"ErrorReportingEnable", 
		@"0", @"MaxWarnings", 
		@"1", @"TraceOutputEnable", 
		[@"~/Library/Preferences/Macromedia/Flash Player/Logs/flashlog.txt" 
			stringByExpandingTildeInPath], @"TraceOutputFileName", nil];

	BOOL needsSave = NO;
	for (NSString *key in defaultSettings)
	{
		NSString *defaultValue = [defaultSettings objectForKey:key];
		NSString *currentValue = [settings objectForKey:key];
		if (currentValue == nil || ![defaultValue isEqualToString:currentValue])
		{
			[settings setObject:defaultValue forKey:key];
			needsSave = YES;
		}
	}
	return !needsSave;
}

- (NSMutableDictionary *)_readMMCfgAtPath:(NSString *)path
{
	NSError *error;
	NSMutableString *contents = [NSMutableString stringWithContentsOfFile:path 
		encoding:NSUTF8StringEncoding error:&error];
	[contents replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 
		range:(NSRange){0, [contents length]}];
	if (contents == nil)
	{
		return nil;
	}
	NSArray *lines = [contents componentsSeparatedByString:@"\n"];
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	for (NSString *line in lines)
	{
		NSRange equalSignRange = [line rangeOfString:@"="];
		if (equalSignRange.location == NSNotFound)
		{
			continue;
		}
		NSString *key = [line substringToIndex:equalSignRange.location];
		NSString *value = [line substringFromIndex:equalSignRange.location + equalSignRange.length];
		[settings setObject:[value stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceCharacterSet]] 
			forKey:[key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
	}
	return settings;
}

- (BOOL)_writeMMCfg:(NSDictionary *)settings toPath:(NSString *)path
{
	NSMutableString *contents = [NSMutableString string];
	for (NSString *key in settings)
	{
		[contents appendFormat:@"%@=%@\n", key, [settings objectForKey:key]];
	}
	NSError *error;
	return [contents writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:&error];
}

- (void)_cleanupAfterConnection:(ZZConnection *)conn
{
	NSMutableDictionary *dict = [conn storageForPluginWithName:@"LoggerPlugin"];

	if ([dict objectForKey:@"MenuItem"])
	{
		[m_controller removeStatusMenuItem:[dict objectForKey:@"MenuItem"]];
		[dict removeObjectForKey:@"MenuItem"];
	}
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *imagePath in [dict objectForKey:@"LoggedImages"])
		[fm removeItemAtPath:imagePath error:nil];
}

- (void)_handleFlashlogMessage:(AbstractMessage *)msg
{
	for (LPSession *session in m_sessions)
		[session handleMessage:msg];
}

- (void)_updateWindowLevel:(BOOL)justConnected
{
	NSObject *values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	BOOL keepWindowOnTop = [[values valueForKey:kKeepAlwaysOnTop] boolValue];
	BOOL keepWindowOnTopWhileConnected = [[values valueForKey:kKeepWindowOnTopWhileConnected] 
		boolValue];
		
	if (keepWindowOnTop || (keepWindowOnTopWhileConnected && [self _hasActiveSession]))
	{
		[m_controller setWindowIsFloating:YES];
		return;
	}
	
	[m_controller setWindowIsFloating:NO];
	WindowBehaviourMode wmode = [[values valueForKey:kWindowBehaviour] intValue];
	if (wmode == WBMBringToTop && justConnected)
		[m_controller bringWindowToTop];
}

- (void)_handleMessage:(AbstractMessage *)message fromConnection:(ZZConnection *)connection
{
	if (connection == nil) // a flashlog message
	{
		for (LPSession *session in m_sessions)
			[session handleMessage:message];
	}
	[[self _sessionForConnection:connection] handleMessage:message];
	
	NSMutableDictionary *storage = [connection storageForPluginWithName:@"LoggerPlugin"];
	if ([storage objectForKey:@"HasSentMessage"] == nil)
	{
		[storage setObject:[NSNumber numberWithBool:YES] forKey:@"HasSentMessages"];
		[self _updateWindowLevel:YES];
	}
}



#pragma mark -
#pragma mark NSTask and NSFileHandle Notifications

- (void)taskTerminated:(NSNotification *)notification {}

- (void)dataAvailable:(NSNotification *)notification
{
	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
	NSString *message = [[NSString alloc] initWithData:data encoding:NSMacOSRomanStringEncoding];
	[self _handleMessage:[AbstractMessage messageWithType:kLPMessageTypeFlashLog 
		message:[message htmlEncodedStringWithConvertedLinebreaks]] fromConnection:nil];
	[[m_logPipe fileHandleForReading] readInBackgroundAndNotify];
	[message release];
}



#pragma mark -
#pragma mark LoggingService Delegate methods

- (void)loggingService:(LoggingService *)service didReceiveLogMessage:(LogMessage *)message 
		   fromGateway:(AMFRemoteGateway *)gateway
{
	[self _handleMessage:message fromConnection:[m_controller connectionForRemote:gateway]];
}

- (void)loggingService:(LoggingService *)service didReceivePNG:(NSString *)path withSize:(NSSize)size
		   fromGateway:(AMFRemoteGateway *)gateway
{
	ZZConnection *conn = [m_controller connectionForRemote:gateway];
	NSMutableDictionary *dict = [conn storageForPluginWithName:@"LoggerPlugin"];
	
	if ([dict objectForKey:@"LoggedImages"] == nil)
		[dict setObject:[NSMutableArray array] forKey:@"LoggedImages"];
	[(NSMutableArray *)[dict objectForKey:@"LoggedImages"] addObject:path];
	
	AbstractMessage *msg = [[AbstractMessage alloc] init];
	msg.message = [NSString stringWithFormat:@"<img src='%@' width='%d' height='%d' />", path, 
				   (int)size.width, (int)size.height];
	[self _handleMessage:msg fromConnection:conn];
	[msg release];
}



#pragma mark -
#pragma mark MenuService Delegate methods

- (void)menuService:(MenuService *)service didReceiveMenu:(NSMenu *)menu 
		fromGateway:(AMFRemoteGateway *)gateway
{
	ZZConnection *conn = [m_controller connectionForRemote:gateway];
	NSMutableDictionary *dict = [conn storageForPluginWithName:@"LoggerPlugin"];
	LPSession *session = [self _sessionForConnection:conn];
	
	if ([dict objectForKey:@"MenuItem"])
	{
		[m_controller removeStatusMenuItem:[dict objectForKey:@"MenuItem"]];
		[dict removeObjectForKey:@"MenuItem"];
	}
	
	NSMenuItem *item = [[NSMenuItem alloc] init];
	[item setTitle:session.sessionName];
	[item setSubmenu:menu];
	[dict setObject:item forKey:@"MenuItem"];
	[m_controller addStatusMenuItem:item];
	[item release];
}



#pragma mark -
#pragma mark StatusMenuItem actions

- (void)statusMenuItemWasClicked:(NSMenuItem *)sender
{	
	NSMenu *lastMenu = [sender menu];
	NSMenu *parent = [lastMenu supermenu];
	NSMutableArray *indexes = [NSMutableArray arrayWithObject:
		[NSNumber numberWithInt:[lastMenu indexOfItem:sender]]];
	while (parent)
	{
		for (ZZConnection *conn in m_controller.connectedClients)
		{
			if ([[[conn storageForPluginWithName:@"LoggerPlugin"] 
				objectForKey:@"MenuItem"] menu] == parent)
			{
				[(AMFRemoteGateway *)conn.remote invokeRemoteService:@"MenuService" 
								 methodName:@"performClickOnMenuItemWithIndexPath" 
								  arguments:indexes, nil];
				return;
			}
		}
		
		for (int32_t i = 0; i < [[parent itemArray] count]; i++)
		{
			NSMenuItem *item = [[parent itemArray] objectAtIndex:i];
			if ([item submenu] == lastMenu)
			{
				[indexes insertObject:[NSNumber numberWithInt:i] atIndex:0];
			}
		}
		
		lastMenu = parent;
		parent = [lastMenu supermenu];
	}
}

@end