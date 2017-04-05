//
//  PersistEngine.m
//  Persist
//
//  Created by liwang.zhao on 2017/3/30.
//  Copyright © 2017年 LandOfMystery. All rights reserved.
//

#import "PersistEngine.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"
#import "PersistObject.h"
#import "NSObject+YYModel.h"
#import "NSDictionary+YYAdd.h"

#define PATH_OF_DOCUMENT    [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]

@interface DBQueuePool()

@property (nonatomic, strong) NSMutableDictionary *dbQueueCache;

@end

@implementation DBQueuePool

+ (instancetype)shareDBQueuePool{
    static DBQueuePool *shareDBQueuePool;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        shareDBQueuePool = [[DBQueuePool alloc] init];
        shareDBQueuePool.dbQueueCache = [[NSMutableDictionary alloc] init];
    });
    
    return shareDBQueuePool;
}

- (FMDatabaseQueue *)getDBQueueWithDBPath:(NSString *)dbPath{
    @synchronized(self) {
        FMDatabaseQueue *queue = nil;
        for (NSString *key in [_dbQueueCache allKeys]) {
            if ([key isEqualToString:dbPath]) {
                NSMutableDictionary *dict = (NSMutableDictionary *)[_dbQueueCache objectForKey:key];
                queue = dict[@"queue"];
                dict[@"count"] = [NSNumber numberWithInteger:([dict[@"count"] integerValue] + 1)];
            }
        }
        
        if (!queue) {
            queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            dict[@"queue"] = queue;
            dict[@"count"] = @1;
            [_dbQueueCache removeObjectForKey:dbPath];
        }
        return queue;
    }
}

- (void)releaseDBQueueWithDBPath:(NSString *)dbPath{
    @synchronized(self) {
        NSMutableDictionary *dict = nil;
        
        for (NSString *key in [_dbQueueCache allKeys]) {
            if ([key isEqualToString:dbPath]) {
                dict = (NSMutableDictionary *)[_dbQueueCache objectForKey:key];
            }
        }
        
        if (dict) {
            NSInteger count = [dict[@"count"] integerValue];
            if (count == 1) {
                FMDatabaseQueue *queue = dict[@"queue"];
                [queue close];
                [_dbQueueCache removeObjectForKey:dbPath];
            } else {
                dict[@"count"] = [NSNumber numberWithInteger:(count - 1)];
            }
        }
    }
}

@end

//用来管理数据升级的类
@interface MigrationManager : NSObject

@property (nonatomic, strong) NSMutableArray *migrationClasses;     //用于标识哪些类已经升级

@end

@implementation MigrationManager

+ (instancetype)shareMigrationManager{
    static MigrationManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        manager = [[MigrationManager alloc] init];
        manager.migrationClasses = [[NSMutableArray alloc] init];
    });
    
    return manager;
}


@end

@interface PersistEngine()

@property (strong, nonatomic) FMDatabaseQueue * dbQueue;
@property (strong, nonatomic) NSString *dbPath;

@end

@implementation PersistEngine

static NSString *const DEFAULT_DB_NAME = @"database.sqlite";

static NSString *const CREATE_TABLE_SQL =
@"CREATE TABLE IF NOT EXISTS %@ ( \
uuid TEXT NOT NULL, \
className TEXT NOT NULL, \
json TEXT NOT NULL, \
version INTEGER ,\
PRIMARY KEY(uuid)) \
";

static NSString *const UPDATE_ITEM_SQL = @"REPLACE INTO %@ (uuid, className, json, version) values (?, ?, ?, ?)";
static NSString *const UPDATE_SQL = @"UPDATE %@ SET json = ?,version = ? where uuid = ?";
static NSString *const QUERY_ITEM_UUID_SQL = @"SELECT json, className, version from %@ where uuid = ? Limit 1";
static NSString *const QUERY_ITEM_CLASSNAME_SQL = @"SELECT json, uuid, version from %@ where className = ?";
static NSString *const QUERY_ITEM_CLASSNAME_AND_KEYWORD_SQL = @"SELECT json, uuid from %@ where className = ? AND json LIKE '%%%@%%'";
static NSString *const COUNT_ALL_SQL = @"SELECT count(*) as num from %@";
static NSString *const CLEAR_ALL_SQL = @"DELETE from %@";
static NSString *const DELETE_ITEM_SQL = @"DELETE from %@ where uuid = ?";
static NSString *const DELETE_ITEM_BYCLASSNAME_SQL = @"DELETE from %@ where className = ?";
static NSString *const DELETE_ITEMS_SQL = @"DELETE from %@ where uuid in ( %@ )";

