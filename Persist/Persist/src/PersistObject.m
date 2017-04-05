//
//  PersistObject.m
//  Persist
//
//  Created by liwang.zhao on 2017/3/30.
//  Copyright © 2017年 LandOfMystery. All rights reserved.
//

#import "PersistObject.h"
#import "PersistHandler.h"

@implementation PersistObject

- (instancetype)init{
    self = [super init];
    if (self) {
        _className = NSStringFromClass([self class]);
        _uuid = [[NSUUID UUID] UUIDString];
    }
    
    return self;
}

// 升级时需要子类实现，每次model改变时（增减字段），需要＋1
+ (NSInteger)getModelVersion{
    return 0;
}

// model改变时，需要做旧数据迁移，数据采用字典类型存放;需要子类实现
+ (void)migrationWith:(NSDictionary *)oldDict newObj:(NSMutableDictionary *)newDict version:(NSInteger)version{
    //    //示例
    //    if (version < 1) {
    //        newDict[@"name"] = [NSString stringWithFormat:@"%@ %@",oldDict[@"firstName"],oldDict[@"lastName"]];
    //        [newDict removeObjectForKey:@"firstName"];
    //        [newDict removeObjectForKey:@"lastName"];
    //        oldDict = [newDict copy];
    //    }
    //
    //    if (version < 2) {
    //        newDict[@"email"] = [NSString stringWithFormat:@"%@@gmail.com",oldDict[@"name"]];
    //    }
}

// 获取数据库中单个元素(UNI)
+ (instancetype)objectInDB:(NSString *)db autoInit:(BOOL)isAutoInit{
    @synchronized (self) {
        //        NSArray *array = [QWHPersistHelper getDataWithClass:self inDB:db];
        id object =  [PersistHandler getSingleDataWithClass:self inDB:db];
        if (object) {
            return object;
        } else {
            if (isAutoInit) {
                id object = [[self alloc] init];
                //                [QWHPersistHelper addData:object inDB:db];
                [PersistHandler addSingleData:object inDB:db];
                return object;
            }
        }
        
        return nil;
    }
    
}

@end
