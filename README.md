# obs-text-line-changer

A lua script for OBS to automatically change a text source by looping through a text file of announcements.

This script was created to replicate functionality in SNAZ, a windows-only program. This lua script works on Mac, letting you define a list of announcements in an external text file and automatically update a text field every few seconds.

Configurable Options:

Source
OBS Text Source - Text source object within OBS that is manipulated
Text file with announcements - Local text file with any number of announcements
Lines per single announcement - Number of lines from the Text file to combine for a single announcement
Seconds per announcement - Duration to show a single announcement before moving to the next one

## Known issues
* Lines per single announcement is not working
* Labels are broken in the script editor (has something to do with obs source enumeration)
