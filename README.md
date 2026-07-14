# Tailwind Streaming Viewer

Tailwind Streaming Viewer is a lightweight streaming appliance for on-set film and television production.

It is designed around a simple philosophy:

- Reliability over features
- Configuration over code
- Low latency wherever possible
- Easy to understand and debug

The server provides secure WebRTC and HLS viewing for multiple camera feeds using MediaMTX, Caddy, and a lightweight Python authentication service.

## Features

- Secure project-based viewer
- Multiple simultaneous camera feeds
- WebRTC (low latency)
- HLS (audio capable)
- JSON-based project configuration
- Simple browser interface
- Designed for Windows deployment

## Architecture

```
Camera
   │
   ▼
SRT
   │
   ▼
MediaMTX
   │
   ├── WebRTC
   └── HLS
        │
        ▼
Caddy
   │
   ▼
Python Authentication
   │
   ▼
Browser Viewer
```

Each production is described by a JSON configuration rather than modifying the application itself.

Example:

```
Web/projects/
    main.example.json
    production.example.json
```

Local production files remain outside version control.

## Components

- MediaMTX
- Caddy
- Python 3
- FFmpeg

These executables are intentionally not included in this repository.

## Philosophy

The goal is not to create another web application.

The goal is to build a dependable streaming appliance that can be powered on before call time and simply work throughout the day.

Configuration files describe the production.

Code describes the server.

## Status

The core streaming architecture is stable.

Current development is focused on a server monitor/supervisor for launching, monitoring, and gracefully shutting down the streaming stack.