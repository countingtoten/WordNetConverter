//
//  main.m
//  WordNetConverter
//
//  Created by James Weinert on 12/16/12.
//  Copyright (c) 2012 James Weinert. All rights reserved.
//

#import "DefToPosMap.h"
#import "FileReader.h"
#import "FMDatabase.h"
#import "WordToDefMap.h"

typedef enum {
    WordNetNoun,
    WordNetVerb,
    WordNetAdjective,
    WordNetAdverb
} WordNetPartOfSpeech;

static NSManagedObjectModel *managedObjectModel()
{
    static NSManagedObjectModel *model = nil;
    if (model != nil) {
        return model;
    }
    
    NSString *path = @"WordNetConverter";
    path = [path stringByDeletingPathExtension];
    NSURL *modelURL = [NSURL fileURLWithPath:[path stringByAppendingPathExtension:@"momd"]];
    model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    return model;
}

static NSManagedObjectContext *managedObjectContext()
{
    static NSManagedObjectContext *context = nil;
    if (context != nil) {
        return context;
    }

    @autoreleasepool {
        context = [[NSManagedObjectContext alloc] init];
        
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel()];
        [context setPersistentStoreCoordinator:coordinator];
        
        NSString *STORE_TYPE = NSSQLiteStoreType;
        
        NSString *path = [[NSProcessInfo processInfo] arguments][0];
        path = [path stringByDeletingPathExtension];
        NSURL *url = [NSURL fileURLWithPath:[path stringByAppendingPathExtension:@"sqlite"]];
        
        NSError *error;
        NSPersistentStore *newStore = [coordinator addPersistentStoreWithType:STORE_TYPE configuration:nil URL:url options:nil error:&error];
        
        if (newStore == nil) {
            NSLog(@"Store Configuration Failure %@", ([error localizedDescription] != nil) ? [error localizedDescription] : @"Unknown Error");
        }
    }
    return context;
}

void createDatabaseOriginal();

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        createDatabaseOriginal();
        /*
         // Create the managed object context
        NSManagedObjectContext *context = managedObjectContext();
        
        // Custom code here...
        // Save the managed object context
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Error while saving %@", ([error localizedDescription] != nil) ? [error localizedDescription] : @"Unknown Error");
            exit(1);
        }*/
    }
    return 0;
}

