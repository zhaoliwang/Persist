//
//  PersistObject.h
//  Persist
//
//  Created by liwang.zhao on 2017/3/30.
//  Copyright © 2017年 LandOfMystery. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PersistObject;

/**
 Base Class To be persisted.
 Every Class need to persist shoud inherit this class.
 
 @property className    The className is used to distinguish the items in DB.
 
 @property uuid         The uuid is taken as the primary key in DB.
 
 If the subclass has its own property as Primary key, you can assign the uuid as your property. All you should kown is that The uuid property is a NSString type.
 
 */

typedef void (^MigrationBlock)(NSDictionary *oldDataDict, PersistObject *newObj, NSInteger version);

@interface PersistObject : NSObject

@property (nonatomic, strong) NSString *className;
@property (nonatomic, strong) NSString *uuid;

// 获取model类版本号，用于数据库迁移（数据库迁移需要实现这个方法）
+ (NSInteger)getModelVersion;

// 数据库迁移需要实现block
+ (void)migrationWith:(NSDictionary *)oldDict newObj:(NSMutableDictionary *)newDict version:(NSInteger)version;

// 获取数据库中单个元素(UNI)
+ (instancetype)objectInDB:(NSString *)db autoInit:(BOOL)isAutoInit;

@end
