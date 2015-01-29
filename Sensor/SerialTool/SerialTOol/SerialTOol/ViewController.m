//
//  ViewController.m
//  SerialTOol
//
//  Created by William Henderson on 1/27/15.
//  Copyright (c) 2015 Knock Software, Inc. All rights reserved.
//

#import "ViewController.h"
#import "ORSSerialPortManager.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.serialData = [NSMutableArray array];
    self.inputBufferString = @"";
    
    [self setupGraph];
    [self setupAxes];
    [self setupScatterPlots];
    
    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.locale = [NSLocale currentLocale];
    self.dateFormatter.dateFormat = @"h:mm:ss:SS";
    
    self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
}

-(void)setupGraph
{
    // Create graph and apply a dark theme
    CPTXYGraph *newGraph = [[CPTXYGraph alloc] initWithFrame:NSRectToCGRect(self.hostView.bounds)];
    self.hostView.hostedGraph = newGraph;
    self.graph                = newGraph;
    
    // Graph title
    CPTMutableTextStyle *textStyle = [CPTMutableTextStyle textStyle];
    textStyle.color                   = [CPTColor grayColor];
    textStyle.fontName                = @"Helvetica-Bold";
    textStyle.fontSize                = 18.0;
    newGraph.titleTextStyle           = textStyle;
    newGraph.titleDisplacement        = CGPointMake(0.0, 10.0);
    newGraph.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    newGraph.backgroundColor = [NSColor blackColor].CGColor;
    
    // Graph padding
    newGraph.paddingLeft   = 20.0;
    newGraph.paddingTop    = 20.0;
    newGraph.paddingRight  = 20.0;
    newGraph.paddingBottom = 20.0;
}

-(void)setupAxes
{
    // Setup scatter plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)self.graph.defaultPlotSpace;
    
    plotSpace.allowsUserInteraction = YES;
#ifdef REMOVE_SELECTION_ON_CLICK
    plotSpace.delegate = self;
#endif
    
    // Grid line styles
    CPTMutableLineStyle *majorGridLineStyle = [CPTMutableLineStyle lineStyle];
    majorGridLineStyle.lineWidth = 0.75;
    majorGridLineStyle.lineColor = [[CPTColor colorWithGenericGray:0.2] colorWithAlphaComponent:0.75];
    
    CPTMutableLineStyle *minorGridLineStyle = [CPTMutableLineStyle lineStyle];
    minorGridLineStyle.lineWidth = 0.25;
    minorGridLineStyle.lineColor = [[CPTColor whiteColor] colorWithAlphaComponent:0.1];
    
    // Axes
    // Label x axis with a fixed interval policy
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)self.graph.axisSet;
    CPTXYAxis *x          = axisSet.xAxis;
    x.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
    x.minorTicksPerInterval       = 4;
    x.preferredNumberOfMajorTicks = 8;
    x.majorGridLineStyle          = majorGridLineStyle;
    x.minorGridLineStyle          = minorGridLineStyle;
    x.title                       = @"X Axis";
    x.titleOffset                 = 30.0;
    
    // Label y with an automatic label policy.
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
    y.minorTicksPerInterval       = 4;
    y.preferredNumberOfMajorTicks = 8;
    y.majorGridLineStyle          = majorGridLineStyle;
    y.minorGridLineStyle          = minorGridLineStyle;
    y.labelOffset                 = 10.0;
    y.title                       = @"Y Axis";
    y.titleOffset                 = 30.0;
}

