//
//  BassWrapper.m
//  iSub
//
//  Created by Ben Baron on 6/27/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassWrapper.h"
#import "ISMSSong+DAO.h"
#import "Defines.h"
#import "EX2Kit.h"

LOG_LEVEL_ISUB_DEFAULT

#define ISMS_BASSBufferSize 800
#define ISMS_defaultSampleRate 44100

@implementation BassWrapper

extern void BASSFLACplugin, BASSWVplugin, BASS_APEplugin, BASS_MPCplugin, BASSOPUSplugin;

static NSUInteger _bassOutputBufferLengthMillis = 0;

+ (NSUInteger)bassOutputBufferLengthMillis
{
    return _bassOutputBufferLengthMillis;
}

+ (void)bassInit:(NSUInteger)sampleRate
{
    // Free BASS just in case we use this after launch
    BASS_Free();
    
	// Initialize BASS
	BASS_SetConfig(BASS_CONFIG_IOS_MIXAUDIO, 0); // Disable mixing.	To be called before BASS_Init.
	BASS_SetConfig(BASS_CONFIG_BUFFER, BASS_GetConfig(BASS_CONFIG_UPDATEPERIOD) + ISMS_BASSBufferSize); // set the buffer length to the minimum amount + 200ms
	BASS_SetConfig(BASS_CONFIG_FLOATDSP, true); // set DSP effects to use floating point math to avoid clipping within the effects chain
	if (BASS_Init(1, (DWORD)sampleRate, 0, NULL, NULL)) 	// Initialize default device.
	{
        _bassOutputBufferLengthMillis = BASS_GetConfig(BASS_CONFIG_BUFFER);
        
        BASS_PluginLoad(&BASSFLACplugin, 0); // load the Flac plugin
        BASS_PluginLoad(&BASSWVplugin, 0); // load the WavePack plugin
        BASS_PluginLoad(&BASS_APEplugin, 0); // load the Monkey's Audio plugin
        //BASS_PluginLoad(&BASS_MPCplugin, 0); // load the MusePack plugin
        BASS_PluginLoad(&BASSOPUSplugin, 0); // load the OPUS plugin
	}
    else
    {
        _bassOutputBufferLengthMillis = 0;
        DDLogError(@"[BassWrapper] Can't initialize device");
        [BassWrapper logError];
    }
	
	//[audioEngineS startEmptyPlayer];
    
	//[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_BassInitialized];
}

+ (void)bassInit
{
	// Default to 44.1 KHz
    [self bassInit:ISMS_defaultSampleRate];
}

+ (void)logError
{
	int errorCode = BASS_ErrorGetCode();
	DDLogError(@"[BassWrapper] BASS error: %i - %@", errorCode, [BassWrapper stringFromErrorCode:errorCode]);
}

+ (void)printChannelInfo:(HSTREAM)channel
{
#ifdef DEBUG
	//BASS_CHANNELINFO i;
	//BASS_ChannelGetInfo(channel, &i);
	//QWORD bytes = BASS_ChannelGetLength(channel, BASS_POS_BYTE);
	//DWORD time = BASS_ChannelBytes2Seconds(channel, bytes);
	//DDLogInfo("[BassWrapper] channel type = %x (%@)\nlength = %llu (%u:%02u)  flags: %i  freq: %i  origres: %i", i.ctype, [BassWrapper formatForChannel:channel], bytes, time/60, time%60, i.flags, i.freq, i.origres);
#endif
}

