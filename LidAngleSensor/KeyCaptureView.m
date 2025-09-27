//
//  KeyCaptureView.m
//  LidAngleSensor
//
//  Created by Vedaant Rajeshirke on 9/27/25.
//


//
//  KeyCaptureView.m
//  LidAngleSensor
//

#import "KeyCaptureView.h"

@implementation KeyCaptureView

// 1. This view must be able to become the "first responder" to receive key events.
- (BOOL)acceptsFirstResponder {
    return YES;
}

// 2. This method is called when a key is pressed. By implementing it, we "handle"
//    the event, which stops the system from making the alert sound.
- (void)keyDown:(NSEvent *)event {
    // Pass the event to our delegate (the AppDelegate) to handle the logic.
    [self.delegate keyCaptureView:self didReceiveKeyDown:event];
}

// We don't need to do anything on key up, but you could add a delegate method
// for it here if you wanted to stop notes from playing in the future.
- (void)keyUp:(NSEvent *)event {
    // [self.delegate keyCaptureView:self didReceiveKeyUp:event];
}

@end