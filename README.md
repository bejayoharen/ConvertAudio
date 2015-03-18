# ConvertAudio
This is sample code for converting audio formats in iOS.

I should warn that this is derived from some of the first code I ever wrote for iOS,
and it's somewhat complex, involving AVFoundation, GCD (Grand Central Dispatch) and so on,
so it may contain errors and general slopiness. Still I think it's likely to be useful,
so I'm sharing.

# Specifics

This example:
* lets the user select a track from their iTunes Library (See SelectAudioPressed in ViewController.m).
* converts it to .wav (16 bit little endian) (See AudioConverter)
* Stores it in the Documents folder where the user can access it via iTunes sharing.

There is also a progress bar update as the process continues.
