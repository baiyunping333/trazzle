#define kFDBPrefAcceptTimeout @"$accepttimeout"
#define kFDBPrefURIModification @"$urimodification"
#define kFDBPrefResponseTimeout @"$responsetimeout"
#define kFDBPrefContextResponseTimeout @"$contextresponsetimeout"
#define kFDBPrefGetVarResponseTimeout @"$getvarresponsetimeout"
#define kFDBPrefSetVarResponseTimeout @"$setvarresponsetimeout"
#define kFDBPrefSWFSWDLoadTimeout @"$swfswdloadtimeout"
#define kFDBPrefSuspendWait @"$suspendwait"
#define kFDBPrefInvokeGetters @"$invokegetters"
#define kFDBPrefPlayerSupportsGet @"$playersupportsget"
#define kFDBPrefHierarchicalVariables @"$hiervars"

typedef enum _FDBInMessageType 
{
	kFDBInMessageTypeUnknown = -1, 
	kFDBInMessageTypeSetMenuState = 0, 
	kFDBInMessageTypeSetProperty = 1, 
	kFDBInMessageTypeExit = 2, 
	kFDBInMessageTypeNewObject = 3, 
	kFDBInMessageTypeRemoveObject = 4, 
	kFDBInMessageTypeTrace = 5, 
	kFDBInMessageTypeErrorTarget = 6, 
	kFDBInMessageTypeErrorExecLimit = 7, 
	kFDBInMessageTypeErrorWith = 8, 
	kFDBInMessageTypeErrorProtoLimit = 9, 
	kFDBInMessageTypeSetVariable = 10, 
	kFDBInMessageTypeDeleteVariable = 11, 
	kFDBInMessageTypeParam = 12, 
	kFDBInMessageTypePlaceObject = 13, 
	kFDBInMessageTypeScript = 14, 
	kFDBInMessageTypeAskBreakpoints = 15, 
	kFDBInMessageTypeBreakAt = 16, 
	kFDBInMessageTypeContinue = 17, 
	kFDBInMessageTypeSetLocalVariables = 18, 
	kFDBInMessageTypeSetBreakpoint = 19, 
	kFDBInMessageTypeNumScript = 20, 
	kFDBInMessageTypeRemoveScript = 21, 
	kFDBInMessageTypeRemoveBreakpoint = 22, 
	kFDBInMessageTypeNotSynced = 23, 
	kFDBInMessageTypeErrorURLOpen = 24, 
	kFDBInMessageTypeProcessTag = 25, 
	kFDBInMessageTypeVersion = 26, 
	kFDBInMessageTypeBreakAtExt = 27, 
	kFDBInMessageTypeSetVariable2 = 28, 
	kFDBInMessageTypeSquelch = 29, 
	kFDBInMessageTypeGetVariable = 30, 
	kFDBInMessageTypeFrame = 31, 
	kFDBInMessageTypeOption = 32, 
	kFDBInMessageTypeWatch = 33, 
	kFDBInMessageTypeGetSWF = 34, 
	kFDBInMessageTypeGetSWD = 35, 
	kFDBInMessageTypeErrorException = 36, 
	kFDBInMessageTypeStackUnderflow = 37, 
	kFDBInMessageTypeErrorZeroDivide = 38, 
	kFDBInMessageTypeErrorScriptStuck = 39, 
	kFDBInMessageTypeBreakReason = 40, 
	kFDBInMessageTypeGetActions = 41, 
	kFDBInMessageTypeSWFInfo = 42, 
	kFDBInMessageTypeConstantPool = 43, 
	kFDBInMessageTypeErrorConsole = 44, 
	kFDBInMessageTypeGetFncNames = 45, 
	// 46 through 52 are for profiling
	kFDBInMessageTypeCallFunction = 54, 
	kFDBInMessageTypeWatch2 = 55, 
	kFDBInMessageTypePassAllExceptionsToDebugger = 56, 
	kFDBInMessageTypeBinaryOp = 57
} FDBInMessageType;

typedef enum _FDBOutMessageType
{
	kFDBOutMessageTypeUnknown = -2, 
	kFDBOutMessageTypeZoomIn = 0, 
	kFDBOutMessageTypeZoomOut = 1, 
	kFDBOutMessageTypeZoom100 = 2, 
	kFDBOutMessageTypeHome = 3, 
	kFDBOutMessageTypeSetQuality = 4, 
	kFDBOutMessageTypePlay = 5, 
	kFDBOutMessageTypeLoop = 6, 
	kFDBOutMessageTypeRewind = 7, 
	kFDBOutMessageTypeForward = 8, 
	kFDBOutMessageTypeBack = 9, 
	kFDBOutMessageTypePrint = 10, 
	kFDBOutMessageTypeSetVariable = 11, 
	kFDBOutMessageTypeSetProperty = 12, 
	kFDBOutMessageTypeExit = 13, 
	kFDBOutMessageTypeSetFocus = 14, 
	kFDBOutMessageTypeContinue = 15, 
	kFDBOutMessageTypeStopDebug = 16, 
	kFDBOutMessageTypeSetBreakpoints = 17, 
	kFDBOutMessageTypeRemoveBreakpoints = 18, 
	kFDBOutMessageTypeRemoveAllBreakpoints = 19, 
	kFDBOutMessageTypeStepOver = 20, 
	kFDBOutMessageTypeStepInto = 21, 
	kFDBOutMessageTypeStepOut = 22, 
	kFDBOutMessageTypeProcessedTag = 23, 
	kFDBOutMessageTypeSetSquelch = 24, 
	kFDBOutMessageTypeGetVariable = 25, 
	kFDBOutMessageTypeGetFrame = 26, 
	kFDBOutMessageTypeGetOption = 27, 
	kFDBOutMessageTypeSetOption = 28, 
	kFDBOutMessageTypeAddWatch = 29, 
	kFDBOutMessageTypeRemoveWatch = 30, 
	kFDBOutMessageTypeStepContinue = 31, 
	kFDBOutMessageTypeGetSWF = 32, 
	kFDBOutMessageTypeGetSWD = 33, 
	kFDBOutMessageTypeGetVariableWhichInvokesGetter = 34, 
	kFDBOutMessageTypeGetBreakReason = 35, 
	kFDBOutMessageTypeGetActions = 36, 
	kFDBOutMessageTypeSetActions = 37, 
	kFDBOutMessageTypeSWFInfo = 38, 
	kFDBOutMessageTypeConstantPool = 39, 
	kFDBOutMessageTypeOutGetFncNames = 40, 
	// 41 through 47 are for profiling
	kFDBOutMessageTypeCallFunction = 48, 
	kFDBOutMessageTypeAddWatch2 = 49, 
	kFDBOutMessageTypeRemoveWatch2 = 50, 
	kFDBOutMessageTypePassAllExceptionsToDebugger = 51, 
	kFDBOutMessageTypeBinaryOp = 51
} FDBOutMessage;