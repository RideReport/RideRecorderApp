//
//  AppDelegate.m
//  SerialTOol
//
//  Created by William Henderson on 1/27/15.
//  Copyright (c) 2015 Knock Software, Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "ORSSerialPortManager.h"
#import "ORSSerialPort.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    NSArray *ports = [[ORSSerialPortManager sharedSerialPortManager] availablePorts];
    for (ORSSerialPort *port in ports) { [port close]; }
}

@end
