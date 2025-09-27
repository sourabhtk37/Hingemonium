//
//  AppDelegate.h
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//  Modified by Vedaant on 2025-09-27
//

#import <Cocoa/Cocoa.h>
#import "HarmoniumAudioEngine.h"
#import "NSLabel.h"
#import "LidAngleSensor.h"
#import "KeyCaptureView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, KeyCaptureViewDelegate>

// Main Window
@property (strong) NSWindow *window;

// Lid Sensor & Timer
@property (strong) LidAngleSensor *lidSensor;
@property (strong) NSTimer *updateTimer;

@property (nonatomic, assign) double lastLidAngle;
@property (nonatomic, assign) double lastUpdateTime;
@property (nonatomic, assign) double airPressure;


// Harmonium Audio Engine
@property (strong) HarmoniumAudioEngine *harmoniumEngine;

// UI Elements
@property (strong) NSLabel *titleLabel;
@property (strong) NSLabel *angleLabel; // For showing the angle
@property (strong) NSLabel *scaleLabel;
@property (strong) NSPopUpButton *scalePopUpButton;
@property (strong) NSLabel *legendLabel; // For the key map legend
@property (strong) NSLabel *instructionsLabel;

// State Management
@property (strong) NSArray<NSString *> *availableScales;
@property (strong) NSDictionary<NSString *, NSArray<NSNumber *> *> *scaleNoteMapping;
@property (strong) NSString *currentScale;
@property (strong) NSArray<NSNumber *> *mappedKeys; // To iterate keys in order

@end
