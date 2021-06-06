//
//  TPConnectionsManager.m
//  teleport
//
//  Created by JuL on 24/02/06.
//  Copyright 2006 abyssoft. All rights reserved.
//

#import "TPConnectionsManager.h"
//#import "TPNetworkConnection_Private.h"
#import "TPPreferencesManager.h"
#import "TPMainController.h"
#import "TPHostsManager.h"
#import "TPTCPSecureSocket.h"
#import "TPLocalHost.h"
#import "TPRemoteHost.h"
#import "TPMessage.h"

static NSString * TPMsgProtocolVersionKey = @"proto-version";
static NSString * TPMsgHostDataKey = @"host-data";

static TPConnectionsManager * _connectionsManager = nil;

@class _TPSocketConnection;

@interface TPConnectionsManager (Internal)

+ (TPMessage*)_identificationMessage;

- (void)_socketConnectionFailed:(_TPSocketConnection*)socketConnection;
- (void)_socketConnection:(_TPSocketConnection*)socketConnection succeededWithNetworkConnection:(TPNetworkConnection*)networkConnection;

@end

@interface _TPSocketConnection : NSObject
{
	@public
	TPTCPSecureSocket * _socket;
	TPRemoteHost * _host;
	NSDictionary * _infoDict;
	TPNetworkConnection * _connection;
	id _delegate;
}

- (instancetype) initWithConnectionToHost:(TPRemoteHost*)remoteHost delegate:(id)delegate infoDict:(NSDictionary*)infoDict NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, strong) TPRemoteHost *host;
@property (nonatomic, readonly, copy) NSDictionary *infoDict;
@property (nonatomic, readonly, unsafe_unretained) id delegate;

@end

@implementation _TPSocketConnection

- (instancetype) initWithConnectionToHost:(TPRemoteHost*)remoteHost delegate:(id)delegate infoDict:(NSDictionary*)infoDict
{
	self = [super init];
	
	PRINT_ME;
	
	_host = remoteHost;
	_infoDict = infoDict;
	_delegate = delegate;
	_socket = [[TPTCPSecureSocket alloc] initWithDelegate:self];
	
	BOOL enableEncryption = [[TPLocalHost localHost] pairWithHost:remoteHost hasCapability:TPHostEncryptionCapability];
	[_socket setEnableEncryption:enableEncryption];
	[_socket connectToHost:[remoteHost address] onPort:[remoteHost port]];
	[_socket setNoDelay:YES];

	return self;
}


- (TPRemoteHost*)host
{
	return _host;
}

- (id)delegate
{
	return _delegate;
}

- (NSDictionary*)infoDict
{
	return _infoDict;
}

- (SecIdentityRef)tcpSecureSocketCopyIdentity:(TPTCPSecureSocket*)tcpSocket
{
	return [[TPConnectionsManager manager] tcpSecureSocketCopyIdentity:tcpSocket];
}

- (void)tcpSocketConnectionSucceeded:(TPTCPSocket*)tcpSocket
{
	PRINT_ME;
	_connection = [[TPNetworkConnection alloc] initWithSocket:tcpSocket];
	
	[_connection setDelegate:self];
	[_connection sendMessage:[TPConnectionsManager _identificationMessage]];
}

- (void)tcpSocketSecureConnectionSucceeded:(TPTCPSecureSocket*)tcpSocket
{
	SecCertificateRef certRef = [tcpSocket copyPeerCertificate];
	[_host setCertificate:certRef];
	CFRelease(certRef);
	
	[self tcpSocketConnectionSucceeded:tcpSocket];
}

- (void)tcpSocketConnectionFailed:(TPTCPSocket*)tcpSocket
{
	PRINT_ME;
	[[TPConnectionsManager manager] _socketConnectionFailed:self];
}

- (void)tcpSocketSecureConnectionFailed:(TPTCPSecureSocket*)tcpSocket
{
	PRINT_ME;
	[[TPConnectionsManager manager] _socketConnectionFailed:self];
}

