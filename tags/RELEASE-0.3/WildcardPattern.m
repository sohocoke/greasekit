/*
 * Copyright (c) 2006 KATO Kazuyoshi <kzys@8-p.info>
 * This source code is released under the MIT license.
 */

#import "WildcardPattern.h"

@implementation WildcardPattern

- (id) initWithString: (NSString*) s
{
	self = [self init];
	
	pattern_ = [s retain];
	
	return self;
}

- (BOOL) isMatch: (NSString*) s
{
	// NSLog(@"pattern_ = %@, s = %@", pattern_, s);
	
	const char* str = [s UTF8String];
	const char* pat = [pattern_ UTF8String];
	BOOL isStar = NO;
	
	while (*str != '\0') {
		if (*str == *pat) {
			str++;
			pat++;
			isStar = NO;
		} else {
			if (isStar) {
				str++;
			} else {
				if (*pat == '*') {
					str++;
					pat++;
					isStar = YES;
				} else {
					return NO;
				}
			}
		}
	}

	while (*pat != '\0') {
		if (*pat != '*') {
			return NO;
		} else {
			pat++;
		}
	}

	return *str == '\0' && *pat == '\0';
}

@end