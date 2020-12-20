/* teleport protocol definitions */

#define PROTOCOL_VERSION 19

typedef NS_ENUM(NSInteger, TPMsgType) {
	TPIdentificationMsgType,
	
	/* Authentication */
	TPAuthenticationRequestMsgType,
	TPAuthenticationInProgressMsgType,
	TPAuthenticationAbortMsgType,
	TPAuthenticationSuccessMsgType,
	TPAuthenticationFailureMsgType,
	
	/* Control */
	TPControlRequestMsgType,
	TPControlSuccessMsgType,
	TPControlFailureMsgType,
	TPControlStopMsgType,
	TPControlWakeType,
	TPControlSleepType,
	TPControlLockType,
	
	/* Events */
	TPEventMsgType,
	
	/* Transfers */
	TPTransferRequestMsgType,
	TPTransferSuccessMsgType,
	TPTransferFailureMsgType
/*	TPTransferControlMsgType*/
} ;

typedef unsigned char TPMouseButton;
typedef int64_t TPScrollWheelDistance;
typedef float TPPixelPos;
typedef struct _TPMouseDelta {int64_t x; int64_t y;} TPMouseDelta;
typedef struct _TPKey {CGKeyCode keyCode; CGCharCode charCode;} TPKey;
/*typedef enum {TPLeftSide=0, TPRightSide, TPTopSide, TPBottomSide} TPScreenSide;*/
typedef uint64_t TPDataLength;
typedef unsigned short TPProtocolVersion;
