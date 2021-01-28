//
//  BassPluginLoad.c
//  iSub
//
//  Created by Benjamin Baron on 1/25/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

#include "BassPluginLoad.h"
#import "bass.h"

extern void BASSFLACplugin, BASSWVplugin, BASS_APEplugin, BASS_MPCplugin, BASSOPUSplugin;

void bassLoadPlugins() {
    BASS_PluginLoad(&BASSFLACplugin, 0); // load the Flac plugin
    BASS_PluginLoad(&BASSWVplugin, 0); // load the WavePack plugin
    BASS_PluginLoad(&BASS_APEplugin, 0); // load the Monkey's Audio plugin
    //BASS_PluginLoad(&BASS_MPCplugin, 0); // load the MusePack plugin
    BASS_PluginLoad(&BASSOPUSplugin, 0); // load the OPUS plugin
}
