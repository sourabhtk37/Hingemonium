//
//  AppDelegate.m
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//  Modified by Vedaant on 2025-09-27
//

#import "AppDelegate.h"

// Maps keyboard characters to a base chromatic scale (C3 = 48)
static const int kKeyToMidiNote[] = {
    ['z'] = 48, ['s'] = 49, ['x'] = 50, ['d'] = 51, ['c'] = 52, ['v'] = 53,
    ['g'] = 54, ['b'] = 55, ['h'] = 56, ['n'] = 57, ['j'] = 58, ['m'] = 59,
    [','] = 60, ['l'] = 61, ['.'] = 62
};

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // --- Window and Custom View Setup ---
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 520, 380)
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    // Create and set our custom view as the window's content view
    KeyCaptureView *keyView = [[KeyCaptureView alloc] initWithFrame:self.window.frame];
    keyView.delegate = self; // Set the delegate to self
    self.window.contentView = keyView;

    [self.window setTitle:@"Hingemonium "];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    // Make our custom view the first responder to ensure it gets key events
    [self.window makeFirstResponder:keyView];

    // --- Component Initialization ---
    self.harmoniumEngine = [[HarmoniumAudioEngine alloc] init];
    self.lidSensor = [[LidAngleSensor alloc] init];
    
    self.lastLidAngle = -1.0;
    self.lastUpdateTime = CACurrentMediaTime();
    self.airPressure = 0.0; // Start with no air
    
    [self.harmoniumEngine startEngine];

    // --- UI and Scale Setup ---
    [self setupUI];
    [self setupScales];
    [self updateLegend]; // Initial legend update

    // --- Start Update Timer ---
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.02
                                                        target:self
                                                      selector:@selector(update)
                                                      userInfo:nil
                                                       repeats:YES];
}

// This is the new delegate method that receives key presses
- (void)keyCaptureView:(KeyCaptureView *)view didReceiveKeyDown:(NSEvent *)event {
    if (event.isARepeat) return;
    
    NSString *keyStr = event.charactersIgnoringModifiers.lowercaseString;
    if (keyStr.length == 0) return;
    
    char character = [keyStr characterAtIndex:0];
    int midiNote = [self getMidiNoteForKey:character];
    
    if (midiNote > 0) {
        [self.harmoniumEngine playNote:midiNote];
    }
}


- (void)setupUI {
    // IMPORTANT: Get the contentView which is now our KeyCaptureView
    NSView *contentView = self.window.contentView;

    // --- Create UI Elements ---
    self.titleLabel = [[NSLabel alloc] init];
    self.titleLabel.stringValue = @"Harmonium for Mac";
    [self.titleLabel setFont:[NSFont boldSystemFontOfSize:24]];

    self.angleLabel = [[NSLabel alloc] init];
    [self.angleLabel setStringValue:@"--°"];
    [self.angleLabel setFont:[NSFont monospacedDigitSystemFontOfSize:18 weight:NSFontWeightRegular]];
    [self.angleLabel setTextColor:[NSColor secondaryLabelColor]];

    self.scaleLabel = [[NSLabel alloc] init];
    self.scaleLabel.stringValue = @"Select Scale:";
    
    self.scalePopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 25) pullsDown:NO];
    [self.scalePopUpButton setTarget:self];
    [self.scalePopUpButton setAction:@selector(scaleDidChange:)];
    [self.scalePopUpButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    self.legendLabel = [[NSLabel alloc] init];
    [self.legendLabel setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
    self.legendLabel.stringValue = @"-";
    
    self.instructionsLabel = [[NSLabel alloc] init];
    self.instructionsLabel.stringValue = @"Move the lid to pump the bellows (air) and use the keyboard to play.";
    
    self.instructionsLabel.alignment = NSTextAlignmentCenter;
    
    // --- Add to View ---
    for (NSView *view in @[self.titleLabel, self.angleLabel, self.scaleLabel, self.scalePopUpButton, self.legendLabel, self.instructionsLabel]) {
        [contentView addSubview:view];
    }

    // --- Auto Layout ---
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        
        [self.angleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.angleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],

        [self.scaleLabel.topAnchor constraintEqualToAnchor:self.angleLabel.bottomAnchor constant:25],
        [self.scaleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor constant:-90],
        
        [self.scalePopUpButton.centerYAnchor constraintEqualToAnchor:self.scaleLabel.centerYAnchor],
        [self.scalePopUpButton.leadingAnchor constraintEqualToAnchor:self.scaleLabel.trailingAnchor constant:10],
        
        [self.legendLabel.topAnchor constraintEqualToAnchor:self.scalePopUpButton.bottomAnchor constant:20],
        [self.legendLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],

        [self.instructionsLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.instructionsLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20]
    ]];
}

- (void)setupScales {
    self.availableScales = @[@"Chromatic", @"Major", @"Natural Minor", @"Minor Pentatonic"];
    self.scaleNoteMapping = @{
        @"Chromatic":        @[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, @10, @11],
        @"Major":            @[@0, @2, @4, @5, @7, @9, @11],
        @"Natural Minor":    @[@0, @2, @3, @5, @7, @8, @10],
        @"Minor Pentatonic": @[@0, @3, @5, @7, @10]
    };
    self.mappedKeys = @[@'z', @'s', @'x', @'d', @'c', @'v', @'g', @'b', @'h', @'n', @'j', @'m', @',', @'l', @'.'];

    [self.scalePopUpButton addItemsWithTitles:self.availableScales];
    self.currentScale = self.availableScales[0];
}