-(void)setupScatterPlots
{
    // Create a plot that uses the data source method
    int count = 0;
    if (self.dataSources) {
        for (CPTScatterPlot *plot in self.dataSources) {
                [self.graph removePlot:plot];
        }
    }
    
    self.dataSources = [NSMutableArray array];
    
    for (CPTColor *color in @[[CPTColor greenColor], [CPTColor blueColor], [CPTColor purpleColor], [CPTColor redColor]]) {
        CPTScatterPlot *plot = [[CPTScatterPlot alloc] init];
        
        plot.identifier     = [NSNumber numberWithInt:count];
        plot.cachePrecision = CPTPlotCachePrecisionDouble;
        
        CPTMutableLineStyle *lineStyle = [plot.dataLineStyle mutableCopy];
        lineStyle.lineWidth              = 2.0;
        lineStyle.lineColor              = color;
        plot.dataLineStyle = lineStyle;
        
        plot.dataSource = self;
        [self.graph addPlot:plot];
        
        // Set plot delegate, to know when symbols have been touched
        // We will display an annotation when a symbol is touched
        plot.delegate                        = self;
        plot.plotSymbolMarginForHitDetection = 5.0;
        count++;
        
        [self.dataSources addObject:plot];
    }
    
    [self setupGraphRange];
}

- (void)setupGraphRange;
{
    // Auto scale the plot space to fit the plot data
    // Compress ranges so we can scroll
    // 45 seconds of data
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)self.graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble([[NSDate date] timeIntervalSince1970] - 45.0) length:CPTDecimalFromDouble(45.0)];

    [plotSpace scaleToFitPlots:@[[self.dataSources objectAtIndex:1]]];

    CPTMutablePlotRange *yRange = [plotSpace.yRange mutableCopy];
    [yRange expandRangeByFactor:CPTDecimalFromDouble(1.00)];
    plotSpace.yRange = yRange;
    
//    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(400.0)];

}

#pragma mark -
#pragma mark Plot datasource methods

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    NSUInteger count = 0;
    
    count = [self.serialData count];

    return count;
}

-(id)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    NSNumber *num = nil;
    NSArray *rowdata = [self.serialData objectAtIndex:index];
    
    
    if(fieldEnum == CPTScatterPlotFieldX) {
        id columnData = [rowdata objectAtIndex:0];
        return [NSNumber numberWithDouble:[columnData timeIntervalSince1970]];
    } else {
        int columnNumber = [(NSNumber *)plot.identifier intValue];

        return [rowdata objectAtIndex:(columnNumber + 1)];
    }
    return num;
}
//
//-(CPTPlotSymbol *)symbolForScatterPlot:(CPTScatterPlot *)plot recordIndex:(NSUInteger)index
//{
//    static CPTPlotSymbol *redDot = nil;
//    
//    CPTPlotSymbol *symbol = (id)[NSNull null];
//    
//    if ( [(NSNumber *)plot.identifier isEqualToString : SELECTION_PLOT] && (index == 2) ) {
//        if ( !redDot ) {
//            redDot            = [[CPTPlotSymbol alloc] init];
//            redDot.symbolType = CPTPlotSymbolTypeEllipse;
//            redDot.size       = CGSizeMake(10.0, 10.0);
//            redDot.fill       = [CPTFill fillWithColor:[CPTColor redColor]];
//        }
//        symbol = redDot;
//    }
//    
//    return symbol;
//}

#pragma mark - TableViewDataSource

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;
{
    NSString *pb = @"";
    for (NSArray *row in self.serialData) {
        NSString *dateString = [self.dateFormatter stringFromDate:[row objectAtIndex:0]];
        NSArray *dataRow = [row subarrayWithRange:NSMakeRange(1, row.count - 1)];
        pb = [pb stringByAppendingString:[NSString stringWithFormat:@"%@\t%@\n", dateString, [dataRow componentsJoinedByString:@"\t"]]];
    }
    [pboard clearContents];
    [pboard declareTypes:@[NSPasteboardTypeString] owner:nil];
    [pboard setString:pb forType:NSPasteboardTypeString];
    
    return true;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return self.serialData.count;
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
    NSArray *rowData = [self.serialData objectAtIndex:rowIndex];
    
    NSUInteger columnIndex = [[aTableView tableColumns] indexOfObject:aTableColumn];
    id columnData = [rowData objectAtIndex:columnIndex];
    if ([columnData isKindOfClass:[NSDate class]]) {
        return [self.dateFormatter stringFromDate:columnData];
    }
    
    return columnData;
}
- (void)refreshTableHeaders;
{
    //
}