+ (NSString *)formatForChannel:(HCHANNEL)channel
{
	BASS_CHANNELINFO i;
	BASS_ChannelGetInfo(channel, &i);
	
	/*if (plugin) 
	 { 
	 // using a plugin
	 const BASS_PLUGININFO *pinfo=BASS_PluginGetInfo(plugin); // get plugin info
	 int a;
	 for (a=0;a<pinfo->formatc;a++) 
	 {
	 if (pinfo->formats[a].ctype==ctype) // found a "ctype" match...
	 return [NSString stringWithFormat:@"%s", pinfo->formats[a].name]; // return it's name
	 }
	 }*/ 
	// check built-in stream formats...
    if (i.ctype==BASS_CTYPE_STREAM_WV) return @"WV";
	if (i.ctype==BASS_CTYPE_STREAM_MPC) return @"MPC";
	if (i.ctype==BASS_CTYPE_STREAM_APE) return @"APE";
	if (i.ctype==BASS_CTYPE_STREAM_FLAC) return @"FLAC";
	if (i.ctype==BASS_CTYPE_STREAM_FLAC_OGG) return @"FLAC";
	if (i.ctype==BASS_CTYPE_STREAM_OGG) return @"OGG";
	if (i.ctype==BASS_CTYPE_STREAM_MP1) return @"MP1";
	if (i.ctype==BASS_CTYPE_STREAM_MP2) return @"MP2";
	if (i.ctype==BASS_CTYPE_STREAM_MP3) return @"MP3";
	if (i.ctype==BASS_CTYPE_STREAM_AIFF) return @"AIFF";
    if (i.ctype==BASS_CTYPE_STREAM_OPUS) return @"Opus";
	if (i.ctype==BASS_CTYPE_STREAM_WAV_PCM) return @"PCM WAV";
	if (i.ctype==BASS_CTYPE_STREAM_WAV_FLOAT) return @"Float WAV";
	if (i.ctype&BASS_CTYPE_STREAM_WAV) return @"WAV";
	if (i.ctype==BASS_CTYPE_STREAM_CA) 
	{
		// CoreAudio codec
		const TAG_CA_CODEC *codec = (TAG_CA_CODEC*)BASS_ChannelGetTags(channel, BASS_TAG_CA_CODEC); // get codec info
		if (codec != NULL)
		{
			switch (codec->atype) 
			{
				case kAudioFormatLinearPCM:				return @"LPCM";
				case kAudioFormatAC3:					return @"AC3";
				case kAudioFormat60958AC3:				return @"AC3";
				case kAudioFormatAppleIMA4:				return @"IMA4";
				case kAudioFormatMPEG4AAC:				return @"AAC"; 
				case kAudioFormatMPEG4CELP:				return @"CELP";
				case kAudioFormatMPEG4HVXC:				return @"HVXC";
				case kAudioFormatMPEG4TwinVQ:			return @"TwinVQ";
				case kAudioFormatMACE3:					return @"MACE 3:1";
				case kAudioFormatMACE6:					return @"MACE 6:1";
				case kAudioFormatULaw:					return @"μLaw 2:1";
				case kAudioFormatALaw:					return @"aLaw 2:1";
				case kAudioFormatQDesign:				return @"QDMC";
				case kAudioFormatQDesign2:				return @"QDM2";
				case kAudioFormatQUALCOMM:				return @"QCPV";
				case kAudioFormatMPEGLayer1:			return @"MP1";
				case kAudioFormatMPEGLayer2:			return @"MP2";
				case kAudioFormatMPEGLayer3:			return @"MP3";
				case kAudioFormatTimeCode:				return @"TIME";
				case kAudioFormatMIDIStream:			return @"MIDI";
				case kAudioFormatParameterValueStream:	return @"APVS";
				case kAudioFormatAppleLossless:			return @"ALAC";
				case kAudioFormatMPEG4AAC_HE:			return @"AAC-HE";
				case kAudioFormatMPEG4AAC_LD:			return @"AAC-LD";
				case kAudioFormatMPEG4AAC_ELD:			return @"AAC-ELD";
				case kAudioFormatMPEG4AAC_ELD_SBR:		return @"AAC-SBR";
				case kAudioFormatMPEG4AAC_HE_V2:		return @"AAC-HEv2";
				case kAudioFormatMPEG4AAC_Spatial:		return @"AAC-S";
				case kAudioFormatAMR:					return @"AMR";
				case kAudioFormatAudible:				return @"AUDB";
				case kAudioFormatiLBC:					return @"iLBC";
				case kAudioFormatDVIIntelIMA:			return @"ADPCM";
				case kAudioFormatMicrosoftGSM:			return @"GSM";
				case kAudioFormatAES3:					return @"AES3";
				default:								return @" ";
			}
		}
	}
	return @"";
}

+ (NSString *)stringFromErrorCode:(NSInteger)errorCode
{
	switch (errorCode)
	{
		case BASS_OK:				return @"No error! All OK";
		case BASS_ERROR_MEM:		return @"Memory error";
		case BASS_ERROR_FILEOPEN:	return @"Can't open the file";
		case BASS_ERROR_DRIVER:		return @"Can't find a free/valid driver";
		case BASS_ERROR_BUFLOST:	return @"The sample buffer was lost";
		case BASS_ERROR_HANDLE:		return @"Invalid handle";
		case BASS_ERROR_FORMAT:		return @"Unsupported sample format";
		case BASS_ERROR_POSITION:	return @"Invalid position";
		case BASS_ERROR_INIT:		return @"BASS_Init has not been successfully called";
		case BASS_ERROR_START:		return @"BASS_Start has not been successfully called";
		case BASS_ERROR_ALREADY:	return @"Already initialized/paused/whatever";
		case BASS_ERROR_NOCHAN:		return @"Can't get a free channel";
		case BASS_ERROR_ILLTYPE:	return @"An illegal type was specified";
		case BASS_ERROR_ILLPARAM:	return @"An illegal parameter was specified";
		case BASS_ERROR_NO3D:		return @"No 3D support";
		case BASS_ERROR_NOEAX:		return @"No EAX support";
		case BASS_ERROR_DEVICE:		return @"Illegal device number";
		case BASS_ERROR_NOPLAY:		return @"Not playing";
		case BASS_ERROR_FREQ:		return @"Illegal sample rate";
		case BASS_ERROR_NOTFILE:	return @"The stream is not a file stream";
		case BASS_ERROR_NOHW:		return @"No hardware voices available";
		case BASS_ERROR_EMPTY:		return @"The MOD music has no sequence data";
		case BASS_ERROR_NONET:		return @"No internet connection could be opened";
		case BASS_ERROR_CREATE:		return @"Couldn't create the file";
		case BASS_ERROR_NOFX:		return @"Effects are not available";
		case BASS_ERROR_NOTAVAIL:	return @"Requested data is not available";
		case BASS_ERROR_DECODE:		return @"The channel is a 'decoding channel'";
		case BASS_ERROR_DX:			return @"A sufficient DirectX version is not installed";
		case BASS_ERROR_TIMEOUT:	return @"Connection timedout";
		case BASS_ERROR_FILEFORM:	return @"Unsupported file format";
		case BASS_ERROR_SPEAKER:	return @"Unavailable speaker";
		case BASS_ERROR_VERSION:	return @"Invalid BASS version (used by add-ons)";
		case BASS_ERROR_CODEC:		return @"Codec is not available/supported";
		case BASS_ERROR_ENDED:		return @"The channel/file has ended";
		case BASS_ERROR_BUSY:		return @"The device is busy";
		case BASS_ERROR_UNKNOWN:
		default:					return @"Unknown error.";
	}
}

