# Mythic Dungeon Wheel - Test Suite Documentation

## Overview
This test suite comprehensively validates all new functionality added to the Mythic Dungeon Wheel addon, including animation robustness, debug mode features, party synchronization, and visual highlighting.

## New Features Tested

### 1. Animation Robustness Against Keystone Removal
- **Problem Solved**: Animation breaking when keystones are removed during rolling
- **Solution**: Keystone snapshot system that preserves animation state
- **Tests**: 
  - Keystone snapshot creation
  - Animation continuation after keystone removal
  - Proper UI button mapping

### 2. Debug Mode "+69 Goon Cave" Keystone
- **Problem Solved**: No test keystone available when players have no real keystones
- **Solution**: Automatic generation of debug keystone in debug mode
- **Tests**:
  - Debug keystone generation when bags are empty
  - Proper keystone attributes (level 69, "Goon Cave", isTest flag)
  - Integration with existing keystone system

### 3. Party-Wide Animation Synchronization
- **Problem Solved**: Only session owner saw rolling animation
- **Solution**: ANIMATION_STARTED message broadcast with synchronized animation
- **Tests**:
  - Message sending when session owner starts rolling
  - Message reception and synchronized animation start
  - Keystone data serialization/deserialization
  - Animation timing synchronization

### 4. Yellow/Gold Highlighting for Party Members
- **Problem Solved**: Party members saw text updates but no visual highlighting
- **Solution**: Enhanced StartSynchronizedAnimation with proper UI button highlighting
- **Tests**:
  - UI button mapping for highlighting
  - Yellow/gold color application (RGB: 0.8, 0.6, 0.2, 0.9)
  - Highlighting cycling through keystones
  - Color cleanup when animation stops

### 5. Proper Animation Cleanup
- **Problem Solved**: Stuck highlighting and animation states
- **Solution**: Enhanced KEYSTONE_SELECTED handler with proper cleanup
- **Tests**:
  - Animation stop on KEYSTONE_SELECTED message
  - Button color reset to default gray
  - State cleanup and finalization

## Test Commands

### Basic Tests
- `/mdwtest` - Basic functionality verification
- `/mdwtestall` - Complete test suite (unit tests)

### Feature-Specific Tests
- `/mdwdebug` - Test debug mode keystone generation
- `/mdwanimation` - Test animation functions and state
- `/mdwparty` - Test party communication and synchronization
- `/mdwhighlight` - Test highlighting system and colors

### Integration Tests
- `/mdwintegration` - Comprehensive integration tests
- `/mdwinttest` - Alternative command for integration tests

### Utility Commands
- `/mdwreset` - Reset test environment
- `/mdwmenu` - Show test menu and available commands

## Test Files

### 1. TestScript.lua
- Main test script with basic functionality tests
- Menu system and command setup
- Individual feature testing functions
- Environment reset capabilities

### 2. TestScrolling.lua
- Comprehensive unit tests for all new functionality
- Detailed testing of each component
- Parallel testing capabilities
- Results tracking and reporting

### 3. TestIntegration.lua
- End-to-end integration testing
- Simulated party scenarios
- Timing-sensitive test sequences
- Real-world usage simulation

### 4. TestPartySync.lua
- Specific tests for party synchronization
- Message handling validation
- Communication protocol testing

### 5. TestSyncHighlighting.lua
- Focused tests for synchronized highlighting
- UI button interaction testing
- Color validation and timing

## Expected Test Results

### Successful Test Indicators
- ✅ All function existence checks pass
- ✅ Debug keystone "+69 Goon Cave" generates correctly
- ✅ Animation state properly initialized and managed
- ✅ Serialization/deserialization maintains data integrity
- ✅ UI highlighting cycles with proper colors
- ✅ Animation stops cleanly on completion
- ✅ Message communication works in party scenarios

### Failure Indicators
- ❌ Missing function errors
- ❌ Debug keystone not generated
- ❌ Animation state corruption
- ❌ Serialization data loss
- ❌ Highlighting not applied or stuck
- ❌ Animation doesn't stop properly
- ❌ Communication failures

## Manual Testing Scenarios

### Scenario 1: Debug Mode Testing
1. Enable debug mode: `MDW.debugMode = true`
2. Ensure no real keystones in bags
3. Run `/mdwdebug` to verify debug keystone generation
4. Check for "+69 Goon Cave (TEST)" keystone

### Scenario 2: Party Animation Testing
1. Create or join a party
2. Start a keystone session as session owner
3. Click "Get Rolling!" button
4. Verify all party members see synchronized yellow highlighting
5. Confirm animation stops for everyone when selection completes

### Scenario 3: Animation Robustness Testing
1. Start rolling animation with multiple keystones
2. Simulate keystone removal during animation
3. Verify animation continues without breaking
4. Check that final selection is still valid

### Scenario 4: Complete Integration Testing
1. Run `/mdwintegration` for automated testing
2. Monitor results for 30+ seconds
3. Review pass/fail statistics
4. Verify 90%+ success rate

## Troubleshooting

### Common Issues
- **Addon not loaded**: Ensure MythicDungeonWheel is properly installed and enabled
- **UI frames not found**: Some frames are created dynamically; this is normal
- **Serialization errors**: Check for special characters in keystone names
- **Animation timing issues**: Verify C_Timer functionality is available

### Debug Output
Enable debug mode for verbose output:
```lua
MythicDungeonWheel.debugMode = true
```

### Performance Considerations
- Tests use timers and may affect performance temporarily
- Integration tests run for 30+ seconds
- Reset environment between test runs for clean results

## Version Compatibility
- Compatible with WoW Retail (current version)
- Requires LibStub and Ace3 libraries
- Tested with current MythicDungeonWheel addon version

## Future Test Additions
- Performance benchmarking tests
- Network latency simulation
- Large party size testing
- Memory usage validation
- UI responsiveness testing
