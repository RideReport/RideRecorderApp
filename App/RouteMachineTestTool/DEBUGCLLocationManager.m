//
//  DEBUGCLLocationManager.m
//  
//
//  Created by William Henderson on 1/27/15.
//
//

#import "DEBUGCLLocationManager.h"

@interface CLLocationManager ()
-(void)onClientEventBatch:(id)arg1 ;
@end

@implementation DEBUGCLLocationManager
-(void)onClientEventBatch:(id)arg1;
{
    NSLog(@"HEYYY: %@\n\n", arg1);
    [super onClientEventBatch:arg1];
}
@end