void createDatabaseOriginal() {
    FMDatabase *db = [FMDatabase databaseWithPath:@"WordNetDictionary.sqlite"];
    [db open];
    //[db executeQuery:@"PRAGMA foreign_keys = ON;"];
    //db.traceExecution = YES;
    
    FMResultSet *wordTableExistRS = [db executeQuery:@"SELECT name FROM sqlite_master WHERE type='table' AND name='words';"];
    if ([wordTableExistRS next] == NO) {
        [db beginTransaction];
        BOOL tableCreated = [db executeUpdate:@"CREATE VIRTUAL TABLE words USING FTS4(wordid INTEGER PRIMARY KEY, lemma TEXT);"];
        if (tableCreated == NO) {
            NSLog(@"*** Failed: %d (%@)", [db lastErrorCode], [db lastErrorMessage]);
            return;
        }else{
            NSLog(@"OK, Virtual word Table created.");
        }
        [db commit];
    }
    
    FMResultSet *defTableExistRS = [db executeQuery:@"SELECT name FROM sqlite_master WHERE type='table' AND name='synsets';"];
    if ([defTableExistRS next] == NO) {
        [db beginTransaction];
        BOOL tableCreated = [db executeUpdate:@"CREATE TABLE synsets(synsetid INTEGER PRIMARY KEY, definition TEXT, partofspeech INTEGER);"];
        if (tableCreated == NO) {
            NSLog(@"*** Failed: %d (%@)", [db lastErrorCode], [db lastErrorMessage]);
            return;
        }else{
            NSLog(@"OK, Virtual word Table created.");
        }
        [db commit];
    }

    FMResultSet *linkTableExistRS = [db executeQuery:@"SELECT name FROM sqlite_master WHERE type='table' AND name='links';"];
    if ([linkTableExistRS next] == NO) {
        [db beginTransaction];
        BOOL tableCreated = [db executeUpdate:@"CREATE TABLE links(wordkey INTEGER, synsetkey INTEGER, priority INTEGER);"];
        if (tableCreated == NO) {
            NSLog(@"*** Failed: %d (%@)", [db lastErrorCode], [db lastErrorMessage]);
            return;
        }else{
            NSLog(@"OK, Virtual word Table created.");
        }
        [db commit];
    }
    
    NSArray *types = [[NSArray alloc] initWithObjects:@"adv", @"adj", @"verb", @"noun", nil];
    //NSArray *types = [[NSArray alloc] initWithObjects:@"test", nil];
    NSMutableArray *wordsArray = [NSMutableArray array];
    NSMutableArray *definitionsArray = [NSMutableArray array];
    NSMutableArray *wordsToDefsArray = [NSMutableArray array];
    NSMutableArray *defsToPosArray = [NSMutableArray array];
    
    // For each file adj, adv, noun, verb
    for (NSString *wordType in types) {
        NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
        
        NSLog(@"Status: loading the contents of data.%@", wordType);
        FileReader *dataFileReader = [[FileReader alloc] initWithFilePath:[[NSBundle mainBundle] pathForResource:@"data" ofType:wordType]];
        __block int dataReadLines = 0;
        [dataFileReader enumerateLinesUsingBlock:^(NSString *aNewLine, BOOL *stop) {
            if (dataReadLines < 29 ) {
                NSLog(@"Skip line %d: %@", dataReadLines, aNewLine);
            } else {
                @autoreleasepool {
                    NSRange defSplit = [aNewLine rangeOfString:@"|"]; // first occurence of " | "
                    NSRange keySplit = [aNewLine rangeOfString:@" "];
                    if (defSplit.location != NSNotFound) {
                        NSString *definition = [[aNewLine substringFromIndex:defSplit.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        NSString *key = [aNewLine substringToIndex:keySplit.location];
                        
                        [dataDict setObject:definition forKey:key];
                        
                        if (dataReadLines % 1000 == 0) {
                            NSLog(@"Reaches line: %d", dataReadLines);
                        }
                    }
                }
            }
            dataReadLines++;
        }];
        NSLog(@"Reaches line: %d", dataReadLines);
        
        FileReader *indexFileReader = [[FileReader alloc] initWithFilePath:[[NSBundle mainBundle] pathForResource:@"index" ofType:wordType]];
        
        __block int indexReadLines = 0;
        [indexFileReader enumerateLinesUsingBlock:^(NSString *aNewLine, BOOL *stop) {
            if (indexReadLines < 29 ) {
                NSLog(@"Skip line %d: %@", indexReadLines, aNewLine);
            } else {
                @autoreleasepool {
                    NSArray *lineParts = [[aNewLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@" "];
                    
                    // lemma  pos  synset_cnt  p_cnt  [ptr_symbol...]  sense_cnt  tagsense_cnt  [synset_offset...]
                    NSString *wordToDefine = [[[lineParts objectAtIndex:0] stringByReplacingOccurrencesOfString:@"_" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    NSString *synsetCountString = [lineParts objectAtIndex:2];
                    NSUInteger synsetCount = [synsetCountString intValue];
                    
                    NSString *ptrSymbolCountString = [lineParts objectAtIndex:3];
                    NSUInteger ptrSymbolCount = [ptrSymbolCountString intValue];
                    
                    NSUInteger synsetOffset = 6 + ptrSymbolCount;
                    
                    NSUInteger wordID;
                    // Check if word is already inserted into the database
                    if (![wordsArray containsObject:wordToDefine]) {
                        wordID = [wordsArray count] + 1;
                        [wordsArray addObject:wordToDefine];
                    } else {
                        wordID = [wordsArray indexOfObject:wordToDefine] + 1;
                    }
                    
                    for (NSUInteger i = 0; i < synsetCount; i++) {
                        NSString *key = [lineParts objectAtIndex:(synsetOffset + i)];
                        
                        NSString *definition = [dataDict objectForKey:key];
                        
                        NSUInteger defID;
                        if (![definitionsArray containsObject:definition]) {
                            defID = [definitionsArray count] + 1;
                            [definitionsArray addObject:definition];
                            
                            DefToPosMap *defToPos = [[DefToPosMap alloc] init];
                            defToPos.definition = definition;
                            defToPos.defID = defID;
                            if ([wordType isEqualToString:@"adj"]) {
                                defToPos.partOfSpeech = WordNetAdjective;
                            } else if ([wordType isEqualToString:@"adv"]) {
                                defToPos.partOfSpeech = WordNetAdverb;
                            } else if ([wordType isEqualToString:@"noun"]) {
                                defToPos.partOfSpeech = WordNetNoun;
                            } else if ([wordType isEqualToString:@"verb"]) {
                                defToPos.partOfSpeech = WordNetVerb;
                            }
                            
                            [defsToPosArray addObject:defToPos];
                        } else {
                            defID = [definitionsArray indexOfObject:definition] + 1;
                        }
                        WordToDefMap *wordToDef = [[WordToDefMap alloc] init];
                        wordToDef.wordID = wordID;
                        wordToDef.defID = defID;
                        wordToDef.priority = i;
                        
                        [wordsToDefsArray addObject:wordToDef];
                    }
                    
                    if (indexReadLines % 1000 == 0) {
                        NSLog(@"Reaches line: %d", indexReadLines);
                    }
                    
                }
            }
            indexReadLines++;
        }];
        NSLog(@"Reaches line: %d", indexReadLines);
    }
    
    
    NSLog(@"Writing words to database");
    [db beginTransaction];
    NSUInteger wordid = 1;
    for (NSString *lemma in wordsArray) {
        BOOL successful = [db executeUpdate:@"INSERT INTO words(wordid, lemma) VALUES(?, ?);", [NSNumber numberWithInteger:wordid], lemma];
        if(successful == NO) {
            NSLog(@"*** Failed: %d (%@)", [db lastErrorCode], [db lastErrorMessage]);
        }
        wordid++;
    }
    [db commit];
    
    NSLog(@"Writing definitions to database");
    [db beginTransaction];
    for (DefToPosMap *defToPos in defsToPosArray) {
        BOOL successful = [db executeUpdate:@"INSERT INTO synsets(synsetid, definition, partofspeech) VALUES(?, ?, ?);", [NSNumber numberWithInteger:defToPos.defID], defToPos.definition, [NSNumber numberWithInteger:defToPos.partOfSpeech]];
        if(successful == NO) {
            NSLog(@"*** Failed: %d (%@)", [db lastErrorCode], [db lastErrorMessage]);
        }
    }
    [db commit];
    
    NSLog(@"Writing word to definition link to database");
    [db beginTransaction];
    for (WordToDefMap *wordToDef in wordsToDefsArray) {
        BOOL successful = [db executeUpdate:@"INSERT INTO links(wordkey, synsetkey, priority) VALUES(?, ?, ?);", [NSNumber numberWithInteger:wordToDef.wordID], [NSNumber numberWithInteger:wordToDef.defID], [NSNumber numberWithInteger:wordToDef.priority]];
        if(successful == NO) {
            NSLog(@"*** Failed: %d (%@)", [db lastErrorCode], [db lastErrorMessage]);
            NSLog(@"wordid %lu synsetid %lu priority %lu", wordToDef.wordID, wordToDef.defID, wordToDef.priority);
        }
    }
    [db commit];
    
    NSLog(@"Data saved");
    NSLog(@"Total words: %lu", [wordsArray count]);
    NSLog(@"Total definitions: %lu", [defsToPosArray count]);
    NSLog(@"Total links: %lu", [wordsToDefsArray count]);
    
    NSLog(@"Definitions Array Count: %lu", [definitionsArray count]);
    
    [db close];
}

