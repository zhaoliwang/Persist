//
//  PersistTests.m
//  PersistTests
//
//  Created by liwang.zhao on 2017/4/5.
//  Copyright © 2017年 LandOfMystery. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PersistObject.h"
#import "PersistHandler.h"
#import "NSObject+YYModel.h"

#define  TESTDB @"test.sqlite"

@interface Students : PersistObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSNumber *age;

@end

@implementation Students

@end

@interface Teacher : PersistObject<YYModel>

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSNumber *age;

@property (nonatomic, strong) NSArray<Students *> *students;

@end

@implementation Teacher

//json 反序列化需要
+ (NSDictionary *)modelContainerPropertyGenericClass {
    return @{@"students" : [Students class]};
}


@end


@interface PersistTests : XCTestCase

@end

@implementation PersistTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [PersistHandler removeAllDataWithClass:[Teacher class] inDB:TESTDB];
    [PersistHandler removeAllDataWithClass:[Students class] inDB:TESTDB];

}

- (void)testGetDataWithClass{
    Students *student1 = [[Students alloc] init];
    student1.name = @"小明";
    student1.age = @6;
    
    Students *student2 = [[Students alloc] init];
    student2.name = @"小红";
    student2.age = @7;
    
    Teacher *teacherA = [[Teacher alloc] init];
    teacherA.age = @45;
    teacherA.name = @"老李";
    teacherA.students = @[student1,student2];
    
    
    [PersistHandler addData:teacherA inDB:TESTDB];
    [PersistHandler addDataWithArray:@[student1,student2] inDB:TESTDB];
    
    
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 2, @"There must be 2 students");
    
    Students *studentA = students[0];
    XCTAssert([studentA.name isEqualToString:@"小明"], @"StudentA's name is not correct");
    XCTAssert(studentA.age.integerValue == 6, @"StudentA's age is not correct");
    Students *studentB = students[1];
    XCTAssert([studentB.name isEqualToString:@"小红"], @"StudentB's name is not correct");
    XCTAssert(studentB.age.integerValue == 7, @"StudentB's age is not correct");
    
    NSArray *teachers = [PersistHandler getDataWithClass:[Teacher class] inDB:TESTDB];
    Teacher *teacher = [teachers firstObject];
    XCTAssert([teacher.name isEqualToString:@"老李"], @"Teacher's name is not correct");
    XCTAssert(teacher.age.integerValue == 45, @"Teacher's age is not correct");
    
    studentA = teacher.students[0];
    XCTAssert([studentA.name isEqualToString:@"小明"], @"StudentA's name is not correct");
    XCTAssert(studentA.age.integerValue == 6, @"StudentA's age is not correct");
    studentB = teacher.students[1];
    XCTAssert([studentB.name isEqualToString:@"小红"], @"StudentB's name is not correct");
    XCTAssert(studentB.age.integerValue == 7, @"StudentB's age is not correct");
}

- (void)testReplaceDataWithObject{
    Students *aBoy = [[Students alloc] init];
    aBoy.name = @"岳云鹏";
    aBoy.age = @33;
    [PersistHandler addData:aBoy inDB:TESTDB];
    
    Students *student = [[Students alloc] init];
    student.name = @"约汉";
    student.age = @35;
    [PersistHandler replaceDataWithObject:student inDB:TESTDB];
    
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 1, @"There must be one student here");
    Students *aGirl = [students firstObject];
    XCTAssert([aGirl.name isEqualToString:@"约汉"], @"A Girl Student's name is not right ");
    XCTAssert(aGirl.age.integerValue == 35, @"A Girl Student's age is not Correct");
}

- (void)testUpdateData{
    Students *aBoy = [[Students alloc] init];
    aBoy.name = @"岳云鹏";
    aBoy.age = @33;
    [PersistHandler addData:aBoy inDB:TESTDB];
    
    aBoy.name = @"胖子孙越";
    aBoy.age = @37;
    [PersistHandler updateData:aBoy inDB:TESTDB];
    
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 1, @"There must be one student here");
    Students *aGirl = [students firstObject];
    XCTAssert([aGirl.name isEqualToString:@"胖子孙越"], @"A Girl Student's name is not right ");
    XCTAssert(aGirl.age.integerValue == 37, @"A Girl Student's age is not Correct");
    
}

//这个测试会失败，addSingleData方法由调用方保证只调用一次
- (void)testSingleAdd{
    Students *aBoy = [[Students alloc] init];
    aBoy.name = @"郭德纲";
    aBoy.age = @44;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [PersistHandler addSingleData:aBoy inDB:TESTDB];
    });
    
    Students *bBoy = [[Students alloc] init];
    bBoy.name = @"于谦";
    bBoy.age = @44;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [PersistHandler addSingleData:bBoy inDB:TESTDB];
    });
    sleep(15);
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 1, @"There must be one student here");
    
}

