//
//  TPNetworkConfigurationWatcher.m
//  teleport
//
//  Created by Julien Robert on 13/04/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TPNetworkConfigurationWatcher.h"
#import "TPServerController.h"
#import "TPClientController.h"
#import "TPNetworkConnection.h"
#import "TPRemoteHost.h"

static void _networkChangeCallBack(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info);

@implementation TPNetworkConfigurationWatcher

- (void)setDelegate:(id)delegate
{
	_delegate = delegate;
}

- (void)startWatching
{
	SCDynamicStoreContext context = {
		0,			   // version
		(__bridge void *)(self),		   // info
		NULL,		   // retain
		NULL,		   // release
		NULL,		   // copyDescription
	};
	
	_storeRef = SCDynamicStoreCreate(kCFAllocatorDefault, CFSTR("com.abyssoft.teleport"), &_networkChangeCallBack, &context);
	if(_storeRef == NULL) {
		NSLog(@"Error creating the dynamic store");
	}
	else {
		CFMutableArrayRef keys = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
		CFMutableArrayRef patterns = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
		CFStringRef key;
		
		/* watch for IPv4 configuration changes (e.g. new default route) */
		key = SCDynamicStoreKeyCreateNetworkGlobalEntity(kCFAllocatorDefault, kSCDynamicStoreDomainState, kSCEntNetIPv4);
		CFArrayAppendValue(keys, key);
		CFRelease(key);
		
		/* as above, but for IPv6 */
		key = SCDynamicStoreKeyCreateNetworkGlobalEntity(kCFAllocatorDefault, kSCDynamicStoreDomainState, kSCEntNetIPv6);
		CFArrayAppendValue(keys, key);
		CFRelease(key);
		
		/* watch for IPv4 interface configuration changes */
		key = SCDynamicStoreKeyCreateNetworkInterfaceEntity(kCFAllocatorDefault, kSCDynamicStoreDomainState, kSCCompAnyRegex, kSCEntNetIPv4);
		CFArrayAppendValue(patterns, key);
		CFRelease(key);
		
		/* as above, but for IPv6 */
		key = SCDynamicStoreKeyCreateNetworkInterfaceEntity(kCFAllocatorDefault, kSCDynamicStoreDomainState, kSCCompAnyRegex, kSCEntNetIPv6);
		CFArrayAppendValue(patterns, key);
		CFRelease(key);
		
		/* watch for DNS interface configuration changes */
		key = SCDynamicStoreKeyCreateNetworkGlobalEntity(kCFAllocatorDefault, kSCDynamicStoreDomainState, kSCEntNetDNS);
		CFArrayAppendValue(keys, key);
		CFRelease(key);
		
        _sourceRef = SCDynamicStoreCreateRunLoopSource(NULL, _storeRef, 0);
        
        if(_sourceRef == NULL) {
            NSLog(@"Error creating the dynamic store runloop source");
        }
		else {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), _sourceRef, kCFRunLoopDefaultMode);
            
            if(!SCDynamicStoreSetNotificationKeys(_storeRef, (CFArrayRef)keys, (CFArrayRef)patterns)) {
                NSLog(@"Error setting the dynamic store notification keys");
            }
			
            CFRelease(_sourceRef);
		}
		
		CFRelease(keys);
		CFRelease(patterns);
	}
}

- (void)stopWatching
{
	if (_sourceRef) {
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _sourceRef, kCFRunLoopDefaultMode);
		CFRelease(_sourceRef);
		_sourceRef = NULL;
	}
}

- (void)_networkChanged
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_notifyNetworkChanged) object:nil];
	[self performSelector:@selector(_notifyNetworkChanged) withObject:nil afterDelay:1.0];
}

- (void)_notifyNetworkChanged
{
	if([_delegate respondsToSelector:@selector(networkConfigurationDidChange:)]) {
		[_delegate networkConfigurationDidChange:self];
	}
}

@end

static void _networkChangeCallBack(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
	@autoreleasepool {
		TPNetworkConfigurationWatcher * self = (__bridge TPNetworkConfigurationWatcher*)info;
		
		BOOL isControlledAsServer = [[TPServerController defaultController] isControlled];
		NSString *serverInterfaceName = [[[TPServerController defaultController] currentConnection] networkInterfaceName];
		
		BOOL isControllingAsClient = [[TPClientController defaultController] isControlling];
		NSString *clientInterfaceName = [[[TPClientController defaultController] currentConnection] networkInterfaceName];
		
		DebugLog(@"Network changed: server(%@, %d); client(%@, %d)", serverInterfaceName, isControlledAsServer, clientInterfaceName, isControllingAsClient);

		serverInterfaceName = isControlledAsServer ? serverInterfaceName : nil;
		clientInterfaceName = isControllingAsClient ? clientInterfaceName : nil;
		
		// Connections in use
		if (serverInterfaceName || clientInterfaceName) {
			for (CFIndex i = 0; i < CFArrayGetCount(changedKeys); i++) {
				CFStringRef key = CFArrayGetValueAtIndex(changedKeys, i);
				CFPropertyListRef value = SCDynamicStoreCopyValue(store, key);

				DebugLog(@"Changed key: %@, value: %@", key, value);

				if (value) {
					CFRelease(value);
				} else {
					// No value for this inf, should be disconnected.
					NSString *keyStr = (__bridge NSString*)key;
					if ((serverInterfaceName && [keyStr hasPrefix:[NSString stringWithFormat:@"State:/Network/Interface/%@", serverInterfaceName]]) ||
						(clientInterfaceName && [keyStr hasPrefix:[NSString stringWithFormat:@"State:/Network/Interface/%@", clientInterfaceName]]) ) {
						// Only notify changes when the corresponding network interface is down.
						[self _networkChanged];
						return;
					}
				}
				
			}
		} else {
			[self _networkChanged];
		}
	}
}

