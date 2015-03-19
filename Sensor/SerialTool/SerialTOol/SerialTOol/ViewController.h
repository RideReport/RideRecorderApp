//
//  ViewController.h
//  SerialTOol
//
//  Created by William Henderson on 1/27/15.
//  Copyright (c) 2015 Knock Software, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CorePlot/CorePlot.h>
#import "ORSSerialPort.h"

@class ORSSerialPortManager;

@interface ViewController : NSViewController <ORSSerialPortDelegate, CPTScatterPlotDataSource, NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, readwrite, strong) IBOutlet CPTGraphHostingView *hostView;
@property (nonatomic, readwrite, strong) CPTXYGraph *graph;
@property (nonatomic, readwrite, strong) NSMutableArray *dataSources;

@property (nonatomic, readwrite, strong) NSString *inputBufferString;
@property (nonatomic, readwrite, strong) NSArray *tableHeaders;
@property (nonatomic, readwrite, strong) NSMutableArray *serialData;

@property (nonatomic, readwrite, strong) IBOutlet NSTableView *dataTableView;

@property (nonatomic, strong) ORSSerialPortManager *serialPortManager;
@property (nonatomic, strong) ORSSerialPort *serialPort;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (unsafe_unretained) IBOutlet NSButton *openCloseButton;

@property (nonatomic, assign) BOOL shouldMarkNextReading;

- (IBAction)openOrClosePort:(id)sender;
- (IBAction)clear:(id)sender;
- (IBAction)mark:(id)sender;

@end