- (void)testSingleUpdate{
    Students *aBoy = [[Students alloc] init];
    aBoy.name = @"郭德纲";
    aBoy.age = @44;
    
    [PersistHandler addSingleData:aBoy inDB:TESTDB];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        Students *bBoy = [Students objectInDB:TESTDB autoInit:YES];
        bBoy.name = @"曹云金";
        bBoy.age = @34;
        
        [PersistHandler updateData:bBoy inDB:TESTDB];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        Students *bBoy = [Students objectInDB:TESTDB autoInit:YES];
        bBoy.name = @"于谦";
        bBoy.age = @48;
        
        [PersistHandler updateData:bBoy inDB:TESTDB];
        
    });
    
    sleep(10);
    
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 1, @"There must be one student here");
    
}

- (void)testUnique{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        Students *aBoy = [Students objectInDB:TESTDB autoInit:YES];
        NSLog(@"%@",aBoy.uuid);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        Students *aBoy = [Students objectInDB:TESTDB autoInit:YES];
        NSLog(@"%@",aBoy.uuid);
    });
    
    sleep(15);
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 1, @"There must be one student here");
    
}

- (void)testMultiUpdate{
    Students *aBoy = [[Students alloc] init];
    aBoy.name = @"郭德纲";
    aBoy.age = @44;
    
    [PersistHandler addSingleData:aBoy inDB:TESTDB];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        Students *bBoy = [[Students alloc] init];
        bBoy.name = @"曹云金";
        bBoy.age = @34;
        
        [PersistHandler updateData:bBoy inDB:TESTDB];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        Students *bBoy = [[Students alloc] init];
        bBoy.name = @"于谦";
        bBoy.age = @48;
        
        [PersistHandler updateData:bBoy inDB:TESTDB];
        
    });
    
    sleep(10);
    
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 1, @"There must be one student here");
    
}



- (void)testReplaceDataWithArray{
    Students *aBoy = [[Students alloc] init];
    aBoy.name = @"岳云鹏";
    aBoy.age = @33;
    [PersistHandler addData:aBoy inDB:TESTDB];
    
    Students *student1 = [[Students alloc] init];
    student1.name = @"郭德纲";
    student1.age = @40;
    Students *student2 = [[Students alloc] init];
    student2.name = @"于谦";
    student2.age = @44;
    [PersistHandler replaceDataWithArray:@[student1,student2] inDB:TESTDB];
    
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 2, @"There must be 2 students");
    
    Students *studentA = students[0];
    XCTAssert([studentA.name isEqualToString:@"郭德纲"], @"StudentA's name is not correct");
    XCTAssert(studentA.age.integerValue == 40, @"StudentA's age is not correct");
    Students *studentB = students[1];
    XCTAssert([studentB.name isEqualToString:@"于谦"], @"StudentB's name is not correct");
    XCTAssert(studentB.age.integerValue == 44, @"StudentB's age is not correct");
}

- (void)testGetDataWithPredicate{
    Students *student1 = [[Students alloc] init];
    student1.name = @"郭德纲";
    student1.age = @40;
    Students *student2 = [[Students alloc] init];
    student2.name = @"于谦";
    student2.age = @44;
    [PersistHandler replaceDataWithArray:@[student1,student2] inDB:TESTDB];
    
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = '郭德纲'"];
    NSArray *students = [PersistHandler getDataWithClass:[Students class] withPredicate:predicate inDB:TESTDB];
    
    XCTAssert(students.count == 1, @"There must be one student here");
    Students *aGirl = [students firstObject];
    XCTAssert([aGirl.name isEqualToString:@"郭德纲"], @"A Girl Student's name is not right ");
    XCTAssert(aGirl.age.integerValue == 40, @"A Girl Student's age is not Correct");
}

- (void)testRemoveData{
    Students *student1 = [[Students alloc] init];
    student1.name = @"郭德纲";
    student1.age = @40;
    Students *student2 = [[Students alloc] init];
    student2.name = @"于谦";
    student2.age = @44;
    [PersistHandler replaceDataWithArray:@[student1,student2] inDB:TESTDB];
    
    [PersistHandler removeData:student2 inDB:TESTDB];
    
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 1, @"There must be one student here");
    Students *aGirl = [students firstObject];
    XCTAssert([aGirl.name isEqualToString:@"郭德纲"], @"A Girl Student's name is not right ");
    XCTAssert(aGirl.age.integerValue == 40, @"A Girl Student's age is not Correct");
}

- (void)testRemoveDataWithClass{
    Students *student1 = [[Students alloc] init];
    student1.name = @"郭德纲";
    student1.age = @40;
    Students *student2 = [[Students alloc] init];
    student2.name = @"于谦";
    student2.age = @44;
    [PersistHandler replaceDataWithArray:@[student1,student2] inDB:TESTDB];
    
    [PersistHandler removeAllDataWithClass:[Students class] inDB:TESTDB];
    
    NSArray *students = [PersistHandler getDataWithClass:[Students class] inDB:TESTDB];
    XCTAssert(students.count == 0, @"There must be none student here");
    
}

@end