- (void)connection:(TPNetworkConnection*)connection receivedMessage:(TPMessage*)message
{
	PRINT_ME;
	if([message msgType] == TPIdentificationMsgType) {
		NSDictionary * infoDict = [message infoDict];
		int protocolVersion = [infoDict[TPMsgProtocolVersionKey] intValue];
		
		if(protocolVersion == PROTOCOL_VERSION) {
			NSData * hostData = infoDict[TPMsgHostDataKey];
			TPRemoteHost * remoteHost = [[TPHostsManager defaultManager] updatedHostFromData:hostData];
			
			[connection setConnectedHost:remoteHost];
			
			[[TPConnectionsManager manager] _socketConnection:self succeededWithNetworkConnection:connection];
		}
		else {
			NSAlert * alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Wrong protocol version", @"Invalid protocol error title") defaultButton:NSLocalizedString(@"OK", nil) alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"The Mac you tried to control is using teleport protocol v%d, but you're using v%d.", @"Invalid protocol error message"), protocolVersion, PROTOCOL_VERSION];
			[(TPMainController*)[NSApp delegate] presentAlert:alert];
			
			[[TPConnectionsManager manager] _socketConnectionFailed:self];
		}
	}
	else {
		NSLog(@"received invalid msg type: %ld (expected identification - %ld)", [message msgType], (long)TPIdentificationMsgType);
		
		[[TPConnectionsManager manager] _socketConnectionFailed:self];
	}
}

@end

@implementation TPConnectionsManager

+ (TPConnectionsManager*)manager
{
	if(_connectionsManager == nil)
		_connectionsManager = [[TPConnectionsManager alloc] init];
	return _connectionsManager;
}

+ (TPMessage*)_identificationMessage
{
	NSDictionary * infoDict = @{TPMsgProtocolVersionKey: @PROTOCOL_VERSION,
		TPMsgHostDataKey: [[TPLocalHost localHost] hostData]};
	
	return [TPMessage messageWithType:TPIdentificationMsgType andInfoDict:infoDict];
}

- (instancetype) init
{
	self = [super init];
	
	_connections = [[NSMutableSet alloc] init];
	_pendingConnections = [[NSMutableDictionary alloc] init];
	
	return self;
}


- (void)connectToHost:(TPRemoteHost*)host withDelegate:(id)delegate infoDict:(NSDictionary*)infoDict
{
	PRINT_ME;
	
	_TPSocketConnection * connection = _pendingConnections[[host identifier]];
	if(connection == nil) {
		connection = [[_TPSocketConnection alloc] initWithConnectionToHost:host delegate:delegate infoDict:infoDict];
		_pendingConnections[[host identifier]] = connection;
	}
}

- (BOOL)startListeningWithDelegate:(id)delegate onPort:(int*)port
{
	if(_listenSocket != nil)
		return YES;
	
	_listenDelegate = delegate;
	
	BOOL enableEncryption = [[TPLocalHost localHost] hasCapability:TPHostEncryptionCapability];
	_listenSocket = [[TPTCPSecureSocket alloc] initWithDelegate:self];
	[_listenSocket setEnableEncryption:enableEncryption];
	
	return [_listenSocket listenOnPort:port tries:50];
}

- (void)stopListening
{
	[_listenSocket close];
	_listenSocket = nil;
}


#pragma mark -
#pragma mark Socket connection

- (void)_socketConnectionFailed:(_TPSocketConnection*)socketConnection
{	
	id delegate = [socketConnection delegate];
	TPRemoteHost * host = [socketConnection host];
	
	if(delegate && [delegate respondsToSelector:@selector(connectionToServerFailed:infoDict:)])
		[delegate connectionToServerFailed:host infoDict:[socketConnection infoDict]];
	
	[_pendingConnections removeObjectForKey:[host identifier]];
}

