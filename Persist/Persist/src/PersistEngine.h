//
//  PersistEngine.h
//  Persist
//
//  Created by liwang.zhao on 2017/3/30.
//  Copyright © 2017年 LandOfMystery. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMDatabaseQueue;

/*
 * 管理FMDatabaseQueue的生命周期，防止重复的FMDatabaseQueue的生成与释放（浪费资源）
 */
@interface DBQueuePool : NSObject

+ (instancetype)shareDBQueuePool;
- (FMDatabaseQueue *)getDBQueueWithDBPath:(NSString *)dbName;
- (void)releaseDBQueueWithDBPath:(NSString *)dbPath;

@end

@interface PersistEngine : NSObject

- (id)initDBWithName:(NSString *)dbName;
- (id)initWithDBWithPath:(NSString *)dbPath;

- (void)createTableWithName:(NSString *)tableName;
- (BOOL)isTableExists:(NSString *)tableName;
- (void)clearTable:(NSString *)tableName;

- (void)putObject:(id)object intoTable:(NSString *)tableName;
- (void)putobjects:(NSArray *)objects intoTable:(NSString *)tableName;
- (NSDictionary *)getObjectByUuid:(NSString *)uuid fromTable:(NSString *)tableName;
- (NSArray *)getObjectByClassName:(NSString *)className fromTable:(NSString *)tableName;
- (NSArray *)getObjectByClassName:(NSString *)className where:(NSString *)where fromTable:(NSString *)tableName;
- (void)deleteObjectByUuid:(NSString *)uuid fromTable:(NSString *)tableName;
- (void)deleteObjectsByUuidArray:(NSArray *)uuidArray fromTable:(NSString *)tableName;
- (void)deleteObjectsByClassName:(NSString *)className fromTable:(NSString *)tableName;
- (NSUInteger)getCountFromTable:(NSString *)tableName;

- (void)updateObject:(id)object intoTable:(NSString *)tableName;

- (void)close;


@end