- (IBAction)clear:(id)sender;
{
    self.serialData = [NSMutableArray array];
    [self.dataTableView reloadData];
    [self setupScatterPlots];
    [self.graph reloadData];
}

#pragma mark - ORSSerialPortDelegate Methods

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
    self.openCloseButton.title = @"Meh";
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
    self.openCloseButton.title = @"K";
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([string length] == 0) return;
    self.inputBufferString = [self.inputBufferString stringByAppendingString:string];
    NSLog(self.inputBufferString);
    if ([self.inputBufferString rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location == NSNotFound) {
        return;
    }

    NSString *rowString =  [self.inputBufferString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *components = [rowString componentsSeparatedByString:@","];
    if (components.count != 6) {
        //ignore partial rows
        self.inputBufferString = @"";
        return;
    }
    NSNumber *num = [[NSNumberFormatter new] numberFromString:components.firstObject];
    if (!num) {
        //it's a header array!
        self.tableHeaders = components;
        [self refreshTableHeaders];
        return;
    }
    
    // start with the date
    NSMutableArray *rowArray = [NSMutableArray arrayWithObject:[NSDate date]];
    NSMutableArray *numbers = [NSMutableArray array];
    for (NSString *component in components) {
        NSNumber *num = [[NSNumberFormatter new] numberFromString:component];
        
        NSUInteger index = [components indexOfObject:component];
        if (index == 3) {
            num = [NSNumber numberWithInt:[num intValue] + 16000];
        }
        if (num == nil) {
            NSAssert(num != nil, @"Got unexpected non-number among numbers!");
        }
        
        [numbers addObject:num];
    }
    
    [rowArray addObject:[numbers objectAtIndex:0]];
    double irVal = [[numbers objectAtIndex:1] doubleValue] - 3;
    if (irVal == 0) {
        irVal = 1;
    }
    double lineralized = (6787/irVal) - 4.0;
    [rowArray addObject:[NSNumber numberWithDouble:lineralized]];
    [rowArray addObject:[numbers objectAtIndex:2]];
    
    int magnitude = sqrt(pow([[numbers objectAtIndex:3] doubleValue], 2.0) + pow([[numbers objectAtIndex:4] doubleValue], 2.0) + pow([[numbers objectAtIndex:4] doubleValue], 2.0));
    [rowArray addObject:[NSNumber numberWithDouble:magnitude - 800]];

    NSUInteger indexToInsert = self.serialData.count;
    [self.serialData addObject:rowArray];
    [self.dataTableView beginUpdates];
    [self.dataTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:indexToInsert] withAnimation:NSTableViewAnimationSlideDown];
    [self.dataTableView scrollRowToVisible:indexToInsert];
    [self.dataTableView endUpdates];
    
    [self.graph reloadData];
    [self setupGraphRange];
    
    self.inputBufferString = @"";
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;
{
    // After a serial port is removed from the system, it is invalid and we must discard any references to it
    self.serialPort = nil;
    self.openCloseButton.title = @"Open";
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
    NSLog(@"Serial port %@ encountered an error: %@", serialPort, error);
}

#pragma mark stuff

- (IBAction)openOrClosePort:(id)sender
{    
    self.serialPort.baudRate = @9600;
    
    self.serialPort.isOpen ? [self.serialPort close] : [self.serialPort open];
}

- (void)setSerialPort:(ORSSerialPort *)port
{
    if (port != _serialPort)
    {
        [_serialPort close];
        _serialPort.delegate = nil;
        
        _serialPort = port;
        
        _serialPort.delegate = self;
    }
}



@end
