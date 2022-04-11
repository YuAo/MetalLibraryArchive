//
//  a.m
//  
//
//  Created by YuAo on 2022/4/10.
//

#import "MetalDataTypeInternal.h"

id<MetalDataTypeObject> MetalDataTypeObjectCreate(unsigned long long type) {
    id value = [[NSClassFromString(@"MTLTypeInternal") alloc] initWithDataType:type];
    return value;
}
