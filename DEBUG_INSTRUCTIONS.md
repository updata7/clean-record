# Debug Instructions for Language Switching Issue

## How to Run with Debug Logs

1. **Open Terminal** and navigate to the project directory:
   ```bash
   cd /Users/chenk/Documents/code/AI/clean-record/CleanRecord
   ```

2. **Run the app** and watch the console output:
   ```bash
   swift run CleanRecord 2>&1 | grep -E "(LocalizationManager|StatusBarController|CleanRecord)"
   ```

3. **Test Language Switching:**
   - Click the menu bar icon
   - Select **Language → 中文**
   - Watch the console output

## What to Look For in Debug Logs

The logs will show the complete flow:

### When you click "中文":
```
StatusBarController: setChinese() called
LocalizationManager: Setting language to: zh-Hans
LocalizationManager: Language saved, posting notification
LocalizationManager: Notification posted
StatusBarController: refreshMenu() called
StatusBarController: Clearing menu items
StatusBarController: Rebuilding menu with new localized strings
LocalizationManager: Looking up 'menu.about' in language 'zh-Hans'
LocalizationManager: Found bundle at: /path/to/zh-Hans.lproj
LocalizationManager: Got string: '关于 CleanRecord'
... (more lookups)
StatusBarController: Menu refresh complete
```

### If notification is NOT received:
You'll see:
```
StatusBarController: setChinese() called
LocalizationManager: Setting language to: zh-Hans
LocalizationManager: Language saved, posting notification
LocalizationManager: Notification posted
(NO refreshMenu() called - this means observer isn't working!)
```

### If bundle is NOT found:
You'll see:
```
LocalizationManager: WARNING - Could not find bundle for language: zh-Hans
```

## Expected vs Actual

**EXPECTED**: After clicking language menu item, you should see:
1. `setChinese()` called
2. Language saved
3. Notification posted
4. `refreshMenu()` called
5. Menu items cleared
6. Menu rebuilt with Chinese strings

**IF MISSING**: Note which step is missing and share the console output.

## Quick Test Commands

Run the app and immediately test:
```bash
# Run app with full debug output
swift run CleanRecord 2>&1 | tee /tmp/cleanrecord-debug.log

# Then click Language → 中文 in the menu

# After testing, view the log:
cat /tmp/cleanrecord-debug.log | grep -E "(setChinese|refreshMenu|LocalizationManager)"
```

## Share Results

Please share the console output showing what happens when you:
1. Start the app
2. Click Language → 中文
3. Whether the menu changes or not

This will help identify exactly where the flow breaks!
