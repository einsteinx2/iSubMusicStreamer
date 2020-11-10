//
//  ISMSErrorCodes.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#pragma no_pch

#ifndef iSub_ISMSErrorCodes_h
#define iSub_ISMSErrorCodes_h

#define ISMSErrorDomain @"iSub Error Domain"

#define ISMSErrorCode_NotASubsonicServer		1
#define ISMSErrorDesc_NotASubsonicServer		@"This is not a Subsonic server"

#define ISMSErrorCode_NotXML					2
#define ISMSErrorDesc_NotXML					@"This is not XML data"

#define ISMSErrorCode_CouldNotCreateConnection	3
#define ISMSErrorDesc_CouldNotCreateConnection	@"Could not create network connection"

#define ISMSErrorCode_CouldNotSendChatMessage	4
#define ISMSErrorDesc_CouldNotSendChatMessage	@"Could not send chat message"

#define ISMSErrorCode_NoLyricsElement           5
#define ISMSErrorDesc_NoLyricsElement           @"No lyrics XML element found"

#define ISMSErrorCode_NoLyricsFound             6
#define ISMSErrorDesc_NoLyricsFound             @"No lyrics found for this song"

#define ISMSErrorCode_IncorrectCredentials		7
#define ISMSErrorDesc_IncorrectCredentials		@"Incorrect username or password."

#define ISMSErrorCode_CouldNotReachServer		8
#define ISMSErrorDesc_CouldNotReachServer		@"Could not reach the server"

#endif