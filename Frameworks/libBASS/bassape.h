/*
	BASSAPE 2.4 C/C++ header file
	Copyright (c) 2022 Un4seen Developments Ltd.

	See the BASSAPE.CHM file for more detailed documentation
*/

#ifndef BASSAPE_H
#define BASSAPE_H

#include "bass.h"

#if BASSVERSION!=0x204
#error conflicting BASS and BASSAPE versions
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef BASSAPEDEF
#define BASSAPEDEF(f) WINAPI f
#endif

// BASS_CHANNELINFO type
#define BASS_CTYPE_STREAM_APE	0x10700

HSTREAM BASSAPEDEF(BASS_APE_StreamCreateFile)(BOOL mem, const void *file, QWORD offset, QWORD length, DWORD flags);
HSTREAM BASSAPEDEF(BASS_APE_StreamCreateURL)(const char *url, DWORD offset, DWORD flags, DOWNLOADPROC *proc, void *user);
HSTREAM BASSAPEDEF(BASS_APE_StreamCreateFileUser)(DWORD system, DWORD flags, const BASS_FILEPROCS *procs, void *user);

#ifdef __cplusplus
}

#if defined(_WIN32) && !defined(NOBASSOVERLOADS)
static inline HSTREAM BASS_APE_StreamCreateFile(BOOL mem, const WCHAR *file, QWORD offset, QWORD length, DWORD flags)
{
	return BASS_APE_StreamCreateFile(mem, (const void*)file, offset, length, flags | BASS_UNICODE);
}

static inline HSTREAM BASS_APE_StreamCreateURL(const WCHAR *url, DWORD offset, DWORD flags, DOWNLOADPROC *proc, void *user)
{
	return BASS_APE_StreamCreateURL((const char*)url, offset, flags | BASS_UNICODE, proc, user);
}
#endif
#endif

#endif
