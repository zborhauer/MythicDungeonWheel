# XML Error Fixes

## Issues Fixed

### 1. **XML Schema References**
- **Problem**: XML had invalid schema references that don't exist in the WoW environment
- **Fix**: Removed `xmlns:xsi` and `xsi:schemaLocation` attributes, kept only the basic WoW UI namespace

### 2. **Parent Template Issues**
- **Problem**: `TitleDragAreaTemplate` inheritance was causing errors
- **Fix**: Removed the problematic title bar frame and simplified the structure

### 3. **$parent References**
- **Problem**: `$parent` placeholder syntax was not resolving properly in some contexts
- **Fix**: Replaced all `$parent` references with explicit frame names:
  - `$parentTitle` → `MythicDungeonWheelFrameTitle`
  - `$parentStatusText` → `MythicDungeonWheelFrameStatusText`
  - `$parentKeystoneList` → `MythicDungeonWheelFrameKeystoneList`
  - etc.

### 4. **Frame Reference Problems**
- **Problem**: Lua code was trying to access frames using dot notation that didn't match XML structure
- **Fix**: Updated Lua code to use the global frame names directly

### 5. **Script Safety**
- **Problem**: XML scripts were calling functions without checking if the addon was loaded
- **Fix**: Added safety checks: `if MythicDungeonWheel then ... end`

### 6. **ScrollChild Initialization**
- **Problem**: ScrollChild frame wasn't properly initialized with buttons table
- **Fix**: Added proper initialization in both XML OnLoad and Lua code

## Before & After

### Before (Problematic):
```xml
<Frame name="$parentTitleBar" inherits="TitleDragAreaTemplate">
<FontString name="$parentTitle" inherits="GameFontNormal">
<Scripts>
    <OnClick>MythicDungeonWheel:StartSession()</OnClick>
</Scripts>
```

### After (Fixed):
```xml
<FontString name="MythicDungeonWheelFrameTitle" inherits="GameFontNormal">
<Scripts>
    <OnClick>
        if MythicDungeonWheel then
            MythicDungeonWheel:StartSession()
        end
    </OnClick>
</Scripts>
```

## Testing the Fixes

To verify the fixes work:

1. **Load the addon** - Should load without XML errors
2. **Open interface** - `/mdw` should show the window without errors
3. **Test buttons** - All buttons should be clickable
4. **Test scrolling** - Keystone list should display properly
5. **Test communication** - Group features should work

## Technical Notes

- The lint errors in VS Code are expected since it doesn't have access to WoW's runtime environment
- Frame globals like `MythicDungeonWheelFrame` are created by WoW when the XML loads
- The addon should now load and function properly in-game without the 61 LUA errors

## What Was Causing the Errors

The main issues were:
1. **Invalid XML structure** causing parse failures
2. **Missing frame references** causing nil value errors  
3. **Unsafe function calls** when addon wasn't fully loaded
4. **Circular reference problems** with $parent substitution

All of these have been resolved with explicit naming and proper safety checks.