- (void)dealloc{
    [[DBQueuePool shareDBQueuePool] releaseDBQueueWithDBPath:_dbPath];
}

//检测table name格式是否有误
+ (BOOL)checkTableName:(NSString *)tableName {
    if (tableName == nil || tableName.length == 0 || [tableName rangeOfString:@" "].location != NSNotFound) {
        return NO;
    }
    return YES;
}

- (id)init {
    return [self initDBWithName:DEFAULT_DB_NAME];
}

- (id)initDBWithName:(NSString *)dbName {
    self = [super init];
    if (self) {
        NSString *dbPath = [PATH_OF_DOCUMENT stringByAppendingPathComponent:dbName];
        if (_dbQueue) {
            [self close];
        }
        _dbPath = dbPath;
        _dbQueue = [[DBQueuePool shareDBQueuePool] getDBQueueWithDBPath:dbPath];
    }
    return self;
}

- (id)initWithDBWithPath:(NSString *)dbPath {
    self = [super init];
    if (self) {
        if (_dbQueue) {
            [self close];
        }
        _dbPath = dbPath;
        _dbQueue = [[DBQueuePool shareDBQueuePool] getDBQueueWithDBPath:dbPath];
    }
    return self;
}

- (void)createTableWithName:(NSString *)tableName {
    if ([PersistEngine checkTableName:tableName] == NO) {
        return;
    }
    
    NSString *sql = [NSString stringWithFormat:CREATE_TABLE_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
}

- (BOOL)isTableExists:(NSString *)tableName{
    if ([PersistEngine checkTableName:tableName] == NO) {
        return NO;
    }
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db tableExists:tableName];
    }];
    return result;
}

- (void)clearTable:(NSString *)tableName {
    if ([PersistEngine checkTableName:tableName] == NO) {
        return;
    }
    NSString *sql = [NSString stringWithFormat:CLEAR_ALL_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
}

- (void)putObject:(id)object intoTable:(NSString *)tableName {
    if ([PersistEngine checkTableName:tableName] == NO) {
        return;
    }
    
    if (![object isKindOfClass:[PersistObject class]]) {
        return;
    }
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSString *objectJsonString = [object modelToJSONString];
    if (!(objectJsonString && objectJsonString.length > 0)) {
        return;
    }
    
    NSString *sql = [NSString stringWithFormat:UPDATE_ITEM_SQL, tableName];
    PersistObject *persistObject = (PersistObject *)object;
    NSInteger version = [[persistObject class] getModelVersion];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql, persistObject.uuid, persistObject.className, objectJsonString, @(version)];
    }];
}

- (void)putobjects:(NSArray *)objects intoTable:(NSString *)tableName{
    if ([PersistEngine checkTableName:tableName] == NO) {
        return;
    }
    
    for (id object in objects) {
        if (![object isKindOfClass:[PersistObject class]]) {
            return;
        }
    }
    
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSString *sql = [NSString stringWithFormat:UPDATE_ITEM_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        for (PersistObject *obj in objects) {
            NSString *objectJsonString = [obj modelToJSONString];
            if (!(objectJsonString && objectJsonString.length > 0)) {
                return;
            }
            NSInteger version = [[obj class] getModelVersion];
            result = [db executeUpdate:sql, obj.uuid, obj.className, objectJsonString, @(version)];
        }
    }];
    
}