- (void)_socketConnection:(_TPSocketConnection*)socketConnection succeededWithNetworkConnection:(TPNetworkConnection*)networkConnection
{
	id delegate = [socketConnection delegate];
	TPRemoteHost * host = [socketConnection host];
	
	if(delegate && [delegate respondsToSelector:@selector(connectionToServerSucceeded:infoDict:)])
		[delegate connectionToServerSucceeded:networkConnection infoDict:[socketConnection infoDict]];
	
	[_pendingConnections removeObjectForKey:[host identifier]];
}


#pragma mark -
#pragma mark Wake on LAN

- (BOOL)wakeUpHost:(TPRemoteHost*)host
{
	if([host hasValidMACAddress]) {
		DebugLog(@"trying to wake up host %@", host);
		return [TPTCPSocket wakeUpHostWithMACAddress:[host MACAddress]];
	}
	else
		return NO;
}


#pragma mark -
#pragma mark Listen socket delegate

- (void)tcpSocket:(TPTCPSocket*)listenSocket connectionAccepted:(TPTCPSocket*)childSocket
{
	DebugLog(@"connection accepted from %@ on %@", listenSocket, childSocket);
	
	[childSocket setNoDelay:YES];
	
	TPNetworkConnection * connection = [[TPNetworkConnection alloc] initWithSocket:childSocket];
	
	[connection setDelegate:self];
	[connection sendMessage:[TPConnectionsManager _identificationMessage]];
	[_connections addObject:connection];
}

- (BOOL)tcpSecureSocketShouldEnableEncryption:(TPTCPSecureSocket*)tcpSocket
{
	NSString * remoteAddress = [tcpSocket remoteAddress];
	TPRemoteHost * remoteHost = [[TPHostsManager defaultManager] hostWithAddress:remoteAddress];
	if(remoteHost == nil) {
		BOOL encryptionActive = [[TPPreferencesManager sharedPreferencesManager] boolForPref:ENABLED_ENCRYPTION];
		NSLog(@"could not determine which host has IP %@, will%s use encryption as it is configured so locally", remoteAddress, encryptionActive ? "" : " NOT");
		return encryptionActive; // encrypted by default, if encryption is enabled locally
	}
	else {
		return [[TPLocalHost localHost] pairWithHost:remoteHost hasCapability:TPHostEncryptionCapability];
	}
}

- (void)tcpSocket:(TPTCPSecureSocket*)listenSocket secureConnectionAccepted:(TPTCPSecureSocket*)childSocket
{
	[self tcpSocket:listenSocket connectionAccepted:childSocket];
}

- (SecIdentityRef)tcpSecureSocketCopyIdentity:(TPTCPSecureSocket*)tcpSocket
{
	SecIdentityRef identity = [[TPLocalHost localHost] identity];
	if(identity == NULL) {
		return NULL;
	}
	else {
		return (SecIdentityRef)CFRetain(identity);
	}
}

- (void)connection:(TPNetworkConnection*)connection receivedMessage:(TPMessage*)message
{
	if([message msgType] == TPIdentificationMsgType) {
		NSDictionary * infoDict = [message infoDict];
		int protocolVersion = [infoDict[TPMsgProtocolVersionKey] intValue];
		
		if(protocolVersion == PROTOCOL_VERSION) {
			NSData * hostData = infoDict[TPMsgHostDataKey];
			TPRemoteHost * remoteHost = [[TPHostsManager defaultManager] updatedHostFromData:hostData];
			
			[connection setConnectedHost:remoteHost];
			[[TPHostsManager defaultManager] addClientHost:remoteHost];
			
			if(_listenDelegate && [_listenDelegate respondsToSelector:@selector(connectionFromClientAccepted:)])
				[_listenDelegate connectionFromClientAccepted:connection];
		}
		else
			NSLog(@"received message with invalid protocol (%d vs %d)", protocolVersion, PROTOCOL_VERSION);
	}
	else {
		NSLog(@"received invalid msg type: %ld (excepted identification - %ld)", [message msgType], (long)TPIdentificationMsgType);
	}
}

- (void)connectionDisconnected:(TPNetworkConnection *)connection
{
	[_connections removeObject:connection];
}

@end
