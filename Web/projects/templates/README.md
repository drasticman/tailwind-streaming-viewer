# Project Templates

These files match the project configuration format used by Tailwind Streaming Viewer.

They are templates for local files stored in:

```text
Web/projects/
```

Real production JSON files should stay local and are excluded from Git by:

```gitignore
Web/projects/*.json
```

The template files can remain public inside:

```text
Web/projects/templates/
```

## Create a production

1. Copy `project.example.json` into the parent `Web/projects` folder.
2. Rename the copy using a short URL-safe project ID, such as:

   ```text
   example.json
   ```

3. Edit the production name and MediaMTX stream paths.
4. Copy `main.example.json` into the parent folder and rename it:

   ```text
   main.json
   ```

5. Set `mainProject` to the project filename without `.json`.

For example:

```json
{
  "mainProject": "example"
}
```

This makes the root URL redirect to:

```text
/example/
```

## Offline landing page

To show the public offline landing page instead of redirecting to a production, use:

```json
{
  "mainProject": "offline"
}
```

## Notes

- `transport` can remain `auto` for normal operation.
- `fallbackMs` controls how long the viewer waits before falling back from WebRTC.
- `defaultLayout` may be `multi` or `single`.
- Set `remoteAudio` to `true` only when the project should expose the audio-capable HLS option.
- A stream must have `enabled: true` to appear in the viewer.
- Stream `path` values must match the corresponding MediaMTX path names.
