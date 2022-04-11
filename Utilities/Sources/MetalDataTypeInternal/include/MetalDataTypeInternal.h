//
//  Header.h
//  
//
//  Created by YuAo on 2022/4/10.
//

@import Foundation;
@import Metal;

NS_ASSUME_NONNULL_BEGIN

// MTLTypeInternal
@protocol MetalDataTypeObject

- (id)initWithDataType:(unsigned long long)arg1;

@property (nonatomic, readonly) unsigned long long dataType;

@property (nonatomic, readonly) NSString * description;

@end

FOUNDATION_EXPORT id<MetalDataTypeObject> MetalDataTypeObjectCreate(unsigned long long type);

NS_ASSUME_NONNULL_END
