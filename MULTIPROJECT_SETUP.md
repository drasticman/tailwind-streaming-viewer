# Multi-project viewer setup

## Initial project

An example project is available at:

- `/example/`

Its MediaMTX paths are configured in `Web/projects/example.json`:

- `Example_A`
- `Example_B`
- optional future audio path: `Example_MultiAudio_clean`

For OBS A Cam, use:

```text
srt://YOUR_SERVER_HOSTNAME:8890?streamid=publish:Example_A
```

## Main project

`Web/projects/main.json` controls where the bare domain redirects:

```json
{
  "mainProject": "example"
}
```

Changing `mainProject` changes the project opened by the bare-domain URL.

## Adding another project

Copy `Web/projects/templates/project.example.json` to a new lowercase filename such as:

```text
Web/projects/secondproject.json
```

Then change the project name and MediaMTX paths.

The viewer will automatically be available at:

```text
/secondproject/
```

without another copy of `index.html`.

## Project transport mode

Each project JSON supports:

- `"auto"`: try WebRTC, then fall back to HLS
- `"webrtc"`: WebRTC only
- `"hls"`: HLS only

## Deployment

Copy updated files into the matching locations under the local Streaming installation, including:

- `Caddy/caddyfile`
- `Web/index.html`
- `Web/projects/main.json`
- the applicable production JSON file

Restart Caddy after replacing the Caddyfile.

The auth server does not need to change for this multi-project setup; all projects share the current site password.
