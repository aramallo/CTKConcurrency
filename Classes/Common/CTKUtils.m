//
//  QLUtils.m
//  PersistentData
//
//  Created by aramallo on 29/11/2009.
//  Copyright 2009 Alejandro M. Ramallo. All rights reserved.
//

#import "CTKUtils.h"

#include <mach/mach.h>
#include <mach/mach_time.h>


@implementation CTKUtils


+ (NSUInteger) currentTimeInMillis
{
	return [self currentTimeInNanos] / 1000000;
}

+ (NSUInteger) currentTimeInNanos
{
	static mach_timebase_info_data_t sTimebaseInfo;
	
	NSUInteger currentCPUTime = mach_absolute_time();
	
	if ( sTimebaseInfo.denom == 0 ) {
        (void) mach_timebase_info(&sTimebaseInfo);
    }
	
    return currentCPUTime * sTimebaseInfo.numer / sTimebaseInfo.denom;
}

+ (NSUInteger) currentTimeInSecs
{
	return [self currentTimeInMillis] / 1000;
}

@end
