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

#ifdef DEV_BUILD
#import <objc/runtime.h>
#endif

@interface XXXPersistVersion : PersistObject

@property (nonatomic, strong) NSString *signatures;
@property (nonatomic, strong) NSNumber *classVersion;
@property (nonatomic, strong) NSString *name;

@end

@implementation XXXPersistVersion

@end

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
#ifdef DEV_BUILD
        [manager checkVersion];
#endif
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

#ifdef DEV_BUILD
- (void)checkVersion{

    //监测是否存在versionTable
    PersistEngine *engine = [[PersistEngine alloc] initDBWithName:@"version.sql"];
    NSString *tableName = @"XXXPersistVersion_Table";
    BOOL isExistVerisonTable = [engine isTableExists:tableName];
    NSArray *allObjects;

    if (isExistVerisonTable) {
        allObjects = [engine getObjectByClassName:@"XXXPersistVersion" fromTable:tableName];
        allObjects = [PersistHandler transferJsonArray:allObjects];
    }
    
    int numClasses;
    Class * classes = NULL;
    numClasses = objc_getClassList(NULL, 0);
    
    if (numClasses > 0 ){
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        
        numClasses = objc_getClassList(classes, numClasses);
        
        for (int i = 0; i < numClasses; i++) {
            Class class = classes[i];
            
            if ([[self class] isSubClass:class ofSuperClass:[PersistObject class]]) {
                
                NSString *className = [NSString stringWithCString:class_getName(class) encoding:NSUTF8StringEncoding];
                if ([className isEqualToString:@"XXXPersistVersion"] || [className isEqualToString:@"PersistObject"]) {
                    continue;
                }
                
                unsigned int propertyCount;
                objc_property_t * properties = class_copyPropertyList(class, &propertyCount);
                NSMutableArray *attrArray = [[NSMutableArray alloc] init];
                
                for (int i = 0; i < propertyCount; i++) {
                    objc_property_t property = properties[i];
                    const char *attributes = property_getAttributes(property);
                    NSString *str = [NSString stringWithCString:attributes encoding:NSUTF8StringEncoding];
                    [attrArray addObject:str];
                }
                
                [attrArray sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                    return [((NSString *)obj1) caseInsensitiveCompare:(NSString *)obj2];
                }];
                
                NSString *signatures = @"";
                for (NSString *attr in attrArray) {
                    signatures = [NSString stringWithFormat:@"%@%@",signatures,attr];
                }
                
                int (*getVersion)(id,SEL);
                getVersion = (int (*)(id, SEL))[class methodForSelector:@selector(getModelVersion)];
                int version = getVersion(class, @selector(getModelVersion));
                
                if (isExistVerisonTable) {
                    NSString *predicate = [NSString stringWithFormat:@"name='%@'",[NSString stringWithCString:class_getName(class) encoding:NSUTF8StringEncoding]];
                    NSArray *filtedArray = [allObjects filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:predicate]];
                    if (filtedArray && filtedArray.count == 1) {
                        XXXPersistVersion *obj = [filtedArray firstObject];
                        if (![obj.signatures isEqualToString:signatures]) {
                            if (version <= [obj.classVersion integerValue]) {
                                NSString *reason = [NSString stringWithFormat:@"className:%s 字段发生变化但是没有将迁移老数据，请实现方法+ (void)migrationWith:(NSDictionary *)oldDict newObj:(NSMutableDictionary *)newDict version:(NSInteger)version 以及 + (NSInteger)getModelVersion;",class_getName(class)];
                                NSException *exception = [[NSException alloc] initWithName:@"DB Version Error" reason:reason userInfo:nil];
                                @throw exception;

                            } else {
                                obj.classVersion = @(version);
                                obj.signatures = signatures;
                                [engine updateObject:obj intoTable:tableName];
                            }
                        }
                    } else {
                        XXXPersistVersion *obj = [[XXXPersistVersion alloc] init];
                        obj.signatures = signatures;
                        obj.classVersion = @(version);
                        obj.name = [NSString stringWithCString:class_getName(class) encoding:NSUTF8StringEncoding];
                        
                        [engine putObject:obj intoTable:tableName];
                    }
                } else{
                    [engine createTableWithName:tableName];

                    XXXPersistVersion *obj = [[XXXPersistVersion alloc] init];
                    obj.signatures = signatures;
                    obj.classVersion = @(version);
                    obj.name = [NSString stringWithCString:class_getName(class) encoding:NSUTF8StringEncoding];
                    
                    [engine putObject:obj intoTable:tableName];
                }
                
                free(properties);

            }
 
        }
        free(classes);
    }

}

+ (BOOL)isSubClass:(Class)class ofSuperClass:(Class)targeClass{
    while(1)
    {
        if(class == targeClass) return YES;
        id superClass = class_getSuperclass(class);
        if(class == superClass) return (superClass == targeClass);
        class = superClass;
    }

}

#endif

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
