# Changelog

## 1.8.7 — first public release
- Smooth motion: the radio's Slow up / Slow down (0.5 s) moves the servos; the script only
  sets the end points, so screen refreshes can never make a servo stutter
- Fixed speed of 30 cycles per minute, full travel from end to end
- Between cycles the servo sweeps straight through the centre; only the last cycle stops there
- Pot 2 sets the number of cycles (1 – 999, exponential: fine steps for small numbers)
- Pot 1 sets the travel (0 – 100 %)
- Dashboard: progress bar (elapsed | RUNNING | time left), servo-arm cycle dial, temperature
  bars for the 4 hottest of up to 8 sensors, current (A) and RX battery (V), travel and cycles dials
- Safety: runs only in the model that shows the widget, stops when the model is changed,
  never starts at power-up when the start switch is already ON
- Temperature bars only show for sensors with live telemetry
- Scales to X20 / X18 / X14 / X10 / X12S screens
- Model pictures (PNG) for each radio size

Versions before 1.8.7 were development versions and were not published.
