//
//  HarmoniumAudioEngine.m
//  LidAngleSensor
//
//  Created by Vedaant Rajeshirke on 9/27/25.
//

#import "HarmoniumAudioEngine.h"

static const int kNumberOfPlayers = 16;

@interface HarmoniumAudioEngine ()
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioMixerNode *mixerNode;
@property (nonatomic, strong) NSMutableArray<AVAudioPlayerNode *> *playerPool;
@property (nonatomic, assign) int currentPlayerIndex;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, AVAudioPCMBuffer *> *noteBuffers;

// Property to hold the current volume based on lid angle
@property (nonatomic, assign) float currentVolume;
@end

@implementation HarmoniumAudioEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentPlayerIndex = 0;
        _currentVolume = 0.0; // Start with no volume
        // ... (rest of init remains the same)
        if (![self setupAudioEngine]) {
            NSLog(@"[HarmoniumAudioEngine] Failed to setup audio engine");
            return nil;
        }
        if (![self loadHarmoniumSamples]) {
            NSLog(@"[HarmoniumAudioEngine] Failed to load audio samples");
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    [self stopEngine];
}

- (BOOL)setupAudioEngine {
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.mixerNode = self.audioEngine.mainMixerNode;
    
    // Create a pool of player nodes for polyphony
    self.playerPool = [NSMutableArray arrayWithCapacity:kNumberOfPlayers];
    for (int i = 0; i < kNumberOfPlayers; i++) {
        AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
        [self.audioEngine attachNode:player];
        [self.audioEngine connect:player to:self.mixerNode format:nil];
        [self.playerPool addObject:player];
    }
    
    return YES;
}

- (BOOL)loadHarmoniumSamples {
    self.noteBuffers = [NSMutableDictionary dictionary];
    NSBundle *bundle = [NSBundle mainBundle];
    
    // Map your note names to their corresponding MIDI numbers
    NSDictionary<NSString *, NSNumber *> *noteFileToMidi = @{
        @"harmonium-c2": @36, @"harmonium-c#2": @37, @"harmonium-d2": @38, @"harmonium-d#2": @39,
        @"harmonium-e2": @40, @"harmonium-f2": @41, @"harmonium-f#2": @42, @"harmonium-g2": @43,
        @"harmonium-g#2": @44, @"harmonium-a2": @45, @"harmonium-a#2": @46, @"harmonium-b2": @47,
        @"harmonium-c3": @48, @"harmonium-c#3": @49, @"harmonium-d3": @50, @"harmonium-d#3": @51,
        @"harmonium-e3": @52, @"harmonium-f3": @53, @"harmonium-f#3": @54, @"harmonium-g3": @55,
        @"harmonium-g#3": @56, @"harmonium-a3": @57, @"harmonium-a#3": @58, @"harmonium-b3": @59,
        @"harmonium-c4": @60, @"harmonium-c#4": @61, @"harmonium-d4": @62, @"harmonium-d#4": @63,
        @"harmonium-e4": @64, @"harmonium-f4": @65, @"harmonium-f#4": @66, @"harmonium-g4": @67,
        @"harmonium-g#4": @68, @"harmonium-a4": @69, @"harmonium-a#4": @70, @"harmonium-b4": @71,
        @"harmonium-c5": @72, @"harmonium-c#5": @73, @"harmonium-d5": @74
    };
    
    __block BOOL firstFile = YES;
    [noteFileToMidi enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull noteName, NSNumber * _Nonnull midiNote, BOOL * _Nonnull stop) {
        NSString *path = [bundle pathForResource:noteName ofType:@"wav"];
        if (!path) {
            NSLog(@"[HarmoniumAudioEngine] Could not find sample: %@.wav", noteName);
            return;
        }
        
        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error;
        AVAudioFile *file = [[AVAudioFile alloc] initForReading:url error:&error];
        if (!file) {
            NSLog(@"[HarmoniumAudioEngine] Failed to load file %@: %@", noteName, error.localizedDescription);
            return;
        }
        
        AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:file.processingFormat frameCapacity:(AVAudioFrameCount)file.length];
        if (![file readIntoBuffer:buffer error:&error]) {
            NSLog(@"[HarmoniumAudioEngine] Failed to read file %@ into buffer: %@", noteName, error.localizedDescription);
            return;
        }
        
        self.noteBuffers[midiNote] = buffer;
        
        // On the first file loaded, connect all players using its audio format
        if (firstFile) {
            for (AVAudioPlayerNode *player in self.playerPool) {
                [self.audioEngine disconnectNodeOutput:player];
                [self.audioEngine connect:player to:self.mixerNode format:file.processingFormat];
            }
            firstFile = NO;
        }
    }];
    
    NSLog(@"[HarmoniumAudioEngine] Successfully loaded %lu harmonium samples.", (unsigned long)self.noteBuffers.count);
    return self.noteBuffers.count > 0;
}

- (void)startEngine {
    if (self.isEngineRunning) return;
    
    NSError *error;
    if (![self.audioEngine startAndReturnError:&error]) {
        NSLog(@"[HarmoniumAudioEngine] Failed to start audio engine: %@", error.localizedDescription);
        return;
    }
    NSLog(@"[HarmoniumAudioEngine] Started.");
}

- (void)stopEngine {
    if (!self.isEngineRunning) return;
    
    for (AVAudioPlayerNode *player in self.playerPool) {
        [player stop];
    }
    [self.audioEngine stop];
    NSLog(@"[HarmoniumAudioEngine] Stopped.");
}

- (BOOL)isEngineRunning {
    return self.audioEngine.isRunning;
}


- (void)playNote:(int)midiNote {
    AVAudioPCMBuffer *buffer = self.noteBuffers[@(midiNote)];
    if (!buffer) {
        NSLog(@"[HarmoniumAudioEngine] No sample found for MIDI note: %d", midiNote);
        return;
    }
    
    AVAudioPlayerNode *player = self.playerPool[self.currentPlayerIndex];
    self.currentPlayerIndex = (self.currentPlayerIndex + 1) % kNumberOfPlayers;
    
    [player stop];
    
    // Set the initial volume WHEN the note starts playing
    player.volume = self.currentVolume;
    
    [player scheduleBuffer:buffer atTime:nil options:AVAudioPlayerNodeBufferInterrupts completionHandler:nil];
    [player play];
}

- (void)updateVolume:(float)volume {
    // Clamp the incoming value to be safe
    self.currentVolume = fmaxf(0.0f, fminf(1.0f, volume));
    
    // Apply this new volume to all currently playing notes
    for (AVAudioPlayerNode *player in self.playerPool) {
        if (player.isPlaying) {
            player.volume = self.currentVolume;
        }
    }
}

@end
