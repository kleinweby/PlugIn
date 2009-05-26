//
//  PlugInManager.m
//  XAMPP Control
//
//  Created by Christian Speich on 20.04.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PlugIn.h"

NSString* PlugInErrorDomain = @"org.apachefriends.xampp.control.plugin";
static PlugInManager *sharedPlugInManager = nil;

@interface PlugInManager (PRIVATE)

- (BOOL) registerPlugIn:(PlugIn*)anPlugIn;

@end


@implementation PlugInManager

#pragma mark SingelTon

+ (PlugInManager*)sharedPlugInManager
{
    @synchronized(self) {
        if (sharedPlugInManager == nil) {
            [[self alloc] init]; // assignment not done here
        }
    }
    return sharedPlugInManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedPlugInManager == nil) {
            sharedPlugInManager = [super allocWithZone:zone];
            return sharedPlugInManager;  // assignment and return on first allocation
        }
    }
    return nil; //on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (unsigned)retainCount
{
    return UINT_MAX;  //denotes an object that cannot be released
} 

- (void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

#pragma mark -

- (id) init
{
	self = [super init];
	if (self != nil) {
		searchPaths = [NSMutableArray new];
		loadedPlugins = [NSMutableArray new];
		registry = [PlugInRegistry new];
		[self setPlugInExtension:@"plugin"];
		
		[[self mutableArrayValueForKey:@"searchPaths"] addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
	}
	return self;
}

- (void) dealloc
{
	[searchPaths release];
	[loadedPlugins release];
	[registry release];
	
	[super dealloc];
}

- (NSArray*) searchPaths
{
	return searchPaths;
}

- (NSArray*) loadedPlugins
{
	return loadedPlugins;
}

- (PlugInRegistry*) registry
{
	return registry;
}

- (NSString*) plugInExtension
{
	return plugInExtension;
}

- (void) setPlugInExtension:(NSString*)anExtension
{
	if ([anExtension isEqualToString:plugInExtension])
		return;
	
	[plugInExtension release];
	plugInExtension = [anExtension retain];
}

- (bool) loadAllPluginsError:(NSError**)anError
{
	NSEnumerator *searchPathEnumerator = [[self searchPaths] objectEnumerator];
	NSString *searchPath;
	
	while ((searchPath = [searchPathEnumerator nextObject])) {
		NSEnumerator *plugInPathEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:searchPath];
		NSString *plugInPath;
		
		while ((plugInPath = [plugInPathEnumerator nextObject])) {
			if ([[plugInPath pathExtension] isEqualToString:[self plugInExtension]])
				[self loadPlugIn:[searchPath stringByAppendingPathComponent:plugInPath] error:NULL];
		}
	}
	
	return YES;
}

- (bool) loadPlugIn:(NSString*)anPath error:(NSError**)anError
{
	NSParameterAssert(anPath != Nil);
	// anError is optional
	
	NSLog(@"DEBUG: Load plugIn '%@' from '%@'", [anPath lastPathComponent], [anPath stringByDeletingLastPathComponent]);
	
	NSBundle *plugIn = [NSBundle bundleWithPath:anPath];
	NSError *error = Nil;
	Class plugInClass;
	id plugInInstance;
	
	NSLog(@"DEBUG: Plugin identifier %@", [plugIn bundleIdentifier]);
	
	if (plugIn == Nil) {
		error = [NSError errorWithDomain:PlugInErrorDomain 
											 code:PlugInNotFound 
										 userInfo:Nil];
		
		*anError = error;
		return NO;
	}
	
	if ([plugIn isLoaded]) {
		NSLog(@"Plugin '%@' already loaded!", [anPath lastPathComponent]);
		return YES;
	}
	
	if (![plugIn load]) {
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
									code:PlugInNotLoaded 
								userInfo:Nil];
		
			*anError = error;
		}
		return NO;
	}
	
	plugInClass = [plugIn principalClass];
	
	if (!plugInClass) {
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotLoaded 
									userInfo:Nil];
		
			*anError = error;
		}
		return NO;
	}
		
	if (![plugInClass isSubclassOfClass:[PlugIn class]]) {
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotCompatible 
									userInfo:Nil];
		
			*anError = error;
		}
		return NO;
	}
	
	
	plugInInstance = [[plugInClass alloc] init];
		
	if (![plugInInstance setupError:&error]) {
		[plugInInstance release];
		
		if (anError != NULL)
			*anError = error;
		
		return NO;
	}
	
	if (![self registerPlugIn:plugInInstance]) {
		[plugInInstance release];
		
		if (anError != NULL) {
			error = [NSError errorWithDomain:PlugInErrorDomain 
										code:PlugInNotRegistered 
									userInfo:Nil];
		
			*anError = error;
		}

		return NO;
	}

	[[self mutableArrayValueForKey:@"loadedPlugins"] addObject:plugInInstance];
	
	[plugInInstance release];
	
	NSLog(@"DEBUG: Plugin '%@' succesfully loaded.", [anPath lastPathComponent]);
		
	return YES;
}

- (BOOL) registerPlugIn:(PlugIn*)anPlugIn
{
	NSParameterAssert([anPlugIn isKindOfClass:[PlugIn class]]);
	
	NSDictionary *registryInfo;
	
	registryInfo = [anPlugIn registryInfo];

	if (!registryInfo)
		return NO;
	
	return [registry registerPlugInWithInfo:registryInfo];
}

@end
