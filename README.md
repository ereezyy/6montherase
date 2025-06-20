# 6MonthErase - Automated System Cleanup Utility

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Overview

6MonthErase is a powerful PowerShell utility designed to automatically identify and uninstall programs that haven't been used in the last 6 months. This tool helps maintain system performance by removing unused software and freeing up valuable disk space.

## Features

- 🔍 **Smart Detection**: Automatically identifies programs unused for 6+ months
- 🛡️ **Safe Operation**: Protects essential system programs and user-specified exclusions
- 📊 **Detailed Reporting**: Generates comprehensive reports of actions taken
- ⚙️ **Configurable**: Customizable time thresholds and exclusion lists
- 🔄 **Backup Support**: Creates restore points before making changes
- 📝 **Logging**: Detailed logs for audit and troubleshooting purposes

## System Requirements

- **Operating System**: Windows 10 or later
- **PowerShell**: Version 5.1 or higher
- **Privileges**: Administrator rights required
- **Disk Space**: Minimum 100MB free space for logs and backups

## Installation

### Quick Install

1. **Download the script**:
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ereezyy/6montherase/main/6MonthErase.ps1" -OutFile "6MonthErase.ps1"
   ```

2. **Set execution policy** (if needed):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Run the script**:
   ```powershell
   .\6MonthErase.ps1
   ```

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/ereezyy/6montherase.git
   cd 6montherase
   ```

2. Run PowerShell as Administrator

3. Execute the script:
   ```powershell
   .\6MonthErase.ps1
   ```

## Usage

### Basic Usage

Run the script with default settings (6-month threshold):

```powershell
.\6MonthErase.ps1
```

### Advanced Usage

Customize the cleanup parameters:

```powershell
# Set custom time threshold (in days)
.\6MonthErase.ps1 -DaysThreshold 180

# Dry run mode (preview only, no actual uninstall)
.\6MonthErase.ps1 -DryRun

# Include additional exclusions
.\6MonthErase.ps1 -ExcludePrograms @("Adobe Photoshop", "Microsoft Office")

# Generate detailed report
.\6MonthErase.ps1 -DetailedReport -ReportPath "C:\Reports\cleanup_report.html"
```

### Configuration File

Create a `config.json` file for persistent settings:

```json
{
  "daysThreshold": 180,
  "createRestorePoint": true,
  "excludePrograms": [
    "Windows Security",
    "Microsoft Edge",
    "Windows Media Player"
  ],
  "logLevel": "Info",
  "reportFormat": "HTML"
}
```

## Safety Features

### Protected Programs

The script automatically protects essential system components:

- Windows system programs
- Security software
- Device drivers
- Microsoft Visual C++ Redistributables
- .NET Framework components

### Restore Points

Before making any changes, the script:
- Creates a system restore point
- Backs up the registry
- Logs all actions for potential rollback

### Exclusion Lists

You can protect specific programs by:
- Adding them to the configuration file
- Using the `-ExcludePrograms` parameter
- Creating a custom exclusion list file

## Output and Reporting

### Console Output

The script provides real-time feedback:
- Programs being analyzed
- Uninstall progress
- Success/failure notifications
- Summary statistics

### Log Files

Detailed logs are saved to:
- `%TEMP%\6MonthErase\logs\cleanup_YYYYMMDD.log`
- Includes timestamps, actions, and error details

### HTML Reports

Generate comprehensive reports with:
- Before/after disk space comparison
- List of removed programs
- Time saved analysis
- Recommendations for future cleanup

## Command Line Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `-DaysThreshold` | Integer | Days of inactivity before considering removal | 180 |
| `-DryRun` | Switch | Preview mode without actual uninstall | False |
| `-ExcludePrograms` | Array | Additional programs to protect | Empty |
| `-CreateRestorePoint` | Switch | Create system restore point | True |
| `-DetailedReport` | Switch | Generate comprehensive HTML report | False |
| `-ReportPath` | String | Custom path for report file | Default temp location |
| `-LogLevel` | String | Logging verbosity (Error/Warning/Info/Debug) | Info |
| `-Silent` | Switch | Run without user interaction | False |

## Examples

### Example 1: Conservative Cleanup

Remove programs unused for 1 year:

```powershell
.\6MonthErase.ps1 -DaysThreshold 365 -CreateRestorePoint -DetailedReport
```

### Example 2: Preview Mode

See what would be removed without making changes:

```powershell
.\6MonthErase.ps1 -DryRun -DetailedReport -ReportPath "C:\preview_report.html"
```

### Example 3: Automated Cleanup

Silent operation for scheduled tasks:

```powershell
.\6MonthErase.ps1 -Silent -LogLevel Warning
```

## Troubleshooting

### Common Issues

**Script won't run**:
- Ensure PowerShell execution policy allows script execution
- Run PowerShell as Administrator
- Check antivirus software isn't blocking the script

**Programs not detected**:
- Some programs may not register last-used dates
- Portable applications might not be detected
- Check exclusion lists for false positives

**Uninstall failures**:
- Some programs require manual uninstallation
- Check logs for specific error messages
- Verify sufficient disk space for temporary files

### Getting Help

1. Check the log files for detailed error information
2. Run with `-LogLevel Debug` for verbose output
3. Use `-DryRun` to preview actions before execution
4. Review the exclusion lists and configuration

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on different Windows versions
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This tool modifies your system by uninstalling programs. While safety measures are in place, always:
- Create backups before running
- Test in a non-production environment first
- Review the exclusion lists carefully
- Keep restore points enabled

Use at your own risk. The authors are not responsible for any data loss or system issues.

## Support

- 📧 **Email**: support@6montherase.com
- 🐛 **Issues**: [GitHub Issues](https://github.com/ereezyy/6montherase/issues)
- 📖 **Documentation**: [Wiki](https://github.com/ereezyy/6montherase/wiki)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/ereezyy/6montherase/discussions)

---

**Made with ❤️ for system optimization enthusiasts**