- (NSDictionary *)getObjectByUuid:(NSString *)uuid fromTable:(NSString *)tableName {
    if ([PersistEngine checkTableName:tableName] == NO) {
        return nil;
    }
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSString *sql = [NSString stringWithFormat:QUERY_ITEM_UUID_SQL, tableName];
    __block NSString *json = nil;
    __block NSString *className = nil;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql, uuid];
        if ([rs next]) {
            json = [rs stringForColumn:@"json"];
            className = [rs stringForColumn:@"className"];
        }
        [rs close];
    }];
    
    if (json.length > 0 && className.length > 0) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"json"] = json;
        dict[@"className"] = className;
        dict[@"uuid"] = uuid;
        return dict;
    }
    return nil;
}

- (NSArray *)getObjectByClassName:(NSString *)className fromTable:(NSString *)tableName{
    if ([PersistEngine checkTableName:tableName] == NO) {
        return nil;
    }
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSString *sql = [NSString stringWithFormat:QUERY_ITEM_CLASSNAME_SQL, tableName];
    __block NSMutableArray *result = [NSMutableArray array];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql, className];
        while ([rs next]) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            dict[@"json"] = [rs stringForColumn:@"json"];
            dict[@"className"] = className;
            dict[@"uuid"] = [rs stringForColumn:@"uuid"];
            dict[@"version"] = @([rs intForColumn:@"version"]);
            [result addObject:dict];
            
        }
        [rs close];
    }];
    
    return result;
}

- (NSArray *)getObjectByClassName:(NSString *)className where:(NSString *)where fromTable:(NSString *)tableName{
    if ([PersistEngine checkTableName:tableName] == NO) {
        return nil;
    }
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSString *sql = [NSString stringWithFormat:QUERY_ITEM_CLASSNAME_AND_KEYWORD_SQL, tableName, where];
    __block NSMutableArray *result = [NSMutableArray array];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql, className];
        while ([rs next]) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            dict[@"json"] = [rs stringForColumn:@"json"];
            dict[@"className"] = className;
            dict[@"uuid"] = [rs stringForColumn:@"uuid"];
            [result addObject:dict];
            
        }
        [rs close];
    }];
    
    return result;
}

- (void)deleteObjectByUuid:(NSString *)uuid fromTable:(NSString *)tableName {
    if ([PersistEngine checkTableName:tableName] == NO) {
        return;
    }
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSString *sql = [NSString stringWithFormat:DELETE_ITEM_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql, uuid];
    }];
}

- (void)deleteObjectsByUuidArray:(NSArray *)uuidArray fromTable:(NSString *)tableName {
    if ([PersistEngine checkTableName:tableName] == NO) {
        return;
    }
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSMutableString *stringBuilder = [NSMutableString string];
    for (id objectId in uuidArray) {
        NSString *item = [NSString stringWithFormat:@" '%@' ", objectId];
        if (stringBuilder.length == 0) {
            [stringBuilder appendString:item];
        } else {
            [stringBuilder appendString:@","];
            [stringBuilder appendString:item];
        }
    }
    NSString *sql = [NSString stringWithFormat:DELETE_ITEMS_SQL, tableName, stringBuilder];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
}

- (void)deleteObjectsByClassName:(NSString *)className fromTable:(NSString *)tableName {
    if ([PersistEngine checkTableName:tableName] == NO) {
        return;
    }
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSString *sql = [NSString stringWithFormat:DELETE_ITEM_BYCLASSNAME_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql, className];
    }];
}


- (NSUInteger)getCountFromTable:(NSString *)tableName{
    if ([PersistEngine checkTableName:tableName] == NO) {
        return 0;
    }
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSString *sql = [NSString stringWithFormat:COUNT_ALL_SQL, tableName];
    __block NSInteger num = 0;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql];
        if ([rs next]) {
            num = [rs unsignedLongLongIntForColumn:@"num"];
        }
        [rs close];
    }];
    return num;
}

- (void)updateObject:(id)object intoTable:(NSString *)tableName{
    if ([PersistEngine checkTableName:tableName] == NO) {
        return;
    }
    
    [[self class] migrationWithTableName:tableName dbPath:_dbPath];
    
    NSString *sql = [NSString stringWithFormat:UPDATE_SQL, tableName];
    __block BOOL result;
    PersistObject *obj = (PersistObject *)object;
    
    NSString *objectJsonString = [obj modelToJSONString];
    NSInteger version = [[obj class] getModelVersion];
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql,objectJsonString,@(version),obj.uuid];
    }];
}

