//
//  PersistHandler.h
//  Persist
//
//  Created by liwang.zhao on 2017/3/31.
//  Copyright © 2017年 LandOfMystery. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PersistObject;

typedef PersistObject* (^UpdatePersistObjectBlock)() ;


@interface PersistHandler : NSObject

/**
 *  删除数据库
 *
 *  @param path 数据库文件路径
 */
+ (void)removeDBAtPath:(NSString *)path;

/**
 *  替换本地数据
 *
 *  @param data 新的本地数据
 */
+ (void)replaceDataWithObject:(PersistObject *)data inDB:(NSString *)dbName;

/**
 *  替换本地数据
 *
 *  @param data 新的数据 数组中只能包含一个类型
 */
+ (void)replaceDataWithArray:(NSArray *)data inDB:(NSString *)dbName;

/**
 *  获取所有对应类型的数据
 *
 *  @param targetClass 必须是PersistObject类型的Class
 *
 *  @return 所有对应类型的数据
 */
+ (NSArray *)getDataWithClass:(Class)targetClass inDB:(NSString *)dbName;

/**
 *  获取所有对应类型的数据(UNI)
 *
 *  @param targetClass 必须是PersistObject类型的Class
 *
 *  @return 所有对应类型的数据
 */
+ (id)getSingleDataWithClass:(Class)targetClass inDB:(NSString *)dbName;

/**
 *  获取对应类型的部分数据(会将json数据还原为对象，然后进行匹配)
 *
 *  @param targetClass 必须是QWHPersistObject类型的Class 否则会crash
 *  @param predicate       NSPredicate
 *
 *  @return 对应类型的数据
 */
+ (NSArray *)getDataWithClass:(Class)targetClass withPredicate:(NSPredicate *)predicate inDB:(NSString *)dbName;

/**
 *  添加数据
 *
 *  @param data 数据对象
 */
+ (void)addData:(PersistObject *)data inDB:(NSString *)dbName;

/**
 *  添加数据(用于数据库只有单一数据的情况),调用方保证只调用一次
 *
 *  @param data 数据对象
 */
+ (void)addSingleData:(PersistObject *)data inDB:(NSString *)dbName;


/**
 *  批量添加数据
 *
 *  @param data 数据对象
 */
+ (void)addDataWithArray:(NSArray *)data inDB:(NSString *)dbName;

/**
 *  删除数据 只删除对应的数据
 *
 *  @param data 数据对象
 */
+ (void)removeData:(PersistObject *)data inDB:(NSString *)dbName;

/**
 *  删除所有对应类型的数据
 *
 *  @param targetClass 必须是PersistObject类型的Class 否则会crash
 */
+ (void)removeAllDataWithClass:(Class)targetClass inDB:(NSString *)dbName;

/**
 *  更新某个数据，不建议使用这个方法，请使用下面那个方法
 *
 *  @param data 数据对象
 */

+ (void)updateData:(PersistObject *)data inDB:(NSString *)dbName;

/**
 *  更新某个数据（使用这个方法不用暴露update方法）
 *
 *  @block 更新数据的逻辑
 */

+ (void)autoUpdateDataWith:(UpdatePersistObjectBlock)block inDB:(NSString *)dbName;


@end
