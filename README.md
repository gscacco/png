# Description
Command line tool that extracts informations from png file. No dependency used

# How to build
From command line using nimble tool:
```shell
nimble build
```

# Usage

```shell
png <filename>
```

# Details
## Decoded blocks
At the moment the tool reads the following block types:

- IHDR
- sRGB
- gAMA
- pHYs
- iCCP

Details on the standard can be found here: http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html