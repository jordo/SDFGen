//
//  AppDelegate.m
//  SDFGen
//
//  Created by Oleg Osin on 8/14/14.
//  Copyright (c) 2014 apportable. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [self loadInputImage];
}

- (void)loadInputImage
{
    NSImage* inputImage = [NSImage imageNamed:@"inputImage"];
    
    [_inputImageView setImage:inputImage];
}

- (void)loadOutputImage
{
    
}

#pragma mark Actions

- (IBAction)generate:(id)sender
{

}

@end
