# Spotlight clipboard history

Clavis presents clipboard history through the public `key clipboard` JSON protocol.
key-cli owns capture, cliphist access, payload inspection and wl-copy restoration.
The two projects build and test independently.

## Data flow

- `key clipboard watch` maintains one wl-paste watcher and selects one useful
  representation per event: file lists, supported images, plain text, Markdown,
  HTML, other text types, then known textual application types.
- cliphist stores the selected bytes and owns deduplication, history limits and
  deletion. There is no Clavis clipboard database or MIME sidecar.
- `ClipboardService` calls `list`, `inspect`, `restore`, `delete` and `clear` using
  argument arrays. It validates `schemaVersion: 1`, command names and operation
  results. Detailed inspection is queued and cached for listed entries.
- `SpotlightClipboardProvider` derives searchable rows from the returned metadata.
  Titles and subtitles may be shortened for display, while restoration uses the
  saved payload in key-cli, never a UI summary.

## Literal text and MIME limits

Spotlight result titles and subtitles use `Text.PlainText`. Markdown, HTML, XML and
JSON source must remain literal text: no rich-text auto-detection, entity decoding,
Markdown renderer or embedded-image extraction. File metadata and image thumbnails
are separate presentations of payloads already classified by key-cli.

The existing `mimeAwareStore` and `mimeRestore` capabilities describe MIME-guided
capture and semantic restoration. New key-cli versions also advertise
`singleRepresentation: true`, `multiMime: false`, `originalMimePreserved: false`.
These additive fields are accepted by the existing capability check; they do not
require a new shell protocol version.

The original offer's MIME metadata is not archived. key-cli classifies decoded
bytes as an image, file list or literal UTF-8 text and restores one appropriate MIME
through wl-copy. Textual source normally returns as `text/plain;charset=utf-8`.
This is not a multi-MIME archive, and Clavis must not describe it as one.

A watcher callback and a subsequent query for a preferred MIME are not atomic.
key-cli retains supported captured stdin on offer-query/read failure and skips
sensitive events, but rapid copies can still replace an offer between queries.
