# Mythic Dungeon Wheel

A World of Warcraft addon that provides an engaging way for groups to randomly select keystones for Mythic+ dungeons using a smooth scrolling animation.

## Features

- **Democratic Session Management**: Any party member can start, reset, or roll sessions
- **Keystone Management**: Players can add/remove their keystones with smart detection
- **Animated Selection**: Smooth scrolling animation that gradually slows down before selecting a keystone
- **Session Owner Controls**: Session owners can remove any keystone from the list
- **One Entry Per Player**: Prevents players from adding multiple keystones to the same session
- **Animation Safety**: Keystones cannot be added/removed during the selection animation
- **Minimap Button**: Convenient minimap button with fallback support
- **Test Mode**: Development testing functionality with fake keystones

## Commands

- `/mdw` or `/mythicwheel` - Toggle the main interface
- `/mdw start` - Start a new session (any party member)
- `/mdw reset` - Reset the current session (any party member)
- `/mdw test` - Toggle test mode for development (adds fake keystones)
- `/mdw devmode` - Toggle developer mode (shows test button)
- `/mdw scan` - Scan bags for keystones
- `/mdw debug` - Show debug information
- `/mdw help` - Show help information

## How to Use

1. **Starting a Session**: Any party member uses `/mdw start` or clicks "Start Session" in the interface
2. **Adding Keystones**: Each player opens the interface with `/mdw` and clicks "Add Your Key" to add their keystone
3. **Managing Keystones**: Players can remove their own keystone with "Remove Your Key", and session owners can remove any keystone using the "×" button
4. **Rolling**: Any party member clicks "Get Rolling!" to start the animated selection
5. **Reset**: Any party member can click "Reset" to clear the session for reuse

## Installation

1. Extract the `MythicDungeonWheel` folder to your `World of Warcraft/_retail_/Interface/AddOns/` directory
2. Restart World of Warcraft or reload your UI with `/reload`
3. The addon will automatically load and display a message in chat

## Interface

The addon provides a clean, draggable interface that shows:
- Current session status and leader
- Available keystones from your bags (when session is active)
- All keystones added to the current session
- Selected keystone (when one has been chosen)
- Control buttons based on your role (leader/participant)

## Development Features

- **Test Mode**: Toggle with `/mdw test` to add fake keystones for testing
- **Debug Information**: Test keystones are marked with "(TEST)" in the interface
- **No Dependencies**: Works without external libraries for maximum compatibility

## Notes

- Requires being in a party or raid group for communication
- Only party/raid leaders can start sessions and select keystones
- Players can only add one keystone per session
- The addon automatically detects keystone items in your bags
- All communication is done through the addon channel and is secure within your group

## Troubleshooting

If the addon isn't working:
1. Make sure you're in a party or raid group
2. Verify the leader has started a session
3. Check that you have keystones in your bags
4. Try `/reload` to refresh the interface
5. Use `/mdw test` to enable test mode for debugging

## Future Enhancements

- Enhanced keystone parsing for better dungeon and affix detection
- Persistent session data across reloads
- Integration with guild systems
- Custom affix display and filtering
- Historical tracking of used keystones
