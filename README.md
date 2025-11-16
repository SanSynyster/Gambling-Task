# EEG Gambling Task (MATLAB + Psychtoolbox)

This script implements a behavioural decision-making task tailored for EEG experiments. Participants choose between two boxes with hidden values across 16 blocks, while precise EEG triggers are sent for synchronization.

## Features

- Designed for EEG research with trigger integration via parallel port (`LPT1`)
- Supports randomized gain/loss value presentation (5 and 25)
- Participant metadata collection (Name, Surname, Age, Gender, Chronotype, User ID)
- Supports up to 384 trials (16 blocks × 24 trials)
- Sends 9 types of EEG triggers:
  - Inter-trial interval (ITI)
  - Fixation
  - Stimulus presentation
  - Choice made
  - Gain (correct/error)
  - Loss (correct/error)
  - End of block

## Usage

1. Ensure MATLAB has access to Psychtoolbox and parallel port support.
2. Run the script:
   ```matlab
   CompleteWithTriggers
   ```
3. Use the `F` and `J` keys to choose left or right box.
4. Press the **spacebar** to continue to the next block after score feedback.
5. Output is saved to a log file automatically.

## Dependencies

- MATLAB R2011b+
- Psychtoolbox 3
- Parallel port driver (`digitalio`)
- Compatible with EEG trigger systems that support TTL input

## Author

Sahab Taali  
MSc Cloud Computing, University of Leicester  
GitHub: [SanSynyster](https://github.com/SanSynyster)