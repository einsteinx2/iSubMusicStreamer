//
//  BassEffectDAO.h
//  Anghami
//
//  Created by Benjamin Baron on 12/4/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#define BassEffectTempCustomPresetId 1000000
#define BassEffectUserPresetStartId 1000

typedef enum 
{
	BassEffectType_ParametricEQ = 1
} BassEffectType;

@class BassEffectValue;
@interface BassEffectDAO : NSObject

@property BassEffectType type;
@property (weak, readonly) NSArray *presetsArray;
@property (strong) NSDictionary *presets;
@property (weak, readonly) NSArray *userPresetsArray;
@property (weak, readonly) NSArray *userPresetsArrayMinusCustom;
@property (weak, readonly) NSDictionary *userPresets;
@property (weak, readonly) NSDictionary *defaultPresets;

@property (readonly) NSUInteger userPresetsCount;
@property (readonly) NSUInteger defaultPresetsCount;

@property (readonly) NSUInteger selectedPresetIndex;
@property NSUInteger selectedPresetId;
@property (weak, readonly) NSDictionary *selectedPreset;
@property (weak, readonly) NSArray *selectedPresetValues;

- (id)initWithType:(BassEffectType)effectType;
- (void)setup;

- (BassEffectValue *)valueForIndex:(NSInteger)index;
- (void)selectPresetId:(NSUInteger)presetId;
- (void)selectPresetAtIndex:(NSUInteger)presetIndex;
- (void)saveCustomPreset:(NSArray *)arrayOfPoints name:(NSString *)name presetId:(NSUInteger)presetId;
- (void)saveCustomPreset:(NSArray *)arrayOfPoints name:(NSString *)name;
- (void)saveTempCustomPreset:(NSArray *)arrayOfPoints;

- (void)deleteCustomPresetForId:(NSUInteger)presetId;
- (void)deleteCustomPresetForIndex:(NSUInteger)presetIndex;
- (void)deleteTempCustomPreset;

@end