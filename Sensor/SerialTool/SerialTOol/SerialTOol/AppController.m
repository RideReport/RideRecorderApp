//
//  AppController.m
//  SerialTOol
//
//  Created by William Henderson on 1/28/15.
//  Copyright (c) 2015 Knock Software, Inc. All rights reserved.
//

#import "AppController.h"

@implementation AppController

- (IBAction) copy:(id)sender
{
    NSTableView *currentTable = [(ViewController *) self.contentViewController dataTableView];
    // Now put the selected rows in the general pasteboard.
    if ([[currentTable dataSource] respondsToSelector:
         @selector(tableView:writeRowsWithIndexes:toPasteboard:)])
    {
        [[currentTable dataSource] tableView:currentTable
                                          writeRowsWithIndexes:[currentTable selectedRowIndexes]
                                       toPasteboard:[NSPasteboard generalPasteboard]];
    }
}

@end