+ (NSUInteger)estimateBitrate:(BassStream *)bassStream
{	
	// Default to the player bitrate
	HSTREAM stream = bassStream.stream;
	QWORD startFilePosition = 0;
	QWORD currentFilePosition = BASS_StreamGetFilePosition(stream, BASS_FILEPOS_CURRENT);
	QWORD filePosition = currentFilePosition - startFilePosition;
	QWORD decodedPosition = BASS_ChannelGetPosition(stream, BASS_POS_BYTE|BASS_POS_DECODE); // decoded PCM position
	double bitrateDouble = filePosition * 8 / BASS_ChannelBytes2Seconds(stream, decodedPosition);
	NSUInteger bitrate = (NSUInteger)(bitrateDouble / 1000);
	bitrate = bitrate > 1000000 ? -1 : bitrate;
	
	BASS_CHANNELINFO i;
	BASS_ChannelGetInfo(bassStream.stream, &i);
	ISMSSong *songForStream = bassStream.song;
	
	// Check the current stream format, and make sure that the bitrate is in the correct range
	// otherwise use the song's estimated bitrate instead (to keep something like a 10000 kbitrate on an mp3 from being used for buffering)
	switch (i.ctype) 
	{
		case BASS_CTYPE_STREAM_WAV_PCM:
		case BASS_CTYPE_STREAM_WAV_FLOAT:
		case BASS_CTYPE_STREAM_WAV:
		case BASS_CTYPE_STREAM_AIFF:
        case BASS_CTYPE_STREAM_WV:
        case BASS_CTYPE_STREAM_FLAC:
        case BASS_CTYPE_STREAM_FLAC_OGG:
			if (bitrate < 330 || bitrate > 12000)
				bitrate = songForStream.estimatedBitrate;
			break;
			
		case BASS_CTYPE_STREAM_OGG:	
		case BASS_CTYPE_STREAM_MP1:
		case BASS_CTYPE_STREAM_MP2:
		case BASS_CTYPE_STREAM_MP3:
        case BASS_CTYPE_STREAM_MPC:
			if (bitrate > 450)
				bitrate = songForStream.estimatedBitrate;
			break;	
			
		case BASS_CTYPE_STREAM_CA:
		{
			const TAG_CA_CODEC *codec = (TAG_CA_CODEC*)BASS_ChannelGetTags(stream, BASS_TAG_CA_CODEC);
			switch (codec->atype) 
			{
				case kAudioFormatLinearPCM:	
				case kAudioFormatAppleLossless:
					if (bitrate < 330 || bitrate > 12000)
						bitrate = songForStream.estimatedBitrate;
					break;
					
				case kAudioFormatMPEG4AAC:
				case kAudioFormatMPEG4AAC_HE:
				case kAudioFormatMPEG4AAC_LD:
				case kAudioFormatMPEG4AAC_ELD:
				case kAudioFormatMPEG4AAC_ELD_SBR:
				case kAudioFormatMPEG4AAC_HE_V2:
				case kAudioFormatMPEG4AAC_Spatial:
				case kAudioFormatMPEGLayer1:
				case kAudioFormatMPEGLayer2:
				case kAudioFormatMPEGLayer3:
					if (bitrate > 450)
						bitrate = songForStream.estimatedBitrate;
					break;
					
					// If we can't detect the format, use the estimated bitrate instead of player to be safe
				default:
					bitrate = songForStream.estimatedBitrate;
					break;
			}
			break;
		}
			
			// If we can't detect the format, use the estimated bitrate instead of player to be safe
		default:
			bitrate = songForStream.estimatedBitrate;
			break;
	}
	
	return bitrate;
}

@end
