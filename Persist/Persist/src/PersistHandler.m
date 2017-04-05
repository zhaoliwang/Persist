//
//  PersistHandler.m
//  Persist
//
//  Created by liwang.zhao on 2017/3/31.
//  Copyright © 2017年 LandOfMystery. All rights reserved.
//

#import "PersistHandler.h"
#import "PersistEngine.h"
#import "PersistObject.h"
#import "NSObject+YYModel.h"

/*
 * 用于管理数据库表的锁
 */
@interface PersistLockManager : NSObject

@property (nonatomic, strong) NSMutableDictionary *locks;

+ (instancetype)shareManager;

- (NSObject*)getLock:(NSString *)tableName;
@end

@implementation PersistLockManager

+ (instancetype)shareManager{
    static PersistLockManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        manager = [[PersistLockManager alloc] init];
        manager.locks = [[NSMutableDictionary alloc] init];
    });
    
    return manager;
}

- (NSObject *)getLock:(NSString *)tableName{
    @synchronized(self){
        if (!_locks[tableName]) {
            _locks[tableName] = [[NSObject alloc] init];
        }
        
        return _locks[tableName];
    }
}

@end


@implementation PersistHandler

+ (void)removeDBAtPath:(NSString *)path{
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

+ (void)replaceDataWithObject:(PersistObject *)data inDB:(NSString *)dbName{
    if (!data || !(dbName.length > 0)) {
        return;
    }
    
    NSString *tableName = [self getTableNameWithClass:[data class]];
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        if ([engine isTableExists:tableName]) {
            [engine clearTable:tableName];
        } else {
            [engine createTableWithName:tableName];
        }
        [engine putObject:data intoTable:tableName];
        
        [engine close];
    }
}

+ (void)replaceDataWithArray:(NSArray *)data inDB:(NSString *)dbName{
    if ([data count] == 0 || !(dbName.length > 0)) {
        return;
    }
    
    id obj = [data firstObject];
    NSString *tableName = [self getTableNameWithClass:[obj class]];
    
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        if ([engine isTableExists:tableName]) {
            [engine clearTable:tableName];
        } else {
            [engine createTableWithName:tableName];
        }
        
        for (id obj in data) {
            [engine putObject:obj intoTable:tableName];
        }
        
        [engine close];
        
    }
    
}

+ (NSArray *)getDataWithClass:(Class)targetClass inDB:(NSString *)dbName{
    if (!(dbName.length > 0)) {
        return nil;
    }
    
    NSString *tableName = [self getTableNameWithClass:targetClass];
    
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        
        if (![engine isTableExists:tableName]) {
            return nil;
        }
        
        NSArray *objectsArray = [engine getObjectByClassName:NSStringFromClass(targetClass) fromTable:tableName];
        [engine close];
        
        return [self transferJsonArray:objectsArray];
    }
}

+ (id)getSingleDataWithClass:(Class)targetClass inDB:(NSString *)dbName{
    if (!(dbName.length > 0)) {
        return nil;
    }
    
    NSString *tableName = [self getTableNameWithClass:targetClass];
    
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        
        if (![engine isTableExists:tableName]) {
            return nil;
        }
        
        NSArray *objectsArray = [engine getObjectByClassName:NSStringFromClass(targetClass) fromTable:tableName];
        if ([objectsArray count] == 0) {
            [engine close];
            return nil;
        }
        
        NSArray *objs = [self transferJsonArray:objectsArray];
        
        if ([objs count] == 1) {
            [engine close];
            return [objs firstObject];
        } else  {
            //解决线上可能出现的多个数据
            [engine clearTable:tableName];
            [engine close];
            return nil;
        }
        
        return nil;
    }
    
}

+ (NSArray *)getDataWithClass:(Class)targetClass where:(NSString *)where inDB:(NSString *)dbName{
    if (!(dbName.length > 0)) {
        return nil;
    }
    
    NSString *tableName = [self getTableNameWithClass:targetClass];
    
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        
        if (![engine isTableExists:tableName]) {
            return nil;
        }
        
        NSArray *objectArray = [engine getObjectByClassName:NSStringFromClass(targetClass) where:where fromTable:tableName];
        [engine close];
        
        return [self transferJsonArray:objectArray];
    }
}

