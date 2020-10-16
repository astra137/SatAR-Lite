# SatAR-Lite

This app is a tool for aligning hand-held antenna with amateur radio satellites via augmented reality.

## Credits

Right as our team was researching SGP4/SDP4, SpaceTrack Report #3, and the source code published by Vallado, the amazing @gavineadie published an open source Swift implementation. It has variable names true to the original papers and other great academic features.

- https://github.com/gavineadie/SatelliteKit

Additional libraries are included to simplify the codebase and prevent mistakes.

- https://github.com/mxcl/PromiseKit
- https://github.com/yannickl/AwaitKit
- https://github.com/yaslab/CSV.swift

The app downloads satellite and radio lists from these servers.

- https://celestrak.com/NORAD/elements/active.txt
- https://www.ne.jp/asahi/hamradio/je9pel/satslist.csv