- (void)close {
    [[DBQueuePool shareDBQueuePool] releaseDBQueueWithDBPath:_dbPath];
    _dbQueue = nil;
}

#pragma mark - 辅助方法

+ (void)migrationWithTableName:(NSString *)tableName dbPath:(NSString *)dbPath{
    if ([tableName length] <= 6) {
        return;
    }
    NSString *className = [tableName substringToIndex:(tableName.length - 6)];
    Class class = NSClassFromString(className);
    if (!class) {
        return;
    }
    
    MigrationManager *manager = [MigrationManager shareMigrationManager];
    
    //保障原子性，防止数组正在迭代过程中，添加新元素，导致崩溃
    @synchronized (manager.migrationClasses) {
        for (NSString *obj in manager.migrationClasses) {
            if ([obj isEqualToString:className]) {
                return;
            }
        }
        
        [manager.migrationClasses addObject:className];
        if ([class getModelVersion] == 0) {
            return;
        }
    }
    
    PersistEngine *engine = [[PersistEngine alloc] initWithDBWithPath:dbPath];
    
    @synchronized(engine.dbQueue) {
        NSString *sql = [NSString stringWithFormat:QUERY_ITEM_CLASSNAME_SQL, tableName];
        [engine.dbQueue inDatabase:^(FMDatabase *db) {
            NSMutableArray *oldObjs = [NSMutableArray array];
            
            [db beginTransaction];
            FMResultSet *rs = [db executeQuery:sql, className];
            while ([rs next]) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                //不需要升级
                NSInteger version = [rs intForColumn:@"version"];
                if (version == [class getModelVersion]) {
                    [db commit];
                    [rs close];
                    [engine close];
                    return;
                }
                
                dict[@"json"] = [rs stringForColumn:@"json"];
                dict[@"className"] = className;
                dict[@"uuid"] = [rs stringForColumn:@"uuid"];
                dict[@"version"] = @(version);
                [oldObjs addObject:dict];
                
            }
            [db commit];
            [rs close];
            
            NSMutableArray *array = [[NSMutableArray alloc] init];
            for (NSDictionary *obj in oldObjs) {
                NSData *jsonData = [obj[@"json"] dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                         options:NSJSONReadingAllowFragments
                                                                           error:nil];
                NSMutableDictionary *newObj = [obj mutableCopy];
                [newObj setObject:jsonDict forKey:@"json"];
                [array addObject:newObj];
            }
            
            if ([class respondsToSelector:@selector(migrationWith:newObj:version:)]) {
                NSMutableArray *newDictArray = [[NSMutableArray alloc] init];
                for (NSDictionary *oldDict in array) {
                    NSMutableDictionary *newDict = [oldDict mutableCopy];
                    NSMutableDictionary *jsonDict = [newDict[@"json"] mutableCopy];
                    [class migrationWith:oldDict[@"json"] newObj:jsonDict version:[oldDict[@"version"] integerValue]];
                    [newDict setObject:jsonDict forKey:@"json"];
                    [newDictArray addObject:newDict];
                }
                
                BOOL result = NO;
                [db beginTransaction];
                BOOL isRollBack = NO;
                for (NSMutableDictionary *newDict in newDictArray) {
                    NSMutableDictionary *objectDict = newDict[@"json"];
                    NSString *objectJsonString = [objectDict jsonStringEncoded];
                    if (!(objectJsonString.length > 0)) {
                        return;
                    }
                    NSString *sql = [NSString stringWithFormat:UPDATE_ITEM_SQL, tableName];
                    NSInteger version = [class getModelVersion];
                    result = [db executeUpdate:sql, newDict[@"uuid"], newDict[@"className"], objectJsonString, @(version)];
                    if (!result) {
                        isRollBack = YES;
                        break;
                    }
                }
                if (isRollBack) {
                    [db rollback];
                } else {
                    [db commit];
                }
                
            }
            
        }];
    }
    [engine close];
}



@end
