//
//  AppDelegate.h
//  SDFGen
//
//  Created by Oleg Osin on 8/14/14.
//  Copyright (c) 2014 apportable. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSImageView* inputImageView;
@property (assign) IBOutlet NSImageView* outputImageView;
@property (assign) IBOutlet NSButton* generateButton;

- (IBAction)generate:(id)sender;

@end