+ (NSArray *)getDataWithClass:(Class)targetClass withPredicate:(NSPredicate *)predicate inDB:(NSString *)dbName{
    if (!(dbName.length > 0)) {
        return nil;
    }
    
    NSArray *allObjects = [self getDataWithClass:targetClass inDB:dbName];
    return [allObjects filteredArrayUsingPredicate:predicate];
}

+ (void)addData:(PersistObject *)data inDB:(NSString *)dbName{
    if (!(dbName.length > 0) || data==nil) {
        return ;
    }
    
    NSString *tableName = [self getTableNameWithClass:[data class]];
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        
        if (![engine isTableExists:tableName]) {
            [engine createTableWithName:tableName];
        }
        
        [engine putObject:data intoTable:tableName];
        [engine close];
    }
}

+ (void)addSingleData:(PersistObject *)data inDB:(NSString *)dbName{
    if (!(dbName.length > 0) || data==nil) {
        return ;
    }
    
    NSString *tableName = [self getTableNameWithClass:[data class]];
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        
        if (![engine isTableExists:tableName]) {
            [engine createTableWithName:tableName];
        }
        
        [engine putObject:data intoTable:tableName];
        [engine close];
    }
    
}

+ (void)addDataWithArray:(NSArray *)data inDB:(NSString *)dbName{
    if (data && data.count > 0) {
        if (!(dbName.length > 0)) {
            return ;
        }
        
        id obj = [data firstObject];
        NSString *tableName = [self getTableNameWithClass:[obj class]];
        
        @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
            PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
            
            if (![engine isTableExists:tableName]) {
                [engine createTableWithName:tableName];
            }
            [engine putobjects:data intoTable:tableName];
            [engine close];
        }
    }
}

+ (void)removeData:(PersistObject *)data inDB:(NSString *)dbName{
    if (!(dbName.length > 0) || data == nil) {
        return ;
    }
    
    NSString *tableName = [self getTableNameWithClass:[data class]];
    
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        
        if (![engine isTableExists:tableName]) {
            return;
        }
        
        [engine deleteObjectByUuid:data.uuid fromTable:tableName];
        [engine close];
    }
}

+ (void)removeAllDataWithClass:(Class)targetClass inDB:(NSString *)dbName{
    if (!(dbName.length > 0)) {
        return ;
    }
    
    NSString *tableName = [self getTableNameWithClass:targetClass];
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        
        if (![engine isTableExists:tableName]) {
            return;
        }
        
        [engine deleteObjectsByClassName:NSStringFromClass(targetClass) fromTable:tableName];
        [engine close];
    }
}

+ (void)updateData:(PersistObject *)data inDB:(NSString *)dbName{
    if (!(dbName.length > 0) || data==nil) {
        return;
    }
    
    NSString *tableName = [self getTableNameWithClass:[data class]];
    @synchronized ([[PersistLockManager shareManager] getLock:tableName]) {
        PersistEngine *engine = [[PersistEngine alloc] initDBWithName:dbName];
        
        if (![engine isTableExists:tableName]) {
            [engine createTableWithName:tableName];
        }
        
        [engine updateObject:data intoTable:tableName];
    }
}

+ (void)autoUpdateDataWith:(UpdatePersistObjectBlock)block inDB:(NSString *)dbName{
    PersistObject *obj = block();
    [self updateData:obj inDB:dbName];
}

#pragma mark - 辅助方法

+ (NSString *)getTableNameWithClass:(Class)targetClass{
    NSString *className = NSStringFromClass(targetClass);
    NSString *tableName = nil;
    if (className.length > 0) {
        tableName = [NSString stringWithFormat:@"%@_Table",className];
    }
    
    return tableName;
}

+ (NSArray *)transferJsonArray:(NSArray *)objectsArray{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    for (NSDictionary *dict in objectsArray) {
        NSString *className = dict[@"className"];
        NSString *json = dict[@"json"];
        
        Class someClass = NSClassFromString(className);
        id object = [[someClass alloc] init];
        if (![object isKindOfClass:[PersistObject class]]) {
            continue;
        }
        
        
        NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:nil];
        if (jsonDict[@"className"]) {
            PersistObject *persistObj = [NSClassFromString(jsonDict[@"className"]) modelWithDictionary:jsonDict];
            [result addObject:persistObj];
        }


    }
    
    return result;
    
}


@end
