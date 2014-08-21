//
//  AppDelegate.h
//  SDFGen
//
//  Created by Oleg Osin on 8/14/14.
//  Copyright (c) 2014 apportable. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTextFieldDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSImageView* inputImageView;
@property (assign) IBOutlet NSImageView* outputImageView;
@property (assign) IBOutlet NSButton* generateButton;
@property (assign) IBOutlet NSTextField* width;
@property (assign) IBOutlet NSTextField* height;
@property (assign) IBOutlet NSTextField* spread;

- (IBAction)generate:(id)sender;

@end
