//
//  HarmoniumAudioEngine.h
//  LidAngleSensor
//
//  Created by Vedaant on 2025-09-27.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface HarmoniumAudioEngine : NSObject

@property (nonatomic, assign, readonly) BOOL isEngineRunning;

- (instancetype)init;
- (void)startEngine;
- (void)stopEngine;
- (void)playNote:(int)midiNote;

/**
 * Updates the volume of all playing notes.
 * @param volume The target volume, from 0.0 to 1.0.
 */
- (void)updateVolume:(float)volume;

@end
