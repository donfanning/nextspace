/*
   Project: Mixer

   Copyright (C) 2019 Sergii Stoian

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <SoundKit/SoundKit.h>

#import "Mixer.h"

static void *OutputContext = &OutputContext;
static void *InputContext = &InputContext;

@implementation Mixer

- init
{
  self = [super init];
  
  if (window == nil) {
    [NSBundle loadNibNamed:@"Mixer" owner:self];
  }  
  return self;
}

- (void)awakeFromNib
{
  [window setFrameAutosaveName:@"Mixer"];
  [window makeKeyAndOrderFront:self];
  [self fillDeviceList];
}

- (id)window
{
  return window;
}

// Fills "Device" popup with port names
- (void)fillDeviceList
{
  NSString      *title;
  SKSoundServer *server = [SKSoundServer sharedServer];
  NSArray       *deviceList;

  if ([[[modeButton selectedItem] title] isEqualToString:@"Playback"]) {
    NSLog(@"Playback");
    deviceList = [server outputList];
  }
  else {
    NSLog(@"Recording");
    deviceList = [server inputList];
  }
  
  [devicePortBtn removeAllItems];

  for (SKSoundDevice *device in deviceList) {
    NSLog(@"Device: %@", device.description);
    for (NSDictionary *port in [device availablePorts]) {
      title = [NSString stringWithFormat:@"%@",
                      [port objectForKey:@"Description"]];
      [devicePortBtn addItemWithTitle:title];
      [[devicePortBtn itemWithTitle:title] setRepresentedObject:device];
    }
    if ([devicePortBtn numberOfItems] == 0) {
      [devicePortBtn addItemWithTitle:device.name];
      [[devicePortBtn itemWithTitle:device.name] setRepresentedObject:device];
    }
    // KVO for added output
    // FIXME: Ugly
    if ([[[modeButton selectedItem] title] isEqualToString:@"Playback"]) {
      [self observeOutput:(SKSoundOut *)device];
    }
    else {
      [self observeInput:(SKSoundIn *)device];
    }
  }

  if ([[devicePortBtn selectedItem] title] == nil) {
    [deviceMuteBtn setEnabled:NO];
    [devicePortBtn setEnabled:NO];
    [deviceProfileBtn setEnabled:NO];
    [deviceVolumeSlider setEnabled:NO];
    [deviceBalanceSlider setEnabled:NO];
  }
  else {
    [deviceMuteBtn setEnabled:YES];
    [devicePortBtn setEnabled:YES];
    [deviceProfileBtn setEnabled:YES];
    [deviceVolumeSlider setEnabled:YES];
    [deviceBalanceSlider setEnabled:YES];
  }
    
  NSLog(@"Device port selected item: %@ - %@",
        [[[[devicePortBtn selectedItem] representedObject] class] description],
        [[devicePortBtn selectedItem] title]);
  
  [self setDevicePort:devicePortBtn];
}

// "Fills "Profile" popup button.
- (void)fillProfileList
{
  SKSoundOut *device = [[devicePortBtn selectedItem] representedObject];
  
  [deviceProfileBtn removeAllItems];
  for (NSDictionary *profile in [device availableProfiles]) {
    [deviceProfileBtn addItemWithTitle:profile[@"Description"]];
  }
  [deviceProfileBtn selectItemWithTitle:[device activeProfile]];
}

// --- Key-Value Observing
- (void)observeOutput:(SKSoundOut *)output
{
  [output.sink addObserver:self
                forKeyPath:@"mute"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
  [output.sink addObserver:self
                forKeyPath:@"activePort"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
  [output.card addObserver:self
                forKeyPath:@"activeProfile"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
  [output.sink addObserver:self
                forKeyPath:@"channelVolumes"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
}
- (void)observeInput:(SKSoundIn *)input
{
  [input.source addObserver:self
                 forKeyPath:@"mute"
                    options:NSKeyValueObservingOptionNew
                    context:InputContext];
  [input.source addObserver:self
                 forKeyPath:@"activePort"
                    options:NSKeyValueObservingOptionNew
                    context:InputContext];
  [input.card addObserver:self
               forKeyPath:@"activeProfile"
                  options:NSKeyValueObservingOptionNew
                  context:InputContext];
  [input.source addObserver:self
                 forKeyPath:@"channelVolumes"
                    options:NSKeyValueObservingOptionNew
                    context:InputContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  SKSoundOut *output;
  SKSoundIn  *input;
  
  if (context == OutputContext) {
    output = [[devicePortBtn selectedItem] representedObject];
    if (object == output.sink) {
      NSLog(@"SoundOut received change to `%@` object %@ change: %@",
            keyPath, [object className], change);
      if ([keyPath isEqualToString:@"mute"]) {
        [deviceMuteBtn setState:[output isMute]];
      }
      else if ([keyPath isEqualToString:@"activePort"]) {
        NSString *title = [[devicePortBtn selectedItem] title];
        if ([output.activePort isEqualToString:title] == NO) {
          [devicePortBtn selectItemWithTitle:output.activePort];
        }
      }
      else if ([keyPath isEqualToString:@"channelVolumes"]) {
        [deviceVolumeSlider setIntegerValue:[output volume]];
        [deviceBalanceSlider setFloatValue:[output balance]];
      }
    }
    else if (object == output.card) {
      if ([keyPath isEqualToString:@"activeProfile"]) {
        [deviceProfileBtn selectItemWithTitle:output.activeProfile];
      }
    }
  }
  else if (context == InputContext) {
    input = [[devicePortBtn selectedItem] representedObject];
    if (object == input.source) {
      NSLog(@"SoundIn received change to `%@` object %@ change: %@",
            keyPath, [object className], change);
      if ([keyPath isEqualToString:@"mute"]) {
        [deviceMuteBtn setState:[input isMute]];
      }
      else if ([keyPath isEqualToString:@"activePort"]) {
        NSString *title = [[devicePortBtn selectedItem] title];
        if ([input.activePort isEqualToString:title] == NO) {
          [devicePortBtn selectItemWithTitle:input.activePort];
        }
      }
      else if ([keyPath isEqualToString:@"channelVolumes"]) {
        [deviceVolumeSlider setIntegerValue:[input volume]];
        [deviceBalanceSlider setFloatValue:[input balance]];
      }
    }
    else if (object == input.card) {
      if ([keyPath isEqualToString:@"activeProfile"]) {
        [deviceProfileBtn selectItemWithTitle:input.activeProfile];
      }
    }
  } else {
    // Any unrecognized context must belong to super
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
  }
}

- (void)setMode:(id)sender
{
  NSString *title = [[sender selectedItem] title];

  if ([title isEqualToString:@"Playback"]) {
    [deviceBox setTitle:@"Output"];
    [self fillDeviceList];
  }
  else if ([title isEqualToString:@"Recording"]) {
    [deviceBox setTitle:@"Input"];
    [self fillDeviceList];
  }
}

// --- Streams actions
- (void)reloadBrowser:(NSBrowser *)browser
{
  NSString *selected = [[appBrowser selectedCellInColumn:0] title];
    
  [appBrowser reloadColumn:0];
  [appBrowser setTitle:@"Streams" ofColumn:0];

  if (selected == nil) {
    [appBrowser selectRow:0 inColumn:0];
  }
}
 
- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  // NSString      *mode = [[modeButton selectedItem] title];
  // NSBrowserCell *cell;

  // if ([mode isEqualToString:@"Playback"]) {
  //   // Get streams of "sink-input-by-media-role" type first
  //   for (PAStream *st in streamList) {
  //     if ([[st typeName] isEqualToString:@"sink-input-by-media-role"]) {
  //       [matrix addRow];
  //       cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
  //       [cell setLeaf:YES];
  //       [cell setRefusesFirstResponder:YES];
  //       [cell setTitle:[NSString stringWithFormat:@"%@ Sounds", [st clientName]]];
  //       [cell setRepresentedObject:st];
  //     }
  //   }
  //   for (PASinkInput *si in sinkInputList) {
  //     [matrix addRow];
  //     cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
  //     [cell setLeaf:YES];
  //     [cell setRefusesFirstResponder:YES];
  //     [cell setTitle:[si nameForClients:clientList streams:streamList]];
  //     [cell setRepresentedObject:si];
  //   }
  // }
  // else if ([mode isEqualToString:@"Recording"]) {
  //   // TODO
  // }
}

- (void)browserClick:(id)sender
{
  id object = [[sender selectedCellInColumn:0] representedObject];

  if (object == nil) {
    return;
  }
  
  // NSLog(@"Browser received click: %@, cell - %@, repObject - %@",
  //       [sender className], [[sender selectedCellInColumn:0] title],
  //       [[[sender selectedCellInColumn:0] representedObject] className]);
  
  // if ([object respondsToSelector:@selector(volumes)]) {
  //   NSArray *volume = [object volumes];
  //   if (volume != nil && [volume count] > 0) {
  //     [appVolume setFloatValue:[volume[0] floatValue]];
  //   }
  // }
}

- (void)appMuteClick:(id)sender
{
  [[[appBrowser selectedCellInColumn:0] representedObject]
    setMute:[sender state]];
}

// --- Output actions
// "Device" popup action
- (void)setDevicePort:(id)sender
{
  SKSoundDevice *device = [[sender selectedItem] representedObject];

  if ([[device availablePorts] count] > 0) {
    [device setActivePort:[[sender selectedItem] title]];
  }
  [deviceMuteBtn setState:[device isMute]];
  [deviceVolumeSlider setMaxValue:[device volumeSteps]-1];
  [deviceVolumeSlider setIntegerValue:[device volume]];
  [deviceBalanceSlider setFloatValue:[device balance]];
  
  [self fillProfileList];
}
// "Profile" popup action
- (void)setDeviceProfile:(id)sender
{
  SKSoundDevice *device = [[devicePortBtn selectedItem] representedObject];

  [device setActiveProfile:[[deviceProfileBtn selectedItem] title]];
}

- (void)setDeviceMute:(id)sender
{
  [[[devicePortBtn selectedItem] representedObject] setMute:[sender state]];
}

- (void)setDeviceVolume:(id)sender
{
  SKSoundDevice *device = [[devicePortBtn selectedItem] representedObject];

  NSLog(@"Device: set volume to %li (old: %lu)",
        [deviceVolumeSlider integerValue], [device volume]);
  
  [device setVolume:[deviceVolumeSlider integerValue]];
  
  NSLog(@"Output: volume was set to %lu", [device volume]);
}

- (void)setDeviceBalance:(id)sender
{
  SKSoundDevice *device = [[devicePortBtn selectedItem] representedObject];
  
  NSLog(@"Device: set balance: %@", [device className]);
  [device setBalance:[deviceBalanceSlider floatValue]];
}

// --- Window delegate
- (BOOL)windowShouldClose:(id)sender
{
  return YES;
}

@end
