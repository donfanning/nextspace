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

#import <dispatch/dispatch.h>

#import "ALSAElement.h"
#import "ALSACard.h"

  
static dispatch_queue_t event_loop_q;
static dispatch_block_t event_loop_block;

@implementation ALSACard

- (void)dealloc
{
  if (isEventLoopActive != NO) {
    [self quitEventLoop];
  }
  
  if (alsa_mixer != NULL) {
    [self deleteMixer:alsa_mixer];
  }

  [cardName release];
  [chipName release];
  [deviceName release];
  
  if (controls) {
    [controls release];
  }

  [super dealloc];
}

- initWithNumber:(int)number
{
  snd_ctl_card_info_t *info;
  char                buf[16];
  snd_ctl_t           *ctl;

  [super init];

  NSLog(@"ALSACard: init with number %d", number);

  snd_ctl_card_info_alloca(&info);
  
  if (number < 0) {
    snd_mixer_t *mixer;
    snd_hctl_t  *hctl;

    deviceName = [[NSString alloc] initWithString:@"default"];
    mixer = [self createMixer];

    if (snd_mixer_get_hctl(mixer, [deviceName cString], &hctl) >= 0) {
      ctl = snd_hctl_ctl(hctl);
      if (snd_ctl_card_info(ctl, info) >= 0) {
        cardName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_name(info)];
        chipName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_mixername(info)];
      }
    }
  
    [self deleteMixer:mixer];
  }
  else {
    sprintf(buf, "hw:%d", number);
    if (snd_ctl_open(&ctl, buf, 0) < 0) {
      return nil;
    }
    
    if (snd_ctl_card_info(ctl, info) < 0) {
      snd_ctl_close(ctl);
      return nil;
    }
    
    cardName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_name(info)];
    deviceName = [[NSString alloc] initWithFormat:@"hw:%d", number];

    alsa_mixer = [self createMixer];
    chipName = [[NSString alloc] initWithCString:snd_ctl_card_info_get_mixername(info)];

    snd_ctl_close(ctl);
  }
  
  alsa_mixer = [self createMixer];
  if (alsa_mixer) {
    snd_mixer_elem_t *elem;
 
    // fprintf(stderr, "Mixer elements for card `%s`:\n", [deviceName cString]);
    controls = [[NSMutableArray alloc] init];
    for (elem = snd_mixer_first_elem(alsa_mixer); elem; elem = snd_mixer_elem_next(elem)) {
      [controls addObject:[[ALSAElement alloc] initWithCard:self element:elem]];
    }
  }

  shouldHandleEvents = NO;
  // timer = [NSTimer scheduledTimerWithTimeInterval:.5
  //                                          target:self
  //                                        selector:@selector(handleEvents)
  //                                        userInfo:nil
  //                                         repeats:YES];
  return self;
}

- (void)handleEvents
{
  int            poll_count, fill_count;
  struct pollfd  *pollfds;
  unsigned short revents;
  int            n;

  if (shouldHandleEvents == NO) {
    sleep(1);
    return;
  }

  poll_count = snd_mixer_poll_descriptors_count(alsa_mixer);
  if (poll_count <= 0) {
    NSLog(@"Cannot obtain mixer poll descriptors.");
  }

  // pollfds = alloca((poll_count + 1) * sizeof(struct pollfd));
  pollfds = alloca(poll_count * sizeof(struct pollfd));
  fill_count = snd_mixer_poll_descriptors(alsa_mixer, pollfds, poll_count);
  NSAssert(poll_count = fill_count, @"poll counts differ");

  // n = poll(pollfds, fill_count + 1, -1);
  n = poll(pollfds, poll_count, -1);

  if (n > 0) {
    /* Ensure that changes made via other programs (alsamixer, etc.) get
       reflected as well.  */
    snd_mixer_poll_descriptors_revents(alsa_mixer, pollfds, poll_count, &revents);
    if (revents & POLLIN) {
      snd_mixer_handle_events(alsa_mixer);
      [controls makeObjectsPerform:@selector(refresh)];
    }
  }
}

- (void)enterEventLoop
{
  if (isEventLoopCreated != NO) {
    NSLog(@"[ALSACard entereventloop] event loop already created. Resuming...");
    [self resumeEventLoop];
    return;
  }

  event_loop_q = dispatch_queue_create("org.nextspace.alsamixer", NULL);
  isEventLoopActive = YES;
  shouldHandleEvents = YES;

  event_loop_block = dispatch_block_create(0, ^{
      while (isEventLoopActive != NO) {
        [self handleEvents];
      }
      fprintf(stderr, "ALSACard event loop quit.\n");
    });
  dispatch_async(event_loop_q, event_loop_block);
  isEventLoopCreated = YES;

  // dispatch_async(event_loop_q, ^{
  //     while (isEventLoopActive != NO) {
  //       [self handleEvents];
  //     }
  //     fprintf(stderr, "ALSACard event loop quit.\n");
  //   });
}

- (void)pauseEventLoop
{
  if (isEventLoopCreated == NO) {
    NSLog(@"[ALSACard pauseEventLoop] event loop was not created! Call -enterEventLoop first.");
    return;
  }
  shouldHandleEvents = NO;
}

- (void)resumeEventLoop
{
  if (isEventLoopCreated == NO) {
    NSLog(@"[ALSACard resumeEventLoop] event loop was not created! Call -enterEventLoop first.");
    return;
  }
  shouldHandleEvents = YES;
}

- (void)quitEventLoop
{
  if (isEventLoopCreated == NO) {
    NSLog(@"[ALSACard quitEventLoop] event loop was not created! Call -enterEventLoop first.");
    return;
  }
  shouldHandleEvents = NO; // stops processing events
  isEventLoopActive = NO;  // finishes running of dispatched block

  // dispatch_block_cancel(event_loop_block);
  dispatch_wait(event_loop_block, dispatch_time(DISPATCH_TIME_NOW, 1000000000));
  dispatch_release(event_loop_q);
  isEventLoopCreated = NO;
}

- (void)setShouldHandleEvents:(BOOL)yn
{
  shouldHandleEvents = yn;
}

- (NSString *)name
{
  return cardName;
}

- (NSString *)chipName
{
  return chipName;
}

- (NSArray *)controls
{
  return controls;
}

- (snd_mixer_t *)mixer
{
  return alsa_mixer;
}

- (snd_mixer_t *)createMixer
{
  snd_mixer_t *mixer = NULL;
  
  if (snd_mixer_open(&mixer, 0) < 0) {
    NSLog(@"Cannot open mixer for sound card `%@`.", cardName);
    return NULL;
  }
  if (snd_mixer_attach(mixer, [deviceName cString]) < 0) {
    NSLog(@"Cannot attach mixer for sound card `%@`.", cardName);
    return NULL;
  }
  if (snd_mixer_selem_register(mixer, NULL, NULL) < 0) {
    NSLog(@"Cannot register the mixer elements for sound card `%@`.", cardName);
    return NULL;
  }
  if (snd_mixer_load(mixer) < 0) {
    NSLog(@"Cannot load mixer for sound card `%@`.", cardName);
    return NULL;
  }

  return mixer;
}

- (void)deleteMixer:(snd_mixer_t *)mixer
{
  snd_mixer_detach(mixer, [cardName cString]);
  snd_mixer_close(mixer);
  mixer = NULL;
}

@end