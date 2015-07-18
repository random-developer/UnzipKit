//
//  PerformOnDataTests.m
//  UnzipKit
//
//  Created by Dov Frankel on 7/16/15.
//  Copyright (c) 2015 Abbey Code. All rights reserved.
//

#import "UZKArchiveTestCase.h"
@import UnzipKit;

@interface PerformOnDataTests : UZKArchiveTestCase
@end

@implementation PerformOnDataTests


- (void)testPerformOnData
{
    NSArray *testArchives = @[@"Test Archive.zip",
                              @"Test Archive (Password).zip"];
    
    NSSet *expectedFileSet = self.nonZipTestFilePaths;
    NSArray *expectedFiles = [expectedFileSet.allObjects sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        UZKArchive *archive = [UZKArchive zipArchiveAtURL:testArchiveURL password:password];
        
        __block NSUInteger fileIndex = 0;
        NSError *error = nil;
        
        [archive performOnDataInArchive:
         ^(UZKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
             NSString *expectedFilename = expectedFiles[fileIndex++];
             XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
             
             NSData *expectedFileData = [NSData dataWithContentsOfURL:self.testFileURLs[expectedFilename]];
             
             XCTAssertNotNil(fileData, @"No data extracted");
             XCTAssertTrue([expectedFileData isEqualToData:fileData], @"File data doesn't match original file");
         } error:&error];
        
        XCTAssertNil(error, @"Error iterating through files");
        XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
    }
}

- (void)testPerformOnData_Unicode
{
    NSSet *expectedFileSet = self.nonZipUnicodeFilePaths;
    NSArray *expectedFiles = [expectedFileSet.allObjects sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.zip"];
    UZKArchive *archive = [UZKArchive zipArchiveAtURL:testArchiveURL];
    
    __block NSUInteger fileIndex = 0;
    NSError *error = nil;
    
    [archive performOnDataInArchive:
     ^(UZKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
         NSString *expectedFilename = expectedFiles[fileIndex++];
         XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
         
         NSData *expectedFileData = [NSData dataWithContentsOfURL:self.unicodeFileURLs[expectedFilename]];
         
         XCTAssertNotNil(fileData, @"No data extracted");
         XCTAssertTrue([expectedFileData isEqualToData:fileData], @"File data doesn't match original file");
     } error:&error];
    
    XCTAssertNil(error, @"Error iterating through files");
    XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
}

- (void)testPerformOnData_FileMoved
{
    NSURL *largeArchiveURL = [self largeArchive];
    
    UZKArchive *archive = [UZKArchive zipArchiveAtURL:largeArchiveURL];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:1];
        
        NSURL *movedURL = [largeArchiveURL URLByAppendingPathExtension:@"unittest"];
        
        NSError *renameError = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm moveItemAtURL:largeArchiveURL toURL:movedURL error:&renameError];
        XCTAssertNil(renameError, @"Error renaming file: %@", renameError);
    });
    
    __block NSUInteger fileCount = 0;
    
    NSError *error = nil;
    BOOL success = [archive performOnDataInArchive:^(UZKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        if (!fileInfo.isDirectory) {
            fileCount++;
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertEqual(fileCount, 5, @"Not all files read");
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}

- (void)testPerformOnData_FileDeleted
{
    NSURL *largeArchiveURL = [self largeArchive];
    
    UZKArchive *archive = [UZKArchive zipArchiveAtURL:largeArchiveURL];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:1];
        
        NSError *removeError = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtURL:largeArchiveURL error:&removeError];
        XCTAssertNil(removeError, @"Error removing file: %@", removeError);
    });
    
    __block NSUInteger fileCount = 0;
    
    NSError *error = nil;
    BOOL success = [archive performOnDataInArchive:^(UZKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        if (!fileInfo.isDirectory) {
            fileCount++;
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertEqual(fileCount, 5, @"Not all files read");
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}

- (void)testPerformOnData_FileMovedBeforeBegin
{
    NSURL *largeArchiveURL = [self largeArchive];
    
    UZKArchive *archive = [UZKArchive zipArchiveAtURL:largeArchiveURL];
    
    NSURL *movedURL = [largeArchiveURL URLByAppendingPathExtension:@"unittest"];
    
    NSError *renameError = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm moveItemAtURL:largeArchiveURL toURL:movedURL error:&renameError];
    XCTAssertNil(renameError, @"Error renaming file: %@", renameError);
    
    __block NSUInteger fileCount = 0;
    
    NSError *error = nil;
    BOOL success = [archive performOnDataInArchive:^(UZKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        if (!fileInfo.isDirectory) {
            fileCount++;
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertEqual(fileCount, 5, @"Not all files read");
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}


@end