- (void)scaleDidChange:(NSPopUpButton *)sender {
    self.currentScale = sender.selectedItem.title;
    [self updateLegend];
}
- (void)update {
    if (!self.lidSensor.isAvailable) {
        self.angleLabel.stringValue = @"Sensor N/A";
        return;
    }
    double angle = [self.lidSensor lidAngle];
    if (angle < 0) {
        self.angleLabel.stringValue = @"Read Error";
        return;
    }

    double currentTime = CACurrentMediaTime();
    if (self.lastLidAngle < 0) {
        self.lastLidAngle = angle;
        self.lastUpdateTime = currentTime;
        return;
    }

    double deltaTime = currentTime - self.lastUpdateTime;
    if (deltaTime <= 0 || deltaTime > 0.5) {
        self.lastLidAngle = angle;
        self.lastUpdateTime = currentTime;
        return;
    }

    // --- 1. Calculate a SMOOTHED velocity for pumping ---
    double instantVelocity = fabs(angle - self.lastLidAngle) / deltaTime;
    
    // --- 2. Update Air Pressure Model ---
    // PUMP: Lid movement adds air to the reservoir.
    // The multiplier controls how quickly you can "fill" the bellows.
    double pumpFactor = 0.015;
    self.airPressure += instantVelocity * pumpFactor;
    
    // DECAY: Air pressure naturally and constantly depletes over time.
    // This creates the smooth fade-out effect. A higher rate means faster decay.
    double decayRate = 0.5; // Pressure depletes by 50% per second.
    self.airPressure -= decayRate * deltaTime;

    // CLAMP: Ensure pressure stays between 0.0 (empty) and 1.0 (full).
    self.airPressure = fmax(0.0, fmin(1.0, self.airPressure));

    // --- 3. Update UI and Audio Engine ---
    self.angleLabel.stringValue = [NSString stringWithFormat:@"Angle: %.1f° | Air Pressure: %.0f%%", angle, self.airPressure * 100];
    
    // Send the final, smooth pressure value to the engine
    [self.harmoniumEngine updateVolume:(float)self.airPressure];

    // Save state for the next frame
    self.lastLidAngle = angle;
    self.lastUpdateTime = currentTime;
}

- (void)updateLegend {
    NSMutableString *legendText = [NSMutableString string];
    [legendText appendString:@"Keyboard Mapping:\n\n"];
    
    for (int i = 0; i < self.mappedKeys.count; i++) {
        char key = [self.mappedKeys[i] charValue];
        int midiNote = [self getMidiNoteForKey:key];
        NSString *noteName = [self noteNameForMidi:midiNote];
        
        // Format as "Z: C3 " with padding
        [legendText appendFormat:@"%c: %-4s", toupper(key), [noteName UTF8String]];
        
        // Add a newline after every 5 keys for readability
        if ((i + 1) % 5 == 0) {
            [legendText appendString:@"\n"];
        }
    }
    self.legendLabel.stringValue = legendText;
}

- (int)getMidiNoteForKey:(char)key {
    int baseNote = kKeyToMidiNote[key];
    if (baseNote == 0) return -1;
    
    int finalNote = baseNote;
    if (![self.currentScale isEqualToString:@"Chromatic"]) {
        NSArray<NSNumber *> *scaleIntervals = self.scaleNoteMapping[self.currentScale];
        int rootNote = 48; // C3
        
        int closestNoteInScale = -1;
        int minDistance = 100;
        
        for (int octave = -1; octave <= 2; octave++) {
            for (NSNumber *interval in scaleIntervals) {
                int noteInScale = rootNote + interval.intValue + (octave * 12);
                int distance = abs(noteInScale - baseNote);
                if (distance < minDistance) {
                    minDistance = distance;
                    closestNoteInScale = noteInScale;
                }
            }
        }
        finalNote = closestNoteInScale;
    }
    return finalNote;
}

- (NSString *)noteNameForMidi:(int)midiNote {
    if (midiNote < 0) return @"-";
    NSArray<NSString *> *names = @[@"C", @"C#", @"D", @"D#", @"E", @"F", @"F#", @"G", @"G#", @"A", @"A#", @"B"];
    int octave = (midiNote / 12) - 1;
    NSString *note = names[midiNote % 12];
    return [NSString stringWithFormat:@"%@%d", note, octave];
}

- (BOOL)handleKeyDown:(NSEvent *)event {
    if (event.isARepeat) return NO;
    
    NSString *keyStr = event.charactersIgnoringModifiers.lowercaseString;
    if (keyStr.length == 0) return NO;
    
    char character = [keyStr characterAtIndex:0];
    int midiNote = [self getMidiNoteForKey:character];
    
    if (midiNote > 0) {
        [self.harmoniumEngine playNote:midiNote];
        return YES; // We handled it, suppress the beep!
    }
    
    return NO; // Not a key we handle
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.updateTimer invalidate];
    [self.harmoniumEngine stopEngine];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
